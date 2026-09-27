import 'dart:convert';

import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:ejmusic/domain/score/correct/score_diff.dart';
import 'package:ejmusic/domain/score/merge/page_merger.dart';
import 'package:ejmusic/features/correction/logic/correction_pipeline.dart';
import 'package:ejmusic/features/correction/ui/change_review_list.dart'
    show changeKindLabel;
import 'package:ejmusic/features/generation/logic/generation_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真实端到端纠错：真实制谱（产出待纠错的谱）→ 逐页原图+切片对照纠错。
/// 仅手动/本地运行：flutter test integration_test/correction_real_test.dart -d windows
/// 不写数据库；调外部 API 产生真实计费，勿进 CI。
void main() {
  test('真实纠错管线：A小调华尔兹 2 页',
      timeout: const Timeout(Duration(minutes: 40)), () async {
    final config = await loadLlmConfig();
    // ignore: avoid_print
    print('config: baseUrl=${config.baseUrl} model=${config.model} '
        'key=${config.apiKey.isEmpty ? '空' : '${config.apiKey.length}字符'}');
    expect(config.isConfigured, isTrue, reason: '本机需先在应用里配置好 LLM');

    final gateway = DioLlmClient(loadConfig: () => config);
    final images = [
      r'K:\曲谱图片\A小调华尔兹\A小调华尔兹-1.jpg',
      r'K:\曲谱图片\A小调华尔兹\A小调华尔兹-2.jpg',
    ];
    final pages = [
      PageInput(pageIndex: 1, imagePath: images[0]),
      PageInput(pageIndex: 2, imagePath: images[1]),
    ];

    // 第 1 步：真实制谱（同应用路径，产出含识别错误的谱）
    final gen = GenerationPipeline(gateway: gateway);
    final genResult = await gen.run(kind: 'piano', pages: pages);
    for (final p in genResult.pages) {
      // ignore: avoid_print
      print('制谱 页${p.pageIndex}: ok=${p.ok} attempts=${p.attempts} '
          'error=${p.error}');
    }
    expect(genResult.document, isNotNull, reason: '制谱须成功才能纠错');
    final doc = genResult.document!;
    // ignore: avoid_print
    print('制谱完成：${doc.parts.first.measures.length} 小节，'
        '合并警告 ${genResult.mergeWarnings.length} 条');

    // 成功片段重合并出页所有权规格（同 prepareCorrection 语义）
    final frags = [
      for (final p in genResult.pages)
        if (p.ok && p.fragment != null) p.fragment!,
    ];
    final slices = PageMerger.merge(fragments: frags, kind: 'piano').slices;

    // 第 2 步：逐页纠错（真实对照原图）
    final correction = CorrectionPipeline(gateway: gateway);
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
      print('纠错 页${p.pageIndex}: ok=${p.ok} unchanged=${p.unchanged} '
          'attempts=${p.attempts} 改动=${p.changes.length} '
          'largeDiff=${p.largeDiff} error=${p.error}');
    }
    for (final w in result.warnings) {
      // ignore: avoid_print
      print('告警: $w');
    }
    for (final c in result.changes.take(20)) {
      // ignore: avoid_print
      print('改动 m${c.measureNumber} '
          '${changeKindLabel(c.kind)}: ${c.before} → ${c.after}');
    }

    // 结构断言：成功的页改动必须定位合法（可应用）
    var okPages = 0;
    for (final p in result.pages) {
      if (!p.ok) continue;
      okPages++;
      final measures = doc.parts.first.measures;
      for (final c in p.changes) {
        expect(c.measureIndex, inExclusiveRange(-1, measures.length),
            reason: '改动小节下标越界');
      }
    }
    expect(okPages, result.pages.length, reason: '全部页纠错应成功（失败见日志）');
    // ignore: avoid_print
    print('共 ${result.changes.length} 处候选修改、${result.warnings.length} 条告警');
  });
}
