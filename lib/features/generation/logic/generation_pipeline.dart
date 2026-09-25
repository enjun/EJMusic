import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../data/llm/image_preprocess.dart';
import '../../../data/llm/llm_client.dart';
import '../../../data/llm/prompts.dart';
import '../../../domain/score/merge/page_merger.dart';
import '../../../domain/score/score_document.dart';
import '../../../domain/score/score_validator.dart';

/// 单页输入。
class PageInput {
  PageInput({required this.pageIndex, required this.imagePath});

  final int pageIndex; // 1-based
  final String imagePath;
}

/// 页进度（UI 用）。
class PageProgress {
  PageProgress({
    required this.pageIndex,
    this.status = 'pending', // pending | running | ok | failed
    this.attempts = 0,
    this.error,
  });

  final int pageIndex;
  String status;
  int attempts;
  String? error;

  PageProgress copy() => PageProgress(
        pageIndex: pageIndex,
        status: status,
        attempts: attempts,
        error: error,
      );
}

class PageOutcome {
  PageOutcome({
    required this.pageIndex,
    required this.ok,
    this.fragment,
    this.error,
    this.attempts = 0,
  });

  final int pageIndex;
  final bool ok;
  final PageFragment? fragment;
  final String? error;
  final int attempts;
}

class GenerationResult {
  GenerationResult({
    required this.pages,
    this.document,
    this.mergeWarnings = const [],
  });

  final List<PageOutcome> pages;
  final ScoreDocument? document; // 至少一页成功即有合并结果
  final List<String> mergeWarnings;

  bool get allOk => pages.every((p) => p.ok);
  int get okCount => pages.where((p) => p.ok).length;
}

/// 识别管线（纯逻辑，LLM 与文件系统可注入，mock 回放可测）。
class GenerationPipeline {
  GenerationPipeline({
    required this.gateway,
    Future<Uint8List?> Function(String path)? readImage,
    Uint8List Function(Uint8List)? compress,
    this.maxRepairAttempts = 3,
  })  : _readImage =
            readImage ?? ((path) async => File(path).existsSync() ? File(path).readAsBytesSync() : null),
        _compress = compress ?? ((b) => ImagePreprocess.compress(b));

  final LlmGateway gateway;
  final Future<Uint8List?> Function(String path) _readImage;
  final Uint8List Function(Uint8List) _compress;
  final int maxRepairAttempts;

  Future<GenerationResult> run({
    required String kind,
    required List<PageInput> pages,
    void Function(PageProgress progress)? onProgress,
    String? titleHint,
  }) async {
    final outcomes = <PageOutcome>[];
    String? carryInJson;

    for (final page in pages) {
      final progress = PageProgress(pageIndex: page.pageIndex, status: 'running');
      onProgress?.call(progress);

      final outcome = await _recognizePage(
        kind: kind,
        page: page,
        carryInJson: carryInJson,
        onAttempt: (n) {
          progress.attempts = n;
          onProgress?.call(progress);
        },
      );
      outcomes.add(outcome);
      progress.status = outcome.ok ? 'ok' : 'failed';
      progress.error = outcome.error;
      onProgress?.call(progress);

      if (outcome.ok && outcome.fragment != null) {
        carryInJson = _lastMeasuresJson(outcome.fragment!);
      }
    }

    // 合并
    final okFragments = [
      for (final o in outcomes)
        if (o.ok && o.fragment != null) o.fragment!,
    ];
    ScoreDocument? doc;
    var warnings = <String>[];
    if (okFragments.isNotEmpty) {
      final merged = PageMerger.merge(fragments: okFragments, kind: kind);
      doc = merged.document;
      warnings = merged.warnings;
      doc.meta.pageCount = pages.length;
      doc.meta.imageNames = [for (final p in pages) p.imagePath];
      final validation = ScoreValidator.validateAndRepair(doc);
      warnings.addAll(validation.repairs);
      // 合并后仍有结构性错误（如跨页拼接超拍）→ 记录 warning 不阻断
      for (final e in validation.errors) {
        warnings.add('校验错误: ${e.message}');
      }
    }
    return GenerationResult(pages: outcomes, document: doc, mergeWarnings: warnings);
  }

  Future<PageOutcome> _recognizePage({
    required String kind,
    required PageInput page,
    required String? carryInJson,
    void Function(int attempt)? onAttempt,
  }) async {
    String? lastError;
    String? lastJson;

    for (var attempt = 1; attempt <= maxRepairAttempts; attempt++) {
      onAttempt?.call(attempt);
      final sw = Stopwatch()..start();
      try {
        debugPrint('[制谱] 第${page.pageIndex}页 第$attempt/$maxRepairAttempts次识别开始'
            '${lastError == null ? '' : '（回喂：${_clip(lastError)}）'}');
        final raw = await gateway.completeJson(
          system: Prompts.system(kind),
          user: Prompts.user(
            pageIndex: page.pageIndex,
            kind: kind,
            carryInJson: carryInJson,
            repairFeedback: lastError == null ? null : [lastError],
            previousAttemptJson: lastJson,
          ),
          imageJpegBase64: await _imageBase64(page.imagePath),
        );
        debugPrint('[制谱] 第${page.pageIndex}页 第$attempt次请求返回 '
            '${sw.elapsedMilliseconds ~/ 1000}s，输出 ${raw.length} 字符');
        lastJson = DioLlmClient.extractJson(raw);
        final fragment = PageFragment.fromJson(
            jsonDecode(lastJson) as Map<String, dynamic>);

        // 片段级校验 + 修复（首/末小节跨页延续豁免拍数检查）
        final probeDoc = _probeDocument(kind, fragment);
        final validation = ScoreValidator.validateAndRepair(
          probeDoc,
          PageMerger.fragmentOptions(fragment, isLastPage: false),
        );
        if (!validation.ok) {
          lastError = [
            for (final e in validation.errors) '${e.code}: ${e.message}',
          ].join('；');
          debugPrint('[制谱] 第${page.pageIndex}页 第$attempt次校验未过：${_clip(lastError, 500)}');
          continue;
        }
        // 校验器的就地修复（补休止/tab 推导）要写回 fragment
        fragment.measures = probeDoc.parts.first.measures;
        debugPrint('[制谱] 第${page.pageIndex}页 第$attempt次识别成功，'
            '${fragment.measures.length} 小节，耗时 ${sw.elapsedMilliseconds ~/ 1000}s');
        return PageOutcome(
          pageIndex: page.pageIndex,
          ok: true,
          fragment: fragment,
          attempts: attempt,
        );
      } catch (e) {
        lastError = e.toString();
        debugPrint('[制谱] 第${page.pageIndex}页 第$attempt次异常（${sw.elapsedMilliseconds ~/ 1000}s）：${_clip(lastError, 500)}');
      }
    }
    return PageOutcome(
      pageIndex: page.pageIndex,
      ok: false,
      error: lastError ?? '未知错误',
      attempts: maxRepairAttempts,
    );
  }

  Future<List<String>> _imageBase64(String path) async {
    final raw = await _readImage(path);
    if (raw == null) {
      throw StateError('无法读取图片文件: $path');
    }
    final jpeg = _compress(raw);
    return [base64Encode(jpeg)];
  }

  static ScoreDocument _probeDocument(String kind, PageFragment frag) {
    return ScoreDocument(
      kind: kind,
      meta: ScoreMeta(
        title: frag.title ?? '',
        timeBeats: frag.timeBeats ?? 4,
        timeBeatType: frag.timeBeatType ?? 4,
        pickup: frag.pickup ?? false,
      ),
      parts: [
        ScorePart(
          instrument: kind,
          staffCount: kind == 'guitar' ? 1 : 2,
          measures: frag.measures,
        ),
      ],
    );
  }

  static String _lastMeasuresJson(PageFragment frag) {
    final last = frag.measures.length >= 2
        ? frag.measures.sublist(frag.measures.length - 2)
        : frag.measures;
    return jsonEncode([
      for (final m in last) m.toJson(),
    ]);
  }

  static String _clip(String s, [int max = 120]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
