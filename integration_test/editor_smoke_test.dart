// 编辑器冒烟：谱面点击选中 → 编辑对话框 → 插入/删除 → 放弃确认。
// 运行：flutter test integration_test/editor_smoke_test.dart -d windows
// 前置：真实数据库中已有种子曲「小星星（种入）」（tool/seed_score.dart）。
import 'package:ejmusic/features/editor/ui/editor_page.dart';
import 'package:ejmusic/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('编辑曲谱页冒烟（谱面点击）', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('小星星（种入）').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑曲谱'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 5));
    await tester.pump();

    // 谱面渲染 + 工具条
    expect(find.byType(InAppWebView), findsOneWidget);
    expect(find.text('曲谱信息'), findsOneWidget);
    expect(find.text('插入音符'), findsOneWidget);
    expect(find.textContaining('点击上方谱面'), findsOneWidget);

    // 派发真实 DOM 点击到第 3 个符头/休止符上（冒泡到 container 监听器）
    final sheet = EditorPage.debugSheet;
    expect(sheet, isNotNull);
    final glyphs = await sheet!.debugEvalJs('''
      return document.querySelectorAll('[class*="vf-notehead"],[class*="vf-rest"]').length;
    ''');
    expect(glyphs, greaterThan(3));
    EditorPage.debugSelectedStep = null;
    await sheet.debugEvalJs('''
      var els = document.querySelectorAll('[class*="vf-notehead"],[class*="vf-rest"]');
      var r = els[2].getBoundingClientRect();
      els[2].dispatchEvent(new MouseEvent('click', {
        clientX: r.left + r.width / 2,
        clientY: r.top + r.height / 2,
        bubbles: true
      }));
    ''');
    // 等 noteClicked 事件跨桥回来
    for (var i = 0; i < 20 && EditorPage.debugSelectedStep == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(EditorPage.debugSelectedStep, isNotNull);
    await tester.pump();
    expect(find.textContaining('已选中'), findsOneWidget);

    // 选中项打开编辑对话框后取消
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑事件'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 插入音符（无选中则追加，插完自动选中）→ 再删除，净零改动
    await tester.tap(find.text('插入音符'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('点击上方谱面'), findsOneWidget);

    // ---- 键盘：方向键选择、琴键输入、时值/附点、Insert ----
    // → 从无选中状态选中第一个事件
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.textContaining('已选中'), findsOneWidget);

    // 琴键 A = C4 四分音符（默认输入状态），插入在选中之后并成为新选中
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C4 1/1'), findsOneWidget);

    // . 加一个附点；琴键 W = C#4 → 附点四分（3/2）
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pump();
    expect(find.textContaining('+1附点'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C#4 3/2'), findsOneWidget);

    // 数字 4 = 八分音符；琴键 K = 高八度 C5
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C5 1/2'), findsOneWidget);

    // Insert 用当前输入状态插入 C4（八度 4、八分音符）
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C4 1/2'), findsOneWidget);

    // Z 降八度 → 状态条显示八度3
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(find.text('八度3 八分音符'), findsOneWidget);

    // 未保存退出 → 放弃确认
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('放弃修改？'), findsOneWidget);
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.text('演奏模式'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
