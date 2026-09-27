import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_settings.dart';
import 'features/convert/ui/convert_page.dart';
import 'features/correction/ui/correction_page.dart';
import 'features/editor/ui/editor_page.dart';
import 'features/generation/ui/generation_page.dart';
import 'features/import/ui/import_page.dart';
import 'features/library/ui/library_page.dart';
import 'features/library/ui/song_detail_page.dart';
import 'features/performance/ui/performance_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'features/viewer/ui/viewer_page.dart';

final appRouter = GoRouter(
  // 调试用：设 EJMUSIC_DEBUG_LOCATION 可让 App 启动直达指定页面
  initialLocation: Platform.environment['EJMUSIC_DEBUG_LOCATION'] ?? '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryPage(),
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) => const ImportPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/song/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return SongDetailPage(songId: id);
      },
    ),
    GoRoute(
      path: '/song/:id/generate',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return GenerationPage(songId: id);
      },
    ),
    GoRoute(
      path: '/song/:id/view',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return ViewerPage(songId: id);
      },
    ),
    GoRoute(
      path: '/song/:id/play',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return PerformancePage(songId: id);
      },
    ),
    GoRoute(
      path: '/song/:id/convert',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return ConvertPage(songId: id);
      },
    ),
    GoRoute(
      path: '/song/:id/correct',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return CorrectionPage(songId: id);
      },
    ),
    GoRoute(
      path: '/song/:id/edit',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('无效的曲目 ID')));
        }
        return EditorPage(songId: id);
      },
    ),
  ],
);

class EJMusicApp extends ConsumerStatefulWidget {
  const EJMusicApp({super.key});

  @override
  ConsumerState<EJMusicApp> createState() => _EJMusicAppState();
}

class _EJMusicAppState extends ConsumerState<EJMusicApp> {
  @override
  void initState() {
    super.initState();
    // 启动即触发配置加载，否则识别开始时读到 AsyncLoading 会回退成空配置
    ref.read(llmConfigProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EJMusic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C6FBF)),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
