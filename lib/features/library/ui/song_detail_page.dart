import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/ui/app_theme.dart';
import '../library_providers.dart';

/// 曲目详情：头图（元信息 + 状态）+ 功能入口网格 + 原始扫描图。
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
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: songAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (song) {
          if (song == null) return const Center(child: Text('曲目不存在'));
          final margin = AppSpacing.pageMargin(context);
          final pages = pagesAsync.value;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              margin,
              AppSpacing.xs,
              margin,
              AppSpacing.xxl,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroCard(song: song),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionTitle(
                          title: '制作与演奏',
                          subtitle: song.scorePath == null
                              ? '曲谱尚未制作，先执行「制作曲谱」'
                              : '已生成可交互曲谱',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ActionGrid(songId: songId, song: song),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionTitle(
                          title: '曲谱原图',
                          subtitle: pages == null
                              ? '加载中…'
                              : '共 ${pages.length} 页扫描图',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        pagesAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text('图片加载失败：$e'),
                          data: (images) => images.isEmpty
                              ? const _PlaceholderNote(text: '无源图片')
                              : _ImageGallery(
                                  count: images.length,
                                  pathAt: (i) => images[i].absPath,
                                ),
                        ),
                      ],
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除曲目'),
        content: const Text('将删除曲目记录与页信息（源图片文件不受影响）。确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appDatabaseProvider).songsDao.deleteSong(songId);
    if (context.mounted) Navigator.of(context).pop();
  }
}

// ------------------------------------------------------------------ 头图

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final status = songStatusFromName(song.status);
    final isGuitar = song.kind == 'guitar';
    final base = isGuitar ? scheme.tertiary : scheme.primary;

    final top = Color.alphaBlend(
      base.withValues(alpha: dark ? 0.28 : 0.16),
      scheme.surfaceContainer,
    );
    final bottom = Color.alphaBlend(
      base.withValues(alpha: 0.03),
      scheme.surfaceContainer,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        boxShadow: AppShadows.soft(theme.brightness),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -26,
            child: Icon(
              isGuitar ? Icons.music_note : Icons.piano,
              size: 148,
              color: base.withValues(alpha: dark ? 0.14 : 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer.withValues(alpha: 0.8),
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(
                        isGuitar ? Icons.music_note : Icons.piano,
                        color: base,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: theme.textTheme.headlineSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (song.composer?.isNotEmpty == true) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              song.composer!,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaChip(
                      icon: isGuitar
                          ? Icons.music_note_outlined
                          : Icons.piano_outlined,
                      label: isGuitar ? '吉他谱' : '钢琴谱',
                      emphasized: true,
                    ),
                    _MetaChip(
                      icon: Icons.description_outlined,
                      label: '${song.pageCount} 页',
                    ),
                    if (song.bpm != null)
                      _MetaChip(
                        icon: Icons.speed_outlined,
                        label: '${song.bpm} BPM',
                      ),
                    if (song.timeBeats != null && song.timeBeatType != null)
                      _MetaChip(
                        icon: Icons.timer_outlined,
                        label: '${song.timeBeats}/${song.timeBeatType} 拍',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

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
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: dark ? 0.34 : 0.16),
          theme.colorScheme.surfaceContainer,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: dark ? color : Color.alphaBlend(Colors.black38, color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = emphasized
        ? scheme.primaryContainer
        : scheme.surfaceContainer.withValues(alpha: 0.7);
    final fg = emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: emphasized ? Colors.transparent : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 功能入口

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.songId, required this.song});

  final int songId;
  final Song song;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // 固定高度：卡片宽窄变化时版式稳定，不会出现细高的竖条
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 118,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => _tiles(context)[i],
    );
  }

  List<Widget> _tiles(BuildContext context) {
    final status = songStatusFromName(song.status);
    final generating = status == SongStatus.generating;
    final hasScore = song.scorePath != null;
    return [
      _ActionTile(
        icon: generating
            ? Icons.hourglass_top
            : (status == SongStatus.ready || status == SongStatus.partial)
            ? Icons.refresh
            : Icons.auto_fix_high,
        title: switch (status) {
          SongStatus.generating => '制作中…',
          SongStatus.ready ||
          SongStatus.partial => song.scorePath == null ? '开始制作' : '重新制作',
          _ => '开始制作',
        },
        subtitle: 'AI 逐页识别扫描图',
        primary: true,
        enabled: !generating,
        onTap: () => context.push('/song/$songId/generate'),
      ),
      _ActionTile(
        icon: Icons.visibility_outlined,
        title: '查看曲谱',
        subtitle: song.musicxmlCachePath == null ? '需先制作曲谱' : '五线谱渲染与缩放',
        enabled: song.musicxmlCachePath != null,
        onTap: () => context.push('/song/$songId/view'),
      ),
      _ActionTile(
        icon: Icons.piano_outlined,
        title: '演奏模式',
        subtitle: hasScore ? '跟弹 / 聆听 + 虚拟键盘' : '需先制作曲谱',
        enabled: hasScore,
        onTap: () => context.push('/song/$songId/play'),
      ),
      _ActionTile(
        icon: Icons.edit_outlined,
        title: '编辑曲谱',
        subtitle: hasScore ? '点击谱面修改音符' : '需先制作曲谱',
        enabled: hasScore,
        onTap: () => context.push('/song/$songId/edit'),
      ),
      _ActionTile(
        icon: Icons.swap_horiz,
        title: '谱式转换',
        subtitle: hasScore
            ? (song.kind == 'piano' ? '转为吉他六线谱' : '转为钢琴大谱表')
            : '需先制作曲谱',
        enabled: hasScore,
        onTap: () => context.push('/song/$songId/convert'),
      ),
      _ActionTile(
        icon: Icons.auto_fix_high_outlined,
        title: 'AI 纠错',
        subtitle: hasScore ? '盲识别对照原图校对' : '需先制作曲谱',
        enabled: hasScore,
        onTap: () => context.push('/song/$songId/correct'),
      ),
    ];
  }
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool primary;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.enabled;
    final accent = widget.primary ? scheme.primary : scheme.onSurfaceVariant;

    final bg = widget.primary
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.10),
            scheme.surfaceContainer,
          )
        : scheme.surfaceContainer;

    final borderColor = !enabled
        ? scheme.outlineVariant
        : _hovered
        ? scheme.primary.withValues(alpha: 0.5)
        : widget.primary
        ? scheme.primary.withValues(alpha: 0.25)
        : scheme.outlineVariant;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: borderColor),
          boxShadow: _hovered && enabled
              ? AppShadows.soft(theme.brightness)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.onTap : null,
            borderRadius: AppRadius.lgAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    widget.icon,
                    size: 24,
                    color: enabled
                        ? accent
                        : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: enabled
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: enabled ? 1 : 0.5,
                          ),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 扫描图

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.count, required this.pathAt});

  final int count;
  final String Function(int index) pathAt;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.72,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: count,
      itemBuilder: (context, i) => _GalleryTile(path: pathAt(i), index: i + 1),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.path, required this.index});

  final String path;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHigh,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 480,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xs,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '第 $index 页',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 小组件

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
        ],
      ],
    );
  }
}

class _PlaceholderNote extends StatelessWidget {
  const _PlaceholderNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
