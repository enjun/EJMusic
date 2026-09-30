import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/components.dart';
import '../logic/dedupe_check.dart';
import '../logic/import_controller.dart';
import '../logic/import_scan.dart';

/// 导入向导：选目录 → 分组编辑 → 去重确认 → 入库。
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.hasSelection ? '已选 ${state.selected.length} 组' : '导入曲谱图片',
        ),
        actions: [
          if (state.hasSelection) ...[
            TextButton(
              onPressed: state.selected.length >= 2
                  ? controller.mergeSelected
                  : null,
              child: const Text('合并所选'),
            ),
            IconButton(
              tooltip: '取消选择',
              icon: const Icon(Icons.close),
              onPressed: controller.clearSelection,
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _DirectoryBar(state: state),
          if (state.phashTotal > 0 && state.phashDone < state.phashTotal)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: state.phashDone / state.phashTotal,
                  minHeight: 3,
                ),
              ),
            ),
          if (state.error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageMargin(context),
                AppSpacing.xs,
                AppSpacing.pageMargin(context),
                0,
              ),
              child: StatusBanner(
                message: state.error!,
                onDismiss: () =>
                    ref.read(importControllerProvider.notifier).clearError(),
              ),
            ),
          Expanded(
            child: state.groups.isEmpty
                ? const EmptyHint(
                    icon: Icons.collections_bookmark_outlined,
                    title: '选择包含曲谱扫描图的目录',
                    message:
                        '支持 jpg / png / webp，自动按文件名归组；'
                        '每首曲子的多页扫描图会被识别为一组。',
                  )
                : _GroupList(state: state),
          ),
        ],
      ),
      bottomNavigationBar: state.groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin(context),
                  AppSpacing.xs,
                  AppSpacing.pageMargin(context),
                  AppSpacing.md,
                ),
                child: FilledButton.icon(
                  onPressed: state.committing ? null : _onStartImport,
                  icon: state.committing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_add, size: 20),
                  label: Text(
                    state.committing
                        ? '导入中…'
                        : '开始导入（${state.groups.length} 首）',
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _onStartImport() async {
    final controller = ref.read(importControllerProvider.notifier);
    final matches = await controller.checkAllDuplication();
    if (!mounted) return;
    final skip = await _showDedupeDialog(matches);
    if (skip == null) return;
    final ids = await controller.commit(skip);
    if (!mounted) return;
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有新增曲子')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导入 ${ids.length} 首曲子')));
    }
    context.go('/');
  }

  /// 返回要跳过的分组下标集合；null 表示取消导入。
  Future<Set<int>?> _showDedupeDialog(List<List<DedupeMatch>> matches) async {
    final state = ref.read(importControllerProvider);
    final skip = <int>{};
    final hasAnyDup = matches.any((m) => m.any((x) => x.isDuplicate));
    if (!hasAnyDup) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('曲库查重'),
          content: Text('未发现重复曲谱，将导入 ${state.groups.length} 首。继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续导入'),
            ),
          ],
        ),
      );
      return goOn == true ? skip : null;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('发现疑似重复'),
          content: SizedBox(
            width: 460,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (ctx, gi) {
                final dups = matches[gi].where((m) => m.isDuplicate).toList();
                if (dups.isEmpty) return const SizedBox.shrink();
                final group = state.groups[gi];
                return CheckboxListTile(
                  value: skip.contains(gi),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      skip.add(gi);
                    } else {
                      skip.remove(gi);
                    }
                  }),
                  title: Text('「${group.label}」与曲库重复'),
                  subtitle: Text(
                    dups
                        .map(
                          (d) =>
                              '${d.existingSong.title}（相似度 ${(d.titleRatio * 100).toStringAsFixed(0)}%，'
                              '指纹匹配 ${d.matchedPages}/${d.totalPages} 页）',
                        )
                        .join('\n'),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认导入'),
            ),
          ],
        ),
      ),
    );
    return result == true ? skip : null;
  }
}

/// 目录信息条：当前目录 + 选择按钮。
class _DirectoryBar extends ConsumerWidget {
  const _DirectoryBar({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDir = state.dirPath != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageMargin(context),
        AppSpacing.xs,
        AppSpacing.pageMargin(context),
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              hasDir ? Icons.folder_open : Icons.folder_off_outlined,
              size: 22,
              color: hasDir ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDir ? '已选目录' : '尚未选择目录',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.dirPath ?? '选择包含曲谱扫描图的文件夹',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (state.scanning) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '正在扫描…',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton.tonalIcon(
              onPressed: state.scanning
                  ? null
                  : () => ref
                        .read(importControllerProvider.notifier)
                        .pickAndScan(),
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(hasDir ? '更换' : '选择目录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    final margin = AppSpacing.pageMargin(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        margin,
        AppSpacing.xs,
        margin,
        AppSpacing.md,
      ),
      itemCount: state.groups.length,
      itemBuilder: (context, i) {
        final group = state.groups[i];
        final isSelected = state.selected.contains(i);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _GroupCard(
            group: group,
            isSelected: isSelected,
            onTap: () {
              if (state.selected.isNotEmpty) {
                controller.toggleSelect(i);
              } else {
                _showGroupDetail(context, ref, i);
              }
            },
            onLongPress: () => controller.toggleSelect(i),
            onRename: (v) => controller.renameGroup(i, v),
          ),
        );
      },
    );
  }

  void _showGroupDetail(BuildContext context, WidgetRef ref, int groupIndex) {
    final controller = ref.read(importControllerProvider.notifier);
    final selectedPaths = <String>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (ctx, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageMargin(ctx),
                    AppSpacing.xs,
                    AppSpacing.pageMargin(ctx),
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '分组：'
                          '${ref.read(importControllerProvider).groups[groupIndex].label}',
                          style: Theme.of(ctx).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: selectedPaths.isEmpty
                            ? null
                            : () {
                                controller.splitNewGroup(
                                  groupIndex,
                                  selectedPaths.toList(),
                                );
                                Navigator.pop(ctx);
                              },
                        icon: const Icon(Icons.call_split, size: 18),
                        label: Text('移出为新组 (${selectedPaths.length})'),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Builder(
                    builder: (ctx) {
                      final group = ref
                          .watch(importControllerProvider)
                          .groups[groupIndex];
                      return GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 170,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                            ),
                        itemCount: group.files.length,
                        itemBuilder: (ctx, fi) {
                          final file = group.files[fi];
                          final checked = selectedPaths.contains(file.absPath);
                          return _ScannedImageTile(
                            path: file.absPath,
                            fileName: file.fileName,
                            checked: checked,
                            onTap: () => setSheetState(() {
                              if (checked) {
                                selectedPaths.remove(file.absPath);
                              } else {
                                selectedPaths.add(file.absPath);
                              }
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 分组卡片：缩略图叠层 + 可编辑曲名 + 文件摘要 + 选中态。
class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.group,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
  });

  final ImportDraftGroup group;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onRename;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = widget.group;
    final selected = widget.isSelected;

    final borderColor = selected
        ? scheme.primary
        : _hovered
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.outlineVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.07),
                  scheme.surfaceContainer,
                )
              : scheme.surfaceContainer,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          boxShadow: _hovered ? AppShadows.soft(theme.brightness) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: AppRadius.lgAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _ThumbStack(files: group.files),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EditableLabel(
                          initial: group.label,
                          onCommit: widget.onRename,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${group.files.length} 张图 · '
                          '${group.files.map((f) => f.fileName).take(2).join('、')}'
                          '${group.files.length > 2 ? ' 等' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (selected)
                    Icon(Icons.check_circle, color: scheme.primary, size: 22)
                  else
                    Icon(
                      Icons.drag_indicator,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 20,
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

/// 扫描图小卡：勾选态边框 + 文件名。
class _ScannedImageTile extends StatelessWidget {
  const _ScannedImageTile({
    required this.path,
    required this.fileName,
    required this.checked,
    required this.onTap,
  });

  final String path;
  final String fileName;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            width: checked ? 2 : 1,
            color: checked ? scheme.primary : scheme.outlineVariant,
          ),
          color: scheme.surfaceContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 340,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (checked)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.18),
                      ),
                    ),
                  if (checked)
                    Positioned(
                      right: AppSpacing.xxs,
                      top: AppSpacing.xxs,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.check,
                          size: 13,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 缩略图叠层：最多展示 3 页，暗示「这是一首多页曲谱」。
class _ThumbStack extends StatelessWidget {
  const _ThumbStack({required this.files});

  final List<FileMeta> files;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = files.length.clamp(1, 3);
    return SizedBox(
      width: 66,
      height: 68,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 11.0,
              top: 0,
              child: Transform.rotate(
                angle: 0,
                child: Container(
                  width: 44,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: scheme.outlineVariant),
                    color: scheme.surfaceContainerHigh,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: Image.file(
                      File(files[i].absPath),
                      fit: BoxFit.cover,
                      cacheWidth: 90,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (files.length > 3)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '+${files.length - 3}',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onPrimary,
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

class _EditableLabel extends StatefulWidget {
  const _EditableLabel({required this.initial, required this.onCommit});

  final String initial;
  final ValueChanged<String> onCommit;

  @override
  State<_EditableLabel> createState() => _EditableLabelState();
}

class _EditableLabelState extends State<_EditableLabel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: Theme.of(context).textTheme.titleMedium,
      decoration: const InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: '曲名',
      ),
      onSubmitted: (v) {
        final trimmed = v.trim();
        if (trimmed.isNotEmpty) widget.onCommit(trimmed);
      },
      onTapOutside: (_) {
        final trimmed = _controller.text.trim();
        if (trimmed.isNotEmpty && trimmed != widget.initial) {
          widget.onCommit(trimmed);
        }
        FocusScope.of(context).unfocus();
      },
    );
  }
}
