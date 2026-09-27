import 'dart:convert';
import 'dart:io';

import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:ejmusic/domain/score/merge/page_merger.dart';
import 'package:ejmusic/domain/score/score_document.dart'
    show PageFragment, ScoreDocument;
import 'package:ejmusic/features/correction/logic/correction_pipeline.dart';
import 'package:ejmusic/features/correction/ui/change_review_list.dart'
    show changeKindLabel;
import 'package:ejmusic/features/generation/logic/generation_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final x in this) {
      return x;
    }
    return null;
  }
}

/// 真实端到端纠错：真实制谱 → 人为注入错音 → 盲识别纠错 → 验证检出率。
/// 仅手动/本地运行：flutter test integration_test/correction_real_test.dart -d windows
/// 不写数据库；调外部 API 产生真实计费，勿进 CI。
void main() {
  test('真实盲识别纠错：A小调华尔兹 2 页（注入错音验证检出）',
      timeout: const Timeout(Duration(minutes: 40)), () async {
    final config = await loadLlmConfig();
    // ignore: avoid_print
    print('config: baseUrl=${config.baseUrl} model=${config.model} '
        'key=${config.apiKey.isEmpty ? '空' : '${config.apiKey.length}字符'}');
    expect(config.isConfigured, isTrue, reason: '本机需先在应用里配置好 LLM');

    final gateway = DioLlmClient(loadConfig: () => config);
    // 纠错走「纠错专用模型」配置（与 correctionPipelineProvider 同语义），留空则跟随制谱模型
    final corrConfig = await loadCorrectionConfig();
    // ignore: avoid_print
    print('纠错模型: ${corrConfig == null ? '跟随制谱模型(${config.model})' : corrConfig.model} '
        'baseUrl=${corrConfig?.baseUrl ?? config.baseUrl} '
        'key=${corrConfig == null ? '同制谱' : '${corrConfig.apiKey.length}字符'}');
    final corrGateway =
        corrConfig != null ? DioLlmClient(loadConfig: () => corrConfig) : gateway;
    final images = [
      r'K:\曲谱图片\A小调华尔兹\A小调华尔兹-1.jpg',
      r'K:\曲谱图片\A小调华尔兹\A小调华尔兹-2.jpg',
    ];
    final pages = [
      PageInput(pageIndex: 1, imagePath: images[0]),
      PageInput(pageIndex: 2, imagePath: images[1]),
    ];

    // 第 1 步：真实制谱（盲识别的对照基准 = 真实图片内容）。
    // 制谱结果缓存到系统临时目录：重跑免重复计费，也避开制谱模型抖动
    // （glm-5.3-flash 偶发连续 3 次 measure_overfull，会拖垮整个实验）。
    // 只在全部页都成功时写缓存，避免缓存半成品。
    final cacheFile = File(
        '${Directory.systemTemp.path}/ejmusic_correction_real_gen_cache.json');
    final cachedJson =
        cacheFile.existsSync() ? cacheFile.readAsStringSync() : '';
    final ScoreDocument doc;
    final List<PageSliceSpec> slices;
    if (cachedJson.isNotEmpty) {
      final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
      final merged = PageMerger.merge(
        fragments: [
          for (final f in cached['fragments'] as List)
            PageFragment.fromJson(f as Map<String, dynamic>),
        ],
        kind: 'piano',
      );
      doc = merged.document;
      slices = merged.slices;
      // ignore: avoid_print
      print('制谱缓存命中：${doc.parts.first.measures.length} 小节');
    } else {
      final gen = GenerationPipeline(gateway: gateway);
      final genResult = await gen.run(kind: 'piano', pages: pages);
      expect(genResult.document, isNotNull, reason: '制谱须成功才能纠错');
      final frags = [
        for (final p in genResult.pages)
          if (p.ok && p.fragment != null) p.fragment!,
      ];
      expect(frags.length, pages.length,
          reason: '所有页制谱成功才能继续（失败页会让切片/注入失真）');
      cacheFile.writeAsStringSync(jsonEncode({
        'images': images,
        'fragments': [for (final f in frags) f.toJson()],
      }));
      final merged = PageMerger.merge(fragments: frags, kind: 'piano');
      doc = merged.document;
      slices = merged.slices;
      // ignore: avoid_print
      print('制谱完成：${doc.parts.first.measures.length} 小节（已缓存）');
    }
    final measures = doc.parts.first.measures;
    final boundaryIdx = <int>{
      for (final s in slices)
        for (final ms in s.measures)
          if (ms.boundary) ms.measureIndex,
    };

    // 第 2 步：向非跨页小节的单音音符注入错音（改 step / octave）
    final injections = <({int mi, int staff, int voiceNo, int ei, String from})>[];
    const steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    for (var mi = 1;
        mi < measures.length - 1 && injections.length < 6;
        mi++) {
      if (boundaryIdx.contains(mi)) continue;
      for (final v in measures[mi].voices) {
        for (var ei = 0;
            ei < v.events.length && injections.length < 6;
            ei++) {
          final e = v.events[ei];
          if (!e.isNote || e.pitches.length != 1) continue;
          final p = e.pitches.first;
          // 隔几个事件取样，避免集中在同一处
          if ((ei + mi) % 3 != 0) continue;
          final from = '${p.step}${p.octave}';
          if (injections.length.isEven) {
            // 改 step（±1，B→C / C→B 时同时动八度保持简单：直接换相邻音名）
            final i = steps.indexOf(p.step);
            final next = steps[(i + (i < 6 ? 1 : -2)) % 7];
            p.step = next;
          } else {
            p.octave += p.octave < 6 ? 1 : -1;
          }
          injections.add((
            mi: mi,
            staff: v.staff,
            voiceNo: v.voiceNo,
            ei: ei,
            from: from,
          ));
        }
        if (injections.length >= 6) break;
      }
    }
    expect(injections.length, greaterThanOrEqualTo(4),
        reason: '注入点太少，验证无意义');
    // ignore: avoid_print
    print('注入 ${injections.length} 处错音：');
    for (final inj in injections) {
      // ignore: avoid_print
      print('  m${inj.mi + 1} staff${inj.staff} 第${inj.ei + 1}个事件: '
          '${inj.from} → 已篡改');
    }

    // 第 3 步：盲识别纠错（对照原图，注入处应被还原）
    final correction = CorrectionPipeline(gateway: corrGateway);
    final sw = Stopwatch()..start();
    final result = await correction.run(
      kind: 'piano',
      doc: doc,
      slices: slices,
      pages: pages,
    );
    // ignore: avoid_print
    print('纠错耗时 ${sw.elapsed}');
    for (final p in result.pages) {
      // ignore: avoid_print
      print('页${p.pageIndex}: ok=${p.ok} unchanged=${p.unchanged} '
          'attempts=${p.attempts} 改动=${p.changes.length} error=${p.error}');
    }
    for (final w in result.warnings) {
      // ignore: avoid_print
      print('告警: $w');
    }

    // 第 4 步：核对检出——注入错音所在小节应被标记为"疑似差异"（小节聚合），
    // 事件级命中另计（盲识别重新分段时事件序号会漂移，小节级才是可靠信号）
    final changedMeasures = <int>{
      for (final c in result.changes) c.measureIndex,
    };
    final injectedMeasures = <int>{for (final i in injections) i.mi};
    var detectedMeasures = 0;
    var detectedEvents = 0;
    for (final inj in injections) {
      final measureFlagged = changedMeasures.contains(inj.mi);
      if (measureFlagged) detectedMeasures++;
      final c = result.changes.where((c) =>
          c.measureIndex == inj.mi &&
          c.staff == inj.staff &&
          c.voiceNo == inj.voiceNo &&
          c.eventIndex == inj.ei).firstOrNull;
      final eventHit = c != null && c.after.contains(inj.from[0]) &&
          c.after.contains(inj.from[inj.from.length - 1]);
      if (eventHit) detectedEvents++;
      // ignore: avoid_print
      print(measureFlagged
          ? '${eventHit ? "✓✓" : "✓小节"} 检出 m${inj.mi + 1} ${inj.from}'
          : '✗ 漏检 m${inj.mi + 1} ${inj.from}');
    }
    // ignore: avoid_print
    print('小节级检出 $detectedMeasures / ${injectedMeasures.length} 个小节，'
        '事件级精确还原 $detectedEvents / ${injections.length}，'
        '候选改动共 ${result.changes.length} 处'
        '（聚合为 ${changedMeasures.length} 个小节）');
    for (final inj in injections) {
      final c = result.changes.where((c) =>
          c.measureIndex == inj.mi &&
          c.staff == inj.staff &&
          c.voiceNo == inj.voiceNo &&
          c.eventIndex == inj.ei).firstOrNull;
      if (c != null) {
        // ignore: avoid_print
        print('  注入点改动详情 m${inj.mi + 1} ${inj.from}: '
            '${changeKindLabel(c.kind)} ${c.before} → ${c.after}');
      }
    }
    expect(detectedMeasures, greaterThanOrEqualTo(injectedMeasures.length),
        reason: '每个注入错音的小节都应被盲识别差异标记（详见上方日志）');
  });
}
