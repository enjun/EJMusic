// sheet.html 宿主页滚动行为：谱面可滚动 + 光标跟随自动滚动 + 重置回顶。
// 运行：flutter test integration_test/sheet_scroll_test.dart -d windows
import 'dart:async';

import 'package:ejmusic/data/render/sheet_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 48 小节 4/4，每小节 4 个四分音符 C5，足够高以产生纵向滚动
/// （webview 视口按 raw 像素布局时约 800×600，24 小节可能不满一屏）。
String buildScoreXml() {
  final sb = StringBuffer();
  for (var m = 1; m <= 48; m++) {
    sb.write('<measure number="$m">');
    if (m == 1) {
      sb.write('<attributes><divisions>1</divisions>'
          '<key><fifths>0</fifths></key>'
          '<time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>');
    }
    for (var n = 0; n < 4; n++) {
      sb.write('<note><pitch><step>C</step><octave>5</octave></pitch>'
          '<duration>1</duration><type>quarter</type></note>');
    }
    sb.write('</measure>');
  }
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<score-partwise version="3.1">'
      '<part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>'
      '<part id="P1">$sb</part>'
      '</score-partwise>';
}

Future<Map<String, num>> pageMetrics(InAppWebViewController w) async {
  final r = await w.callAsyncJavaScript(functionBody: '''
    return { sh: document.body.scrollHeight,
             ch: document.body.clientHeight,
             sy: window.scrollY };
  ''');
  final value = r?.value as Map? ?? const {};
  return value.map((k, v) => MapEntry('$k', v is num ? v : 0));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('谱面可滚动且光标跟随滚动', timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
    final controller = SheetWebviewController();
    final events = <SheetEvent>[];
    InAppWebViewController? webview;
    final loaded = Completer<void>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: await buildSheetHostHtml(),
              mimeType: 'text/html',
              encoding: 'utf-8',
            ),
            initialSettings: InAppWebViewSettings(transparentBackground: false),
            onWebViewCreated: (w) {
              webview = w;
              controller.attach(w);
              controller.events.listen(events.add);
              w.addJavaScriptHandler(
                  handlerName: 'ejm',
                  callback: (args) {
                    final m = args.isNotEmpty ? args.first : null;
                    if (m is Map) controller.handleEvent(SheetEvent.from(m));
                    return null;
                  });
            },
            onLoadStop: (_, _) async {
              await Future.delayed(const Duration(milliseconds: 300));
              await controller.loadMusicXml(buildScoreXml());
              loaded.complete();
            },
          ),
        ),
      ),
    ));

    await loaded.future.timeout(const Duration(seconds: 30));
    // 轮询等渲染结果事件（events 是列表，非流）
    SheetEvent? first;
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (first == null) {
      for (final e in events) {
        if (e is SheetReady || e is SheetError) {
          first = e;
          break;
        }
      }
      if (first != null) break;
      if (DateTime.now().isAfter(deadline)) fail('40s 内未收到渲染结果事件');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    expect(first, isA<SheetReady>(), reason: '渲染应成功');
    final total = (first as SheetReady).totalSteps;
    expect(total, 192, reason: '48 小节 × 每小节 4 拍 = 192 步，实得 $total');

    final w = webview!;
    // 谱面总高必须超过视口，否则谈不上滚动
    final m0 = await pageMetrics(w);
    expect(m0['sh'], greaterThan(m0['ch'] as num),
        reason: '渲染高度 ${m0['sh']} 应超过视口 ${m0['ch']}，谱面应可滚动');

    // 光标移到最后 → 页面应自动滚动跟随（到达最大滚动位置）
    await controller.cursorTo(total);
    await Future.delayed(const Duration(milliseconds: 1500));
    final m1 = await pageMetrics(w);
    final maxScroll = (m1['sh'] as num) - (m1['ch'] as num);
    expect(m1['sy'] as num, greaterThan(maxScroll * 0.8),
        reason: '光标到底后页面应滚到接近最大位置 '
            '(scrollY=${m1['sy']}, maxScroll=$maxScroll)');

    // 光标回起点 → 应回滚到顶部
    await controller.cursorReset();
    await Future.delayed(const Duration(milliseconds: 1500));
    final m2 = await pageMetrics(w);
    expect(m2['sy'] as num, lessThan(100),
        reason: '重置后应滚回顶部（scrollY=${m2['sy']}）');
  });
}
