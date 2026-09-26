import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../library_providers.dart';

/// 曲目详情：元信息 + 源扫描图（P2 将加入交互曲谱渲染与演奏入口）。
class SongDetailPage extends ConsumerWidget {
  const SongDetailPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songProvider(songId));
    final pagesAsync = ref.watch(songSourceImagesProvider(songId));

    return Scaffold(
      appBar: AppBar(
        title: Text(songAsync.value?.title ?? '曲谱详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: songAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (song) {
          if (song == null) return const Center(child: Text('曲目不存在'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(song.title, style: Theme.of(context).textTheme.headlineSmall),
              if (song.composer?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(song.composer!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _meta('谱式', song.kind == 'guitar' ? '吉他谱' : '钢琴谱'),
                  if (song.bpm != null) _meta('速度', '${song.bpm} BPM'),
                  if (song.timeBeats != null && song.timeBeatType != null)
                    _meta('拍号', '${song.timeBeats}/${song.timeBeatType}'),
                  _meta('页数', '${song.pageCount}'),
                ],
              ),
              const Divider(height: 32),
              _actionBar(context, song),
              const Divider(height: 32),
              Text('曲谱原图', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              pagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('图片加载失败：$e'),
                data: (images) => images.isEmpty
                    ? const Text('无源图片')
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: images.length,
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(images[i].absPath),
                            fit: BoxFit.cover,
                            cacheWidth: 440,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(
                                    color: Colors.black12,
                                    child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionBar(BuildContext context, Song song) {
    final status = songStatusFromName(song.status);
    final generating = status == SongStatus.generating;
    final hasScore = song.scorePath != null;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: Icon(generating
                    ? Icons.hourglass_top
                    : status == SongStatus.ready || status == SongStatus.partial
                        ? Icons.refresh
                        : Icons.auto_fix_high),
                label: Text(switch (status) {
                  SongStatus.ready ||
                  SongStatus.partial =>
                    song.scorePath == null ? '开始制作' : '重新制作',
                  SongStatus.generating => '制作中…',
                  _ => '开始制作',
                }),
                onPressed: generating
                    ? null
                    : () => context.push('/song/$songId/generate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text('查看曲谱'),
                onPressed: song.musicxmlCachePath == null
                    ? null
                    : () => context.push('/song/$songId/view'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.piano),
                label: const Text('演奏模式'),
                onPressed: hasScore
                    ? () => context.push('/song/$songId/play')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('谱式转换'),
                onPressed: hasScore
                    ? () => context.push('/song/$songId/convert')
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑曲谱'),
                onPressed: hasScore
                    ? () => context.push('/song/$songId/edit')
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _meta(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除曲目'),
        content: const Text('将删除曲目记录与页信息（源图片文件不受影响）。确定删除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appDatabaseProvider).songsDao.deleteSong(songId);
    if (context.mounted) Navigator.of(context).pop();
  }
}
