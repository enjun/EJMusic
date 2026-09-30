import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/components.dart';
import '../logic/correction_controller.dart';
import '../logic/correction_pipeline.dart' show CorrectionPageProgress;
import 'change_review_list.dart';

/// AI 纠错页：stage1 逐页对照原图校对（进度 + 单页重试），
/// stage2 修改清单确认后应用。
class CorrectionPage extends ConsumerStatefulWidget {
  const CorrectionPage({super.key, required this.songId});

  final int songId;

  @override
  ConsumerState<CorrectionPage> createState() => _CorrectionPageState();
}

class _CorrectionPageState extends ConsumerState<CorrectionPage> {
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(correctionControllerProvider(widget.songId).notifier)
          .start(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(correctionControllerProvider(widget.songId));
    final controller = ref.read(
      correctionControllerProvider(widget.songId).notifier,
    );

    // 应用完成后提示并返回
    final msg = state.resultMessage;
    if (msg != null && state.stage == CorrectionStage.idle && !_notified) {
      _notified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        Navigator.of(context).pop();
      });
    }

    return PopScope(
      canPop: state.stage != CorrectionStage.running,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI 纠错'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _StageBadge(stage: state.stage),
            ),
          ],
        ),
        body: _buildBody(context, state, controller),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CorrectionState state,
    CorrectionController controller,
  ) {
    if (state.stage == CorrectionStage.idle && state.error != null) {
      return EmptyHint(
        icon: Icons.error_outline,
        title: '纠错失败',
        message: state.error,
        action: FilledButton.icon(
          onPressed: controller.start,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('重试'),
        ),
      );
    }

    if (state.stage == CorrectionStage.review) {
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageMargin(context),
              AppSpacing.sm,
              AppSpacing.pageMargin(context),
              0,
            ),
            child: const SectionTitle(
              title: '修改清单',
              subtitle: '对照原图发现以下差异，请确认后应用',
            ),
          ),
          Expanded(
            child: ChangeReviewList(
              changes: state.changes,
              warnings: state.warnings,
              onToggle: controller.toggle,
              onSetAll: controller.setAll,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageMargin(context),
                AppSpacing.sm,
                AppSpacing.pageMargin(context),
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: state.applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    state.applying ? '应用中…' : '应用选中（${state.selectedCount} 处）',
                  ),
                  onPressed: state.applying || state.selectedCount == 0
                      ? null
                      : controller.applySelected,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // running（或初始）
    final pages = state.pages;
    final done = pages
        .where(
          (p) =>
              p.status == 'ok' ||
              p.status == 'unchanged' ||
              p.status == 'failed',
        )
        .length;
    final failed = pages.where((p) => p.status == 'failed').length;
    final changed = pages.where((p) => p.status == 'ok').length;

    return CenteredBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
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
                          Text(
                            '逐页校对进度',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '正在逐页盲识别原图并与当前曲谱比对…',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$done / ${pages.length}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: pages.isEmpty ? 0 : done / pages.length,
                    minHeight: 8,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHigh,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '$changed',
                        label: '有修改',
                        icon: Icons.edit_note,
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
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              itemCount: pages.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) =>
                  _pageTile(context, pages[i], controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageTile(
    BuildContext context,
    CorrectionPageProgress p,
    CorrectionController controller,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color, label) = switch (p.status) {
      'ok' => (
        Icons.check_circle,
        AppColors.success,
        '发现 ${p.changeCount} 处修改'
            '${p.largeDiff ? '（改动较多，请仔细核对）' : ''}'
            '（第${p.attempts}次尝试）',
      ),
      'unchanged' => (
        Icons.check_circle_outline,
        scheme.onSurfaceVariant,
        '无修改',
      ),
      'failed' => (Icons.error, scheme.error, p.error ?? '失败'),
      'running' => (Icons.sync, scheme.primary, '第${p.attempts}次盲识别中…'),
      _ => (Icons.schedule, scheme.onSurfaceVariant, '等待中'),
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
                Text('第 ${p.pageIndex} 页', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: p.status == 'failed'
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (p.status == 'failed' && p.pageIndex > 0)
            TextButton(
              onPressed: () => controller.retryPage(p.pageIndex),
              child: const Text('重试本页'),
            ),
        ],
      ),
    );
  }
}

/// AppBar 右侧的阶段标识。
class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final CorrectionStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (stage) {
      CorrectionStage.running => ('校对中', AppColors.info),
      CorrectionStage.review => ('待确认', AppColors.warning),
      CorrectionStage.idle => ('已完成', AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: Color.alphaBlend(Colors.black26, color),
        ),
      ),
    );
  }
}
