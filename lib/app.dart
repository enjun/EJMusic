import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/generation/ui/generation_page.dart';
import 'features/import/ui/import_page.dart';
import 'features/library/ui/library_page.dart';
import 'features/library/ui/song_detail_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'features/viewer/ui/viewer_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
  ],
);

class EJMusicApp extends StatelessWidget {
  const EJMusicApp({super.key});

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
