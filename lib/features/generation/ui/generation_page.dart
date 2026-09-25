import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/generation_controller.dart';
import '../logic/generation_pipeline.dart';

/// 制作进度页：逐页识别状态 + 单页重试。
class GenerationPage extends ConsumerWidget {
  const GenerationPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generationControllerProvider(songId));
    final total = state.pages.length;
    final ok = state.okCount;

    return Scaffold(
      appBar: AppBar(title: const Text('制作曲谱')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? null : ok / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$ok / $total 页'),
                  ],
                ),
                if (state.resultMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(state.resultMessage!,
                      style: TextStyle(color: Colors.green.shade700)),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 8),
                  Text(state.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          Expanded(
            child: state.pages.isEmpty
                ? const Center(child: Text('尚无页面'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.pages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = state.pages[i];
                      return _PageTile(
                        progress: p,
                        enabled: !state.running,
                        onRetry: () => ref
                            .read(generationControllerProvider(songId).notifier)
                            .retryPage(p.pageIndex),
                      );
                    },
                  ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: state.running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high),
                    label: Text(state.running ? '识别中…' : '开始制作'),
                    onPressed: state.running
                        ? null
                        : () => ref
                            .read(generationControllerProvider(songId).notifier)
                            .start(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('查看曲谱'),
                    onPressed: () => context.push('/song/$songId/view'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.progress,
    required this.enabled,
    required this.onRetry,
  });

  final PageProgress progress;
  final bool enabled;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (progress.status) {
      'ok' => (Icons.check_circle, Colors.green.shade600, '识别成功'),
      'running' => (
          Icons.autorenew,
          Theme.of(context).colorScheme.primary,
          '识别中（第 ${progress.attempts} 次）'
        ),
      'failed' => (Icons.error_outline, Theme.of(context).colorScheme.error, '失败'),
      _ => (Icons.radio_button_unchecked, Colors.grey, '待识别'),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('第 ${progress.pageIndex} 页'),
        subtitle: progress.error != null
            ? Text(progress.error!, maxLines: 3, overflow: TextOverflow.ellipsis)
            : Text(label, style: TextStyle(color: color, fontSize: 12)),
        trailing: progress.status == 'failed' && enabled
            ? TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
