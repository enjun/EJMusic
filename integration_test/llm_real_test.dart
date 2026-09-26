import 'dart:convert';
import 'dart:io';

import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/data/llm/image_preprocess.dart';
import 'package:ejmusic/data/llm/llm_client.dart';
import 'package:ejmusic/data/llm/prompts.dart';
import 'package:ejmusic/features/generation/logic/generation_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真实端到端：真实配置 + 真实扫描图 + 真实 LLM + 真实校验管线。
/// 仅手动/本地运行：flutter test integration_test/llm_real_test.dart -d windows
/// 不写数据库；调外部 API 产生真实计费，勿进 CI。
void main() {
  test('真实制谱管线：A小调华尔兹 2 页', timeout: const Timeout(Duration(minutes: 25)),
      () async {
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
    for (final p in images) {
      expect(File(p).existsSync(), isTrue, reason: '测试图片缺失: $p');
    }

    // 第 1 步：裸网关调用，看模型原始输出质量与耗时
    final sw = Stopwatch()..start();
    final raw = await gateway.completeJson(
      system: Prompts.system('piano'),
      user: Prompts.user(pageIndex: 1, kind: 'piano'),
      imageJpegBase64: [
        base64Encode(ImagePreprocess.compress(File(images.first).readAsBytesSync())),
      ],
    );
    // ignore: avoid_print
    print('裸调用耗时 ${sw.elapsed}，输出 ${raw.length} 字符');
    // ignore: avoid_print
    print('raw 前 300 字符: ${raw.substring(0, raw.length < 300 ? raw.length : 300)}');
    final jsonStr = DioLlmClient.extractJson(raw);
    final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
    // ignore: avoid_print
    print('extractJson OK，顶层字段: ${obj.keys.toList()}');

    // 第 2 步：完整管线（含校验与回喂修复）
    final pipeline = GenerationPipeline(gateway: gateway);
    final result = await pipeline.run(
      kind: 'piano',
      pages: [
        PageInput(pageIndex: 1, imagePath: images[0]),
        PageInput(pageIndex: 2, imagePath: images[1]),
      ],
    );
    for (final p in result.pages) {
      // ignore: avoid_print
      print('页${p.pageIndex}: ok=${p.ok} attempts=${p.attempts} '
          '小节=${p.fragment?.measures.length ?? 0} error=${p.error}');
    }
    // ignore: avoid_print
    print('合并警告: ${result.mergeWarnings}');
    expect(result.okCount, result.pages.length,
        reason: '全部页应识别成功；失败原因见上方日志');
    expect(result.document, isNotNull);
    // ignore: avoid_print
    print('总小节数: ${result.document!.parts.first.measures.length}');
  });
}
