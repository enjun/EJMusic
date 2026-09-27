// 编辑器冒烟：谱面点击选中 → 编辑对话框 → 插入/删除 → 放弃确认。
// 运行：flutter test integration_test/editor_smoke_test.dart -d windows
// 前置：真实数据库中已有种子曲「小星星（种入）」（tool/seed_score.dart）。
import 'package:ejmusic/data/render/sheet_webview.dart';
import 'package:ejmusic/features/editor/ui/editor_page.dart';
import 'package:ejmusic/main.dart' as app;
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // 编辑触发防抖重渲染后，蓝选中与绿光标都应落回当前选中音符上
  //（而不是跳回小节开头/曲首）。绿光标 = container 里唯一的光标 img。
  Future<void> expectCursorOnSelection(
      SheetWebviewController sheet, WidgetTester tester) async {
    // 等防抖渲染 + 重渲染完成
    await Future.delayed(const Duration(seconds: 2));
    await tester.pump();
    final v = await sheet.debugEvalJs('''
      return (function () {
        var glyphs = document.querySelectorAll(
          '[class*="vf-notehead"],[class*="vf-rest"]');
        var sel = null;
        var anyFill = '';
        for (var i = 0; i < glyphs.length; i++) {
          if (glyphs[i].style && glyphs[i].style.fill) {
            anyFill += i + ':' + glyphs[i].style.fill + ' ';
          }
          if (!sel && glyphs[i].style
              && glyphs[i].style.fill === 'rgb(26, 115, 232)') {
            sel = glyphs[i];
          }
        }
        if (!sel) {
          return JSON.stringify({err: 'no-blue', glyphs: glyphs.length,
            anyFill: anyFill, hl: window.__ejmLastHighlight || null,
            inv: window.__ejmInvCount || 0,
            svgCount: document.querySelectorAll('#container svg').length});
        }
        var imgs = document.querySelectorAll('#container img');
        if (!imgs.length) return JSON.stringify({err: 'no-cursor'});
        var r1 = sel.getBoundingClientRect();
        var r2 = imgs[0].getBoundingClientRect();
        var dx = Math.abs((r1.left + r1.width / 2) - (r2.left + r2.width / 2));
        var dy = Math.abs((r1.top + r1.height / 2) - (r2.top + r2.height / 2));
        return JSON.stringify({dx: Math.round(dx), dy: Math.round(dy)});
      })()
    ''');
    expect(v, isNotNull);
    final m = jsonDecode(v.toString()) as Map<String, dynamic>;
    expect(m.containsKey('err'), isFalse,
        reason: '编辑后高亮恢复失败: $m');
    expect((m['dx'] as num), lessThan(25),
        reason: '绿光标未落在选中音符上: $m');
    expect((m['dy'] as num), lessThan(25),
        reason: '绿光标未落在选中音符上: $m');
  }


  testWidgets('编辑曲谱页冒烟（谱面点击）', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('小星星（种入）').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑曲谱'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 5));
    await tester.pump();

    // 谱面渲染 + 工具条（曲谱信息卡默认收起为入口条）
    expect(find.byType(InAppWebView), findsOneWidget);
    expect(find.textContaining('曲谱信息'), findsOneWidget);
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
    // 编辑后重渲染：高亮（蓝选中+绿光标）应恢复在新插入的音符上
    await expectCursorOnSelection(sheet, tester);

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
    await expectCursorOnSelection(sheet, tester);

    // Insert 用当前输入状态插入 C4（八度 4、八分音符）
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C4 1/2'), findsOneWidget);

    // Shift+琴键：加音成和弦。Shift+K = C5 追加到 C4 → C4+C5
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C4+C5 1/2'), findsOneWidget);

    // 重复同音去重：仍为两音
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('已选中：C4+C5 1/2'), findsOneWidget);

    // Shift+E = D#4 → 三音和弦
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('已选中：C4+C5+D#4 1/2'), findsOneWidget);
    await expectCursorOnSelection(sheet, tester);

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
