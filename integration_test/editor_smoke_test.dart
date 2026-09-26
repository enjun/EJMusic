// 编辑器冒烟：打开已制谱曲目的编辑页、事件对话框、脏状态与放弃确认。
// 运行：flutter test integration_test/editor_smoke_test.dart -d windows
// 前置：真实数据库中已有种子曲「小星星（种入）」（tool/seed_score.dart）。
import 'package:ejmusic/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('编辑曲谱页冒烟', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('小星星（种入）').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑曲谱'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.pump();

    // 小节卡片与事件 chips 渲染
    expect(find.text('曲谱信息'), findsOneWidget);
    expect(find.textContaining('第 '), findsWidgets);
    expect(find.byType(ActionChip), findsWidgets);

    // 打开事件编辑对话框并取消
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    expect(find.text('编辑事件'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 改 BPM 触发脏状态 → 返回弹出放弃确认
    final bpmField = find.widgetWithText(TextField, 'BPM');
    expect(bpmField, findsOneWidget);
    await tester.enterText(bpmField, '120');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('放弃修改？'), findsOneWidget);

    // 继续编辑 → 撤销还原 → 可直接返回
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('放弃修改？'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    // 回到详情页
    expect(find.text('演奏模式'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
