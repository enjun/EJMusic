import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../library_providers.dart';

SongStatus _parseStatus(String name) => songStatusFromName(name);

/// 曲库首页。
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的曲谱库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/import'),
        icon: const Icon(Icons.add),
        label: const Text('导入曲谱'),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 80,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                  const SizedBox(height: 12),
                  const Text('曲库还是空的'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/import'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('从目录导入曲谱图片'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(_kindIcon(song.kind)),
                ),
                title: Text(song.title),
                subtitle: Text([
                  if (song.composer?.isNotEmpty == true) song.composer!,
                  '${song.pageCount} 页',
                ].join(' · ')),
                trailing: _StatusChip(status: _parseStatus(song.status)),
                onTap: () => context.push('/song/${song.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

String _kindIcon(String kind) => kind == 'guitar' ? '🎸' : '🎹';

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SongStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SongStatus.grouped => ('待制作', Colors.orange),
      SongStatus.generating => ('制作中', Colors.blue),
      SongStatus.ready => ('已完成', Colors.green),
      SongStatus.partial => ('部分完成', Colors.amber),
      SongStatus.failed => ('失败', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9))),
    );
  }
}
