import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/components.dart';
import '../logic/generation_controller.dart';
import '../logic/generation_pipeline.dart';

/// 制作进度页：总体进度 + 逐页识别状态与单页重试。
class GenerationPage extends ConsumerWidget {
  const GenerationPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generationControllerProvider(songId));
    final pages = state.pages;
    final total = pages.length;
    final ok = state.okCount;
    final failed = pages.where((p) => p.status == 'failed').length;
    final runningCount = pages.where((p) => p.status == 'running').length;
    final progress = total == 0 ? 0.0 : ok / total;

    return Scaffold(
      appBar: AppBar(title: const Text('制作曲谱')),
      body: CenteredBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressHeader(
              progress: progress,
              ok: ok,
              failed: failed,
              running: runningCount,
              total: total,
              isRunning: state.running,
            ),
            if (state.resultMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              StatusBanner(
                message: state.resultMessage!,
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              StatusBanner(message: state.error!),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: pages.isEmpty
                  ? const EmptyHint(
                      icon: Icons.description_outlined,
                      title: '尚无页面',
                      message: '扫描图尚未导入，请先在曲目详情中导入曲谱图片。',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      itemCount: pages.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, i) {
                        final p = pages[i];
                        return _PageTile(
                          progress: p,
                          enabled: !state.running,
                          onRetry: () => ref
                              .read(
                                generationControllerProvider(songId).notifier,
                              )
                              .retryPage(p.pageIndex),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: state.running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high, size: 20),
                    label: Text(state.running ? '识别中…' : '开始制作'),
                    onPressed: state.running
                        ? null
                        : () => ref
                              .read(
                                generationControllerProvider(songId).notifier,
                              )
                              .start(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.visibility, size: 20),
                    label: const Text('查看曲谱'),
                    onPressed: () => context.push('/song/$songId/view'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.progress,
    required this.ok,
    required this.failed,
    required this.running,
    required this.total,
    required this.isRunning,
  });

  final double progress;
  final int ok;
  final int failed;
  final int running;
  final int total;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (progress * 100).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('识别进度', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      total == 0
                          ? '等待开始'
                          : isRunning
                          ? '正在逐页识别，请勿关闭窗口…'
                          : '已完成 $ok / $total 页',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '$ok',
                  label: '已识别',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: '$running',
                  label: '识别中',
                  icon: Icons.autorenew,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  value: '$failed',
                  label: '失败',
                  icon: Icons.error_outline,
                  color: failed > 0
                      ? AppColors.danger
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color, label) = switch (progress.status) {
      'ok' => (Icons.check_circle, AppColors.success, '识别成功'),
      'running' => (
        Icons.autorenew,
        scheme.primary,
        '识别中（第 ${progress.attempts} 次）',
      ),
      'failed' => (Icons.error_outline, scheme.error, '失败'),
      _ => (Icons.radio_button_unchecked, scheme.onSurfaceVariant, '待识别'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${progress.pageIndex} 页',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  progress.error ?? label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: progress.error != null
                        ? color
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (progress.status == 'failed' && enabled)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
