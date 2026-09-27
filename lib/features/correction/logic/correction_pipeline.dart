import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../data/llm/correction_prompts.dart';
import '../../../data/llm/image_preprocess.dart';
import '../../../data/llm/llm_client.dart';
import '../../../domain/score/correct/score_diff.dart';
import '../../../domain/score/correct/slice_map.dart';
import '../../../domain/score/merge/page_merger.dart';
import '../../../domain/score/score_document.dart';
import '../../../domain/score/score_validator.dart';
import '../../generation/logic/generation_pipeline.dart' show PageInput;

/// 单页纠错进度（UI 用）。
class CorrectionPageProgress {
  CorrectionPageProgress({
    required this.pageIndex,
    this.status = 'pending', // pending | running | ok | failed | unchanged
    this.attempts = 0,
    this.error,
    this.changeCount = 0,
    this.largeDiff = false,
  });

  final int pageIndex;
  String status;
  int attempts;
  String? error;
  int changeCount;
  bool largeDiff;

  CorrectionPageProgress copy() => CorrectionPageProgress(
        pageIndex: pageIndex,
        status: status,
        attempts: attempts,
        error: error,
        changeCount: changeCount,
        largeDiff: largeDiff,
      );
}

/// 单页纠错结果。
class CorrectionPageOutcome {
  CorrectionPageOutcome({
    required this.pageIndex,
    required this.ok,
    this.unchanged = false,
    this.changes = const [],
    this.warnings = const [],
    this.error,
    this.attempts = 0,
    this.largeDiff = false,
  });

  final int pageIndex;
  final bool ok;
  final bool unchanged;
  final List<ScoreChange> changes;
  final List<String> warnings;
  final String? error;
  final int attempts;
  final bool largeDiff;
}

class CorrectionResult {
  CorrectionResult({
    required this.pages,
    required this.changes,
    this.warnings = const [],
  });

  final List<CorrectionPageOutcome> pages;

  /// 全部页的可应用改动（按页序拼接）。
  final List<ScoreChange> changes;
  final List<String> warnings;
}

/// 纠错管线（纯逻辑，LLM 与文件系统可注入）：逐页把原图 + 当前切片 JSON
/// 发给 LLM 对照校对，结构守卫 + 校验回喂（≤maxAttempts 次），本地 diff。
/// 原文档不被修改。
class CorrectionPipeline {
  CorrectionPipeline({
    required this.gateway,
    Future<Uint8List?> Function(String path)? readImage,
    Uint8List Function(Uint8List)? compress,
    this.maxAttempts = 3,
  })  : _readImage = readImage ??
            ((path) async =>
                File(path).existsSync() ? File(path).readAsBytesSync() : null),
        _compress = compress ?? ((b) => ImagePreprocess.compress(b));

  final LlmGateway gateway;
  final Future<Uint8List?> Function(String path) _readImage;
  final Uint8List Function(Uint8List) _compress;
  final int maxAttempts;

  Future<CorrectionResult> run({
    required String kind,
    required ScoreDocument doc,
    required List<PageSliceSpec> slices,
    required List<PageInput> pages,
    void Function(CorrectionPageProgress progress)? onProgress,
  }) async {
    final outcomes = <CorrectionPageOutcome>[];
    for (final page in pages) {
      final outcome = await runPage(
        kind: kind,
        doc: doc,
        slices: slices,
        page: page,
        onProgress: onProgress,
      );
      outcomes.add(outcome);
    }
    return CorrectionResult(
      pages: outcomes,
      changes: [for (final o in outcomes) ...o.changes],
      warnings: [for (final o in outcomes) ...o.warnings],
    );
  }

  /// 单页纠错（重试入口复用）。
  Future<CorrectionPageOutcome> runPage({
    required String kind,
    required ScoreDocument doc,
    required List<PageSliceSpec> slices,
    required PageInput page,
    void Function(CorrectionPageProgress progress)? onProgress,
  }) async {
    final spec = slices.where((s) => s.page == page.pageIndex).firstOrNull;
    final progress = CorrectionPageProgress(pageIndex: page.pageIndex, status: 'running');
    if (spec == null || spec.measures.isEmpty) {
      progress.status = 'failed';
      progress.error = '该页没有切片规格（页片段缺失）';
      onProgress?.call(progress);
      return CorrectionPageOutcome(
        pageIndex: page.pageIndex,
        ok: false,
        error: progress.error,
      );
    }
    onProgress?.call(progress);

    try {
      final sliceDoc = buildSliceDocument(doc, spec);
      final images = await _imageBase64(page.imagePath);
      final carryIn = _carryInJson(doc, spec);
      final hint = _boundaryHint(doc, spec, slices);

      String? lastError;
      String? lastJson;
      List<ScoreMeasure> corrected = const [];
      var attempt = 0;
      for (attempt = 1; attempt <= maxAttempts; attempt++) {
        progress.attempts = attempt;
        onProgress?.call(progress);
        final sw = Stopwatch()..start();
        try {
          debugPrint('[纠错] 第${page.pageIndex}页 第$attempt/$maxAttempts次开始'
              '${lastError == null ? '' : '（回喂：${_clip(lastError)}）'}');
          final raw = await gateway.completeJson(
            system: CorrectionPrompts.system(kind),
            user: CorrectionPrompts.user(
              pageIndex: page.pageIndex,
              kind: kind,
              sliceJson: jsonEncode([
                for (final m in sliceDoc.parts.first.measures) m.toJson(),
              ]),
              carryInJson: carryIn,
              boundaryHint: hint,
              repairFeedback: lastError == null ? null : [lastError],
              previousAttemptJson: lastJson,
            ),
            imageJpegBase64: images,
          );
          debugPrint('[纠错] 第${page.pageIndex}页 第$attempt次返回 '
              '${sw.elapsedMilliseconds ~/ 1000}s，输出 ${raw.length} 字符');
          lastJson = DioLlmClient.extractJson(raw);
          final fragment =
              PageFragment.fromJson(jsonDecode(lastJson) as Map<String, dynamic>);

          // 结构守卫：小节数必须一致（页 ↔ 小节对应的根基）
          if (fragment.measures.length != spec.measures.length) {
            lastError = '必须输出与输入相同数量的小节'
                '（应为 ${spec.measures.length} 个，实际 ${fragment.measures.length} 个）';
            debugPrint('[纠错] 第${page.pageIndex}页 第$attempt次小节数不符');
            continue;
          }

          // 结构校验 + 修复（切片小节都是完整小节；首小节可能是弱起，
          // 末小节可能被下一页承接）
          final probeDoc = _probeDocument(kind, doc.meta, fragment);
          final lastMi = spec.measures.last.measureIndex;
          final validation = ScoreValidator.validateAndRepair(
            probeDoc,
            ValidateOptions(
              firstContinues: false,
              lastContinues: lastMi < doc.parts.first.measures.length - 1,
              firstIsPickup:
                  spec.measures.first.measureIndex == 0 && doc.meta.pickup,
            ),
          );
          if (!validation.ok) {
            lastError = [
              for (final e in validation.errors) '${e.code}: ${e.message}',
            ].join('；');
            debugPrint('[纠错] 第${page.pageIndex}页 第$attempt次校验未过：'
                '${_clip(lastError, 500)}');
            continue;
          }
          // 校验器就地修复（补休止/吸附）写回修正切片
          corrected = probeDoc.parts.first.measures;
          break;
        } catch (e) {
          lastError = e.toString();
          debugPrint('[纠错] 第${page.pageIndex}页 第$attempt次异常'
              '（${sw.elapsedMilliseconds ~/ 1000}s）：${_clip(lastError, 500)}');
        }
      }

      if (attempt > maxAttempts && corrected.isEmpty) {
        progress.status = 'failed';
        progress.error = lastError ?? '未知错误';
        onProgress?.call(progress);
        return CorrectionPageOutcome(
          pageIndex: page.pageIndex,
          ok: false,
          error: progress.error,
          attempts: maxAttempts,
        );
      }

      // 本地 diff（含跨页守卫：LLM 改写图片范围外内容的小节整段丢弃）
      final correctedDoc = ScoreDocument(
        kind: doc.kind,
        meta: doc.meta,
        parts: [
          ScorePart(
            instrument: doc.parts.first.instrument,
            staffCount: doc.parts.first.staffCount,
            measures: corrected,
          ),
        ],
      );
      final (changes: changes, warnings: diffWarnings) = diffSlice(
        original: sliceDoc,
        corrected: correctedDoc,
        spec: spec,
        page: page.pageIndex,
      );

      final changedMeasures = {...changes.map((c) => c.measureIndex)}.length;
      final largeDiff =
          changedMeasures > spec.measures.length * 0.6 && changedMeasures > 3;
      progress.status = changes.isEmpty ? 'unchanged' : 'ok';
      progress.changeCount = changes.length;
      progress.largeDiff = largeDiff;
      onProgress?.call(progress);
      return CorrectionPageOutcome(
        pageIndex: page.pageIndex,
        ok: true,
        unchanged: changes.isEmpty,
        changes: changes,
        warnings: diffWarnings,
        attempts: attempt.clamp(1, maxAttempts),
        largeDiff: largeDiff,
      );
    } catch (e) {
      progress.status = 'failed';
      progress.error = e.toString();
      onProgress?.call(progress);
      return CorrectionPageOutcome(
        pageIndex: page.pageIndex,
        ok: false,
        error: e.toString(),
      );
    }
  }

  /// 切片前一合并小节 JSON（上下文参考，禁止输出）。
  String? _carryInJson(ScoreDocument doc, PageSliceSpec spec) {
    final first = spec.measures.first.measureIndex;
    if (first <= 0) return null;
    final m = doc.parts.first.measures[first - 1];
    return jsonEncode(m.toJson());
  }

  /// 跨页限制提示：列出每个 boundary 小节中不属于本页的事件区间。
  String? _boundaryHint(
    ScoreDocument doc,
    PageSliceSpec spec,
    List<PageSliceSpec> slices,
  ) {
    final restrictions = <BoundaryRestriction>[];
    for (final ms in spec.measures) {
      if (!ms.boundary) continue;
      final m = doc.parts.first.measures[ms.measureIndex];
      final descs = <String>[];
      for (final v in m.voices) {
        final key = '${v.staff}:${v.voiceNo}';
        final ranges = ms.ownedRanges[key];
        final n = v.events.length;
        if (ranges == null) {
          descs.add('$_voice(staff${v.staff}) 全部 $n 个事件');
          continue;
        }
        final unowned = <int>[
          for (var i = 0; i < n; i++)
            if (!ranges.any((r) => i >= r.$1 && i < r.$2)) i,
        ];
        if (unowned.isEmpty) continue;
        descs.add('$_voice(staff${v.staff}) '
            '${_rangeText(unowned)}（共 ${unowned.length} 个）');
      }
      if (descs.isEmpty) continue;
      // 本页所有权从 0 开始 → 尾部属于下一页；否则头部来自上一页
      final ownsHead =
          ms.ownedRanges.values.any((rs) => rs.any((r) => r.$1 == 0));
      restrictions.add(BoundaryRestriction(
        measureNumber: ms.measureIndex + 1,
        tail: ownsHead,
        descriptions: descs,
      ));
    }
    if (restrictions.isEmpty) return null;
    return CorrectionPrompts.boundaryHint(restrictions: restrictions);
  }

  static String _rangeText(List<int> indices) {
    // 连续段压缩：[2,3,4,7] → "第2-4、7个"
    final parts = <String>[];
    var start = indices.first;
    var prev = indices.first;
    for (final i in indices.skip(1)) {
      if (i == prev + 1) {
        prev = i;
        continue;
      }
      parts.add(start == prev ? '第${start + 1}个' : '第${start + 1}-${prev + 1}个');
      start = prev = i;
    }
    parts.add(start == prev ? '第${start + 1}个' : '第${start + 1}-${prev + 1}个');
    return parts.join('、');
  }

  static String _voice(int staff) =>
      staff == 1 ? '右手' : staff == 2 ? '左手' : '谱表$staff';

  static ScoreDocument _probeDocument(
      String kind, ScoreMeta meta, PageFragment frag) {
    return ScoreDocument(
      kind: kind,
      meta: ScoreMeta(
        timeBeats: meta.timeBeats,
        timeBeatType: meta.timeBeatType,
        pickup: meta.pickup && frag.measures.isNotEmpty,
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

  Future<List<String>> _imageBase64(String path) async {
    final raw = await _readImage(path);
    if (raw == null) {
      throw StateError('无法读取图片文件: $path');
    }
    final jpeg = _compress(raw);
    return [base64Encode(jpeg)];
  }

  static String _clip(String s, [int max = 120]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final x in this) {
      return x;
    }
    return null;
  }
}
