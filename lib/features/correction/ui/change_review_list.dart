import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/components.dart';
import '../../../domain/score/correct/score_diff.dart';

/// 改动类型中文标签。
String changeKindLabel(ScoreChangeKind kind) => switch (kind) {
  ScoreChangeKind.modifyAttributes => '属性修改',
  ScoreChangeKind.modifyEvent => '修改',
  ScoreChangeKind.rewriteVoice => '声部重写',
  ScoreChangeKind.addVoice => '新增声部',
  ScoreChangeKind.removeVoice => '删除声部',
};

/// 改动确认清单：详情页纠错页与编辑器 bottom sheet 共用。
/// 按小节聚合展示（盲识别差异量大，事件级平铺无法人工把关）：
/// 每个小节一个可展开分组，组勾选框一键采纳/跳过整小节改动。
/// [onToggle] 为 null 时只读展示。
class ChangeReviewList extends StatelessWidget {
  const ChangeReviewList({
    super.key,
    required this.changes,
    this.warnings = const [],
    this.onToggle,
    this.onSetAll,
  });

  final List<ScoreChange> changes;
  final List<String> warnings;
  final ValueChanged<int>? onToggle;
  final ValueChanged<bool>? onSetAll;

  @override
  Widget build(BuildContext context) {
    final selectedCount = changes.where((c) => c.selected).length;
    final margin = AppSpacing.pageMargin(context);

    // 按小节聚合（保持出现顺序）
    final groups = <int, List<int>>{};
    for (var i = 0; i < changes.length; i++) {
      groups.putIfAbsent(changes[i].measureIndex, () => []).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (warnings.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              margin,
              AppSpacing.sm,
              margin,
              AppSpacing.xs,
            ),
            child: StatusBanner(
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              message: '${warnings.length} 条告警：${warnings.join('；')}',
            ),
          ),
        if (onSetAll != null && changes.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              margin,
              AppSpacing.xs,
              margin,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => onSetAll!(true),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('全选'),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => onSetAll!(false),
                  icon: const Icon(Icons.remove_done, size: 16),
                  label: const Text('全不选'),
                ),
                const Spacer(),
                _SelectionPill(selected: selectedCount, total: changes.length),
              ],
            ),
          ),
        Expanded(
          child: changes.isEmpty
              ? const EmptyHint(
                  icon: Icons.check_circle_outline,
                  title: '没有发现需要修改的地方',
                  message: 'AI 校对结果与当前曲谱一致。',
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    margin,
                    AppSpacing.xs,
                    margin,
                    AppSpacing.lg,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, gi) {
                    final measureIndex = groups.keys.elementAt(gi);
                    final indices = groups[measureIndex]!;
                    final first = changes[indices.first];
                    final allSelected = indices.every(
                      (i) => changes[i].selected,
                    );
                    final summary = indices
                        .map((i) => changes[i])
                        .map(
                          (c) =>
                              '${c.before.isEmpty ? '' : '${c.before} → '}'
                              '${c.after.isEmpty ? c.before : c.after}',
                        )
                        .join('；');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _MeasureGroup(
                        title: '第 ${first.measureNumber} 小节',
                        count: indices.length,
                        summary: summary,
                        initiallyExpanded: indices.length <= 3,
                        allSelected: allSelected,
                        onToggleAll: onToggle == null
                            ? null
                            : () {
                                // 全选中 → 整组取消；否则整组勾选
                                for (final i in indices) {
                                  if (changes[i].selected == allSelected) {
                                    onToggle!(i);
                                  }
                                }
                              },
                        children: [
                          for (final i in indices)
                            _ChangeRow(
                              label: changeKindLabel(changes[i].kind),
                              before: changes[i].before,
                              after: changes[i].after,
                              selected: changes[i].selected,
                              onToggle: onToggle == null
                                  ? null
                                  : () => onToggle!(i),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill({required this.selected, required this.total});

  final int selected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = selected == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: all ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '已选 $selected / $total 处',
        style: theme.textTheme.labelMedium?.copyWith(
          color: all ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 一个小节的改动分组：头部可勾选整组，展开后逐条勾选。
class _MeasureGroup extends StatelessWidget {
  const _MeasureGroup({
    required this.title,
    required this.count,
    required this.summary,
    required this.allSelected,
    required this.children,
    this.onToggleAll,
    this.initiallyExpanded = false,
  });

  final String title;
  final int count;
  final String summary;
  final bool allSelected;
  final List<Widget> children;
  final VoidCallback? onToggleAll;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: allSelected
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.only(
            left: AppSpacing.xs,
            right: AppSpacing.md,
          ),
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
          leading: onToggleAll == null
              ? null
              : Checkbox(value: allSelected, onChanged: (_) => onToggleAll!()),
          title: Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count 处',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// 单条改动：勾选框 + 类型 + before → after 对照。
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.label,
    required this.before,
    required this.after,
    required this.selected,
    this.onToggle,
  });

  final String label;
  final String before;
  final String after;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.xxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onToggle != null)
              Checkbox(value: selected, onChanged: (_) => onToggle!()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _DiffLine(before: before, after: after),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine({required this.before, required this.after});

  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: 2,
      children: [
        if (before.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              before,
              style: mono?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (before.isNotEmpty)
          Icon(Icons.arrow_forward, size: 13, color: scheme.onSurfaceVariant),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: AppRadius.smAll,
          ),
          child: Text(
            after.isEmpty ? '（删除）' : after,
            style: mono?.copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}
