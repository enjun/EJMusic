import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../library/library_providers.dart';
import '../logic/convert_controller.dart';

/// 谱式转换页：钢琴谱 ↔ 吉他谱。
class ConvertPage extends ConsumerWidget {
  const ConvertPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songProvider(songId));
    final state = ref.watch(convertControllerProvider(songId));
    final song = songAsync.value;

    final targetKind = song?.kind == 'piano' ? '吉他谱（六线谱）' : '钢琴谱（大谱表）';

    return Scaffold(
      appBar: AppBar(title: Text('谱式转换 · ${song?.title ?? ''}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('源曲谱：${song?.title ?? ''}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('类型：${song?.kind == 'piano' ? '钢琴谱' : '吉他谱'} · '
                        '${song?.bpm ?? '-'} BPM'),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.arrow_downward, size: 18),
                      const SizedBox(width: 6),
                      Text('转换为：$targetKind'),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.running ? null : () => _convert(ref),
              icon: state.running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.swap_horiz),
              label: Text(state.running ? '转换中…' : '开始转换'),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('转换失败：${state.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (state.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in state.warnings) Text('· $w'),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            if (state.resultSongId != null)
              FilledButton.tonalIcon(
                onPressed: () =>
                    context.push('/song/${state.resultSongId}/view'),
                icon: const Icon(Icons.music_note),
                label: const Text('查看转换结果'),
              ),
          ],
        ),
      ),
    );
  }

  void _convert(WidgetRef ref) {
    ref.read(convertControllerProvider(songId).notifier).convert();
  }
}
