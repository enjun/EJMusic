import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ejmusic/app.dart';
import 'package:ejmusic/core/config/app_settings.dart';
import 'package:ejmusic/core/db/database.dart';
import 'package:ejmusic/features/import/logic/import_controller.dart';

void main() {
  const fixtureDir = String.fromEnvironment(
    'IMPORT_FIXTURE_DIR',
    defaultValue: r'D:\workspace\git\EJMusic\test_fixtures\扫描图',
  );

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const EJMusicApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  /// 在真实异步区执行扫描并等待 pHash 计算完成。
  Future<void> scanAndWait(WidgetTester tester, ProviderContainer container) async {
    await tester.runAsync(() async {
      final controller = container.read(importControllerProvider.notifier);
      await controller.scanDirectory(fixtureDir);
      for (var i = 0; i < 240; i++) {
        final s = container.read(importControllerProvider);
        if (s.phashTotal > 0 && s.phashDone >= s.phashTotal) return;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      fail('pHash 计算超时');
    });
  }

  testWidgets('P1 端到端：扫描分组 → 导入 → 曲库展示', (tester) async {
    final container = await pumpApp(tester);

    // 曲库初始为空
    expect(find.text('曲库还是空的'), findsOneWidget);

    // 导航到导入页
    await tester.tap(find.text('从目录导入曲谱图片'));
    await tester.pumpAndSettle();
    expect(find.text('导入曲谱图片'), findsOneWidget);

    // 直接扫描测试目录（绕开原生目录选择对话框）
    await scanAndWait(tester, container);
    await tester.pump(const Duration(milliseconds: 500));

    // 3 首曲子各成一组
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('开始导入（3 首）'), findsOneWidget);

    // 首次导入无重复 → 普通确认对话框
    await tester.tap(find.byIcon(Icons.library_add));
    await tester.pumpAndSettle();
    expect(find.text('曲库查重'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '继续导入'));
    await tester.pumpAndSettle();

    // 回到曲库，应展示 3 首
    expect(find.text('我的曲谱库'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('小星星'), findsOneWidget);
    expect(find.text('Canon_in_D'), findsOneWidget);
    expect(find.text('夜曲'), findsOneWidget);

    // 数据库校验：每组 2 页
    final songs = await db.songsDao.listSongs();
    expect(songs.length, 3);
    for (final song in songs) {
      expect(song.pageCount, 2, reason: '${song.title} 应有 2 页');
      expect(song.titleNorm, isNotEmpty);
    }
    final images = await db.select(db.sourceImages).get();
    expect(images.length, 6);
    // 所有图片都计算出了指纹
    expect(images.where((i) => i.phash != null).length, 6);
  });

  testWidgets('P1 端到端：重复导入同目录触发去重提示', (tester) async {
    final container = await pumpApp(tester);

    // 导航到导入页
    await tester.tap(find.text('从目录导入曲谱图片'));
    await tester.pumpAndSettle();

    // 第一次导入
    await scanAndWait(tester, container);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.library_add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '继续导入'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    // 回到曲库后，再次进入导入页
    await tester.tap(find.text('导入曲谱'));
    await tester.pumpAndSettle();

    // 第二次导入同目录
    await scanAndWait(tester, container);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.library_add));
    await tester.pumpAndSettle();

    // 应弹出"发现疑似重复"对话框
    expect(find.text('发现疑似重复'), findsOneWidget);
    expect(find.textContaining('与曲库重复'), findsWidgets);

    // 勾选跳过所有重复组后确认
    final checkboxes = find.byType(CheckboxListTile);
    expect(checkboxes, findsWidgets);
    for (var i = checkboxes.evaluate().length - 1; i >= 0; i--) {
      await tester.tap(checkboxes.at(i));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();

    // 曲库不应新增（全部跳过）
    final songs = await db.songsDao.listSongs();
    expect(songs.length, 3, reason: '跳过重复后不应新增曲目');
  });
}
