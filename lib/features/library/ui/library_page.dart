import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/ui/app_theme.dart';
import '../library_providers.dart';

SongStatus _parseStatus(String name) => songStatusFromName(name);

/// 曲库首页：页头 + 曲目卡片网格。
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
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/import'),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('导入曲谱'),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (songs) {
          if (songs.isEmpty) {
            return _EmptyState(onImport: () => context.push('/import'));
          }
          final margin = AppSpacing.pageMargin(context);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(margin, AppSpacing.xs, margin, 0),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: _LibraryHeader(count: songs.length),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  margin,
                  AppSpacing.lg,
                  margin,
                  // 给悬浮按钮留出空间，避免遮住最后一行卡片
                  AppSpacing.xxl + AppSpacing.xl,
                ),
                sliver: SliverGrid(
                  // 由卡片自身宽度决定列数：宽卡片自动切成横向版式，
                  // 因此任何窗口宽度下都不会出现「拉成横幅」的空洞感
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 236,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final song = songs[i];
                    return _SongCard(
                      song: song,
                      onTap: () => context.push('/song/${song.id}'),
                    );
                  }, childCount: songs.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ 页头

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('曲谱收藏', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '共 $count 首曲目 · 扫描图已归组，随时可制作与演奏',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 720)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: _CountBadge(count: count),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$count 首',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 曲目卡片

class _SongCard extends StatefulWidget {
  const _SongCard({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final song = widget.song;
    final status = _parseStatus(song.status);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽卡片切横向版式：左侧头图、右侧信息，避免大片空白
        final wide = constraints.maxWidth >= 460;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: _hovered
                    ? scheme.primary.withValues(alpha: 0.45)
                    : scheme.outlineVariant,
              ),
              boxShadow: _hovered
                  ? AppShadows.lifted(theme.brightness)
                  : AppShadows.soft(theme.brightness),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: AppRadius.lgAll,
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 148,
                            child: _CardArt(
                              kind: song.kind,
                              status: status,
                              compact: true,
                            ),
                          ),
                          Expanded(
                            child: _CardBody(
                              song: song,
                              status: status,
                              hovered: _hovered,
                              showStatus: false,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CardArt(kind: song.kind, status: status),
                          Expanded(
                            child: _CardBody(
                              song: song,
                              status: status,
                              hovered: _hovered,
                              showStatus: false,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 卡片文字区：状态 + 曲名 / 作曲 / 页数与速度 / 进入指示。
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.song,
    required this.status,
    required this.hovered,
    this.showStatus = true,
  });

  final Song song;
  final SongStatus status;
  final bool hovered;

  /// 竖向版式由头图承载状态徽标，文字区不再重复展示。
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (showStatus) ...[
                    _StatusBadge(status: status),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      [
                        if (song.composer?.isNotEmpty == true) song.composer!,
                        song.kind == 'guitar' ? '吉他谱' : '钢琴谱',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _MetaPill(
                icon: Icons.description_outlined,
                label: '${song.pageCount} 页',
              ),
              if (song.bpm != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _MetaPill(icon: Icons.speed_outlined, label: '${song.bpm} BPM'),
              ],
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: hovered
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 卡片头图：谱式主色微渐变底 + 谱式水印 + 状态徽标。
/// [compact] 为横向版式的窄侧栏：状态徽标改由文字区承担，这里只留图标。
class _CardArt extends StatelessWidget {
  const _CardArt({
    required this.kind,
    required this.status,
    this.compact = false,
  });

  final String kind;
  final SongStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final isGuitar = kind == 'guitar';

    final base = isGuitar ? scheme.tertiary : scheme.primary;
    final top = Color.alphaBlend(
      base.withValues(alpha: dark ? 0.30 : 0.16),
      scheme.surfaceContainer,
    );
    final bottom = Color.alphaBlend(
      base.withValues(alpha: dark ? 0.10 : 0.05),
      scheme.surfaceContainer,
    );

    final art = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
            border: compact
                ? Border(right: BorderSide(color: scheme.outlineVariant))
                : Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
        ),
        // 右上角大图标水印，给卡片一个视觉重心
        Positioned(
          right: -14,
          top: -18,
          child: Icon(
            isGuitar ? Icons.music_note : Icons.piano,
            size: 104,
            color: base.withValues(alpha: dark ? 0.16 : 0.11),
          ),
        ),
        if (compact)
          Positioned(
            left: 0,
            right: 0,
            top: AppSpacing.sm,
            child: Center(child: _StatusBadge(status: status)),
          )
        else
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _StatusBadge(status: status),
          ),
        Positioned(
          left: compact ? 0 : AppSpacing.md,
          right: compact ? 0 : null,
          bottom: AppSpacing.sm,
          child: Center(
            child: Icon(
              isGuitar ? Icons.music_note : Icons.piano,
              size: 26,
              color: base,
            ),
          ),
        ),
      ],
    );

    return compact ? art : SizedBox(height: 92, child: art);
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 状态徽标

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SongStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (label, icon, color) = switch (status) {
      SongStatus.grouped => ('待制作', Icons.schedule, AppColors.warning),
      SongStatus.generating => ('制作中', Icons.autorenew, AppColors.info),
      SongStatus.ready => ('已完成', Icons.check_circle, AppColors.success),
      SongStatus.partial => (
        '部分完成',
        Icons.incomplete_circle,
        AppColors.warning,
      ),
      SongStatus.failed => ('失败', Icons.error_outline, AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: dark ? 0.34 : 0.18),
          theme.colorScheme.surfaceContainer,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: dark ? color : Color.alphaBlend(Colors.black38, color),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 空 / 错误态

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

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
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.tertiary.withValues(alpha: 0.14),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.library_music_outlined,
                  size: 52,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '曲库还是空的',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '导入曲谱扫描图，AI 会按页识别并生成可交互的五线谱，'
                '之后即可查看、编辑、转换与跟弹演奏。',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text('从目录导入曲谱图片'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text('曲库加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
