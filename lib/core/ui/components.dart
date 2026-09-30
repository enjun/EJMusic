import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 单列内容页的统一容器：限制最大宽度并居中，宽窗口下不会拉成难读的长行。
class CenteredBody extends StatelessWidget {
  const CenteredBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final margin = AppSpacing.pageMargin(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // Align 会给 child 松约束，ConstrainedBox 会缩到最小宽度；
        // SizedBox.expand 先把宽度撑满，再由 maxWidth 收窄并居中
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding:
                padding ??
                EdgeInsets.fromLTRB(
                  margin,
                  AppSpacing.xs,
                  margin,
                  AppSpacing.xl,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 区块标题：主色竖条 + 标题 + 可选说明/尾部控件。
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 分区卡片：可选标题行 + 内容，统一圆角、描边与轻阴影。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.trailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasHeader = title != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: theme.textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(subtitle!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          if (hasHeader) Divider(height: 1, color: scheme.outlineVariant),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// 统计数字卡片：大号数值 + 说明文字。
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;
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
              color: accent.withValues(alpha: 0.14),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(color: accent),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态提示：图标 + 主文案 + 说明。
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 44, color: scheme.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 悬浮在谱面之上的提示胶囊（深色半透明，任何背景下都可读）。
class OverlayPill extends StatelessWidget {
  const OverlayPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent.withValues(alpha: 0.85)),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 带状态色的信息条：用于错误 / 警告 / 成功提示，替代整块 Material 色块。
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.color,
    this.onDismiss,
  });

  final String message;
  final IconData icon;
  final Color? color;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: '关闭',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
