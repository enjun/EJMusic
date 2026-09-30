import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/components.dart';
import '../../library/library_providers.dart';
import '../logic/convert_controller.dart';

/// 谱式转换页：钢琴谱 ↔ 吉他谱。
class ConvertPage extends ConsumerWidget {
  const ConvertPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final songAsync = ref.watch(songProvider(songId));
    final state = ref.watch(convertControllerProvider(songId));
    final song = songAsync.value;
    final isPiano = song?.kind != 'guitar';

    return Scaffold(
      appBar: AppBar(title: Text('谱式转换 · ${song?.title ?? ''}')),
      body: CenteredBody(
        maxWidth: 680,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConversionCard(
              title: song?.title ?? '',
              isPiano: isPiano,
              bpm: song?.bpm,
              pageCount: song?.pageCount,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: state.running ? null : () => _convert(ref),
              icon: state.running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz, size: 20),
              label: Text(state.running ? '转换中…' : '开始转换'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              StatusBanner(message: '转换失败：${state.error}'),
            ],
            if (state.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: '转换提示（${state.warnings.length} 条）',
                icon: Icons.info_outline,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in state.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: scheme.onSurfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(w, style: theme.textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (state.resultSongId != null) ...[
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '转换完成，已生成新的曲目记录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          context.push('/song/${state.resultSongId}/view'),
                      icon: const Icon(Icons.music_note, size: 18),
                      label: const Text('查看结果'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _convert(WidgetRef ref) {
    ref.read(convertControllerProvider(songId).notifier).convert();
  }
}

/// 源 → 目标 的转换示意卡。
class _ConversionCard extends StatelessWidget {
  const _ConversionCard({
    required this.title,
    required this.isPiano,
    this.bpm,
    this.pageCount,
  });

  final String title;
  final bool isPiano;
  final int? bpm;
  final int? pageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              isPiano ? '钢琴谱（大谱表）' : '吉他谱（六线谱）',
              if (bpm != null) '$bpm BPM',
              if (pageCount != null) '$pageCount 页',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _KindBadge(
                  icon: isPiano ? Icons.piano : Icons.music_note,
                  label: isPiano ? '钢琴谱' : '吉他谱',
                  caption: '源曲谱',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  children: [
                    Icon(Icons.arrow_forward, color: scheme.primary, size: 22),
                    const SizedBox(height: 2),
                    Text('转换', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Expanded(
                child: _KindBadge(
                  icon: isPiano ? Icons.music_note : Icons.piano,
                  label: isPiano ? '吉他谱' : '钢琴谱',
                  caption: '目标曲谱',
                  emphasized: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  isPiano
                      ? '按和弦走向把大谱表改写为六线谱，尽量保留原有节奏与分段。'
                      : '把六线谱展开为大谱表，音高与节奏保持一一对应。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({
    required this.icon,
    required this.label,
    required this.caption,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String caption;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = emphasized ? scheme.primary : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: emphasized
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: accent),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: accent),
          ),
          Text(caption, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
