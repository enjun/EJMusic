// 演奏模式增强：快捷键（空格暂停/继续、K 键盘开关、Esc 重开、+/- 调速）。
// 运行：flutter test integration_test/perf_shortcut_test.dart -d windows
// 前置：真实数据库中已有种子曲「小星星（种入）」（tool/seed_score.dart）。
import 'package:ejmusic/features/performance/ui/piano_keyboard.dart';
import 'package:ejmusic/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('演奏快捷键：空格/K/Esc/+/-', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('小星星（种入）').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('演奏模式'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byType(PianoKeyboard), findsOneWidget);

    // ---- 聆听模式 ----
    await tester.tap(find.text('聆听'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    // 空格开始播放
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await Future.delayed(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // +/- 调速（模拟器没有 numpad add 的物理键，用 = 键，快捷键两者都映射）
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);

    // 空格暂停
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsNothing);

    // 再按空格继续
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // K 隐藏/显示键盘
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byType(PianoKeyboard), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byType(PianoKeyboard), findsOneWidget);

    // Esc 重新开始（停止播放）
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
