// P3 端到端：演奏模式（跟弹判定 / 聆听播放）+ 谱式转换（在真实 Windows App 中跑）。
// 运行：flutter test integration_test/p3_flow_test.dart -d windows
// 前置：真实数据库中已有种子曲「小星星（种入）」（tool/seed_score.dart）。
import 'package:ejmusic/domain/performance/follow_judge.dart';
import 'package:ejmusic/features/performance/ui/performance_page.dart';
import 'package:ejmusic/features/performance/ui/piano_keyboard.dart';
import 'package:ejmusic/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

bool _isWhite(int m) => const {0, 2, 4, 5, 7, 9, 11}.contains(m % 12);

int _whiteIndex(int m, int kbLow) {
  const pos = {0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6};
  return (m ~/ 12 - kbLow ~/ 12) * 7 + pos[m % 12]!;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('演奏模式 + 谱式转换端到端', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 曲库 → 详情
    await tester.tap(find.text('小星星（种入）').first);
    await tester.pumpAndSettle();

    // 详情 → 演奏模式（加载曲谱 + 音频 + WebView）
    await tester.tap(find.text('演奏模式'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byType(PianoKeyboard), findsOneWidget);
    expect(find.text('点击「开始跟弹」'), findsOneWidget);
    final judge = PerformancePage.debugJudge;
    expect(judge, isNotNull);
    expect(judge!.phase, JudgePhase.idle);

    // ---- 跟弹模式 ----
    await tester.tap(find.text('开始跟弹'));
    await tester.pumpAndSettle();
    expect(judge.phase, JudgePhase.awaiting);
    expect(find.text('请按亮起的琴键'), findsOneWidget);

    final kbWidget =
        tester.widget<PianoKeyboard>(find.byType(PianoKeyboard));
    final kbLow = kbWidget.lowMidi;
    final kbHigh = kbWidget.highMidi;
    final kbRect = tester.getRect(find.byType(PianoKeyboard));
    var whites = 0;
    for (var m = kbLow; m <= kbHigh; m++) {
      if (_isWhite(m)) whites++;
    }
    final whiteW = kbRect.width / whites;
    Future<void> press(int midi) async {
      await tester.tapAt(Offset(
        kbRect.left + (_whiteIndex(midi, kbLow) + 0.5) * whiteW,
        kbRect.top + kbRect.height * 0.75,
      ));
      await tester.pump(const Duration(milliseconds: 40));
    }

    // 先按一个错键
    final wrongKey = [
      for (var m = kbLow; m <= kbHigh; m++)
        if (_isWhite(m) && !judge.expected.contains(m)) m,
    ].first;
    final wrongBefore = judge.wrongCount;
    await press(wrongKey);
    expect(judge.wrongCount, wrongBefore + 1);

    // 依提示按完所有和弦 → 完成对话框
    var guard = 0;
    while (!judge.isDone && guard++ < 400) {
      for (final m in judge.expected.toList()) {
        await press(m);
      }
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(judge.isDone, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('演奏完成'), findsOneWidget);
    expect(judge.accuracy, inExclusiveRange(0.9, 1.0));
    await tester.tap(find.text('好的'));
    await tester.pump(const Duration(milliseconds: 400));

    // ---- 聆听模式 ----
    await tester.tap(find.text('聆听'));
    await tester.pumpAndSettle();
    expect(PerformancePage.debugJudge!.mode, FollowMode.listen);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 5));
    await tester.pump();
    final listenJudge = PerformancePage.debugJudge!;
    expect(listenJudge.noteIndex,
        allOf(greaterThanOrEqualTo(2), lessThan(listenJudge.notes.length)));
    expect(find.byIcon(Icons.stop), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump(const Duration(milliseconds: 300));

    // 返回详情 → 谱式转换
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('谱式转换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始转换'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('查看转换结果'), findsOneWidget);

    // 转换结果（吉他版）可打开渲染
    await tester.tap(find.text('查看转换结果'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    // 诊断：若 WebView 缺失，打印当前页面实际内容
    if (find.byType(InAppWebView).evaluate().isEmpty) {
      // ignore: avoid_print
      print('DIAG fallbackText='
          '${find.text('曲谱尚未制作完成，请先完成「制作曲谱」').evaluate().isNotEmpty} '
          'stillOnConvert='
          '${find.textContaining('谱式转换').evaluate().isNotEmpty}');
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | ');
      // ignore: avoid_print
      print('DIAG texts=$texts');
      debugDumpApp();
    }
    expect(find.byType(InAppWebView), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
