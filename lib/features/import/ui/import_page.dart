import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        title: Text(state.hasSelection
            ? '已选 ${state.selected.length} 组'
            : '导入曲谱图片'),
        actions: [
          if (state.hasSelection) ...[
            TextButton(
              onPressed: state.selected.length >= 2 ? controller.mergeSelected : null,
              child: const Text('合并所选'),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: controller.clearSelection,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _DirectoryBar(state: state),
          if (state.phashTotal > 0 && state.phashDone < state.phashTotal)
            LinearProgressIndicator(
              value: state.phashDone / state.phashTotal,
              minHeight: 2,
            ),
          if (state.error != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline),
                title: Text(state.error!),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      ref.read(importControllerProvider.notifier).clearError(),
                ),
              ),
            ),
          Expanded(
            child: state.groups.isEmpty
                ? _EmptyHint(state: state)
                : _GroupList(state: state),
          ),
        ],
      ),
      bottomNavigationBar: state.groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: state.committing ? null : _onStartImport,
                  icon: state.committing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_add),
                  label: Text(state.committing ? '导入中…' : '开始导入（${state.groups.length} 首）'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有新增曲子')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${ids.length} 首曲子')),
      );
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续导入')),
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
            width: 420,
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
                    dups.map((d) =>
                        '${d.existingSong.title}（相似度 ${(d.titleRatio * 100).toStringAsFixed(0)}%，'
                        '指纹匹配 ${d.matchedPages}/${d.totalPages} 页）').join('\n'),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认导入')),
          ],
        ),
      ),
    );
    return result == true ? skip : null;
  }
}

class _DirectoryBar extends ConsumerWidget {
  const _DirectoryBar({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.dirPath ?? '尚未选择目录',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
                if (state.scanning)
                  const Text('扫描中…', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: state.scanning
                ? null
                : () => ref.read(importControllerProvider.notifier).pickAndScan(),
            icon: const Icon(Icons.folder_open),
            label: const Text('选择目录'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends ConsumerWidget {
  const _EmptyHint({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.collections_bookmark, size: 72,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('选择包含曲谱扫描图的目录'),
          const SizedBox(height: 4),
          Text('支持 jpg / png / webp，自动按文件名归组',
              style: Theme.of(context).textTheme.bodySmall),
        ],
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
    return ListView.builder(
      itemCount: state.groups.length,
      itemBuilder: (context, i) {
        final group = state.groups[i];
        final isSelected = state.selected.contains(i);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: isSelected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                )
              : null,
          child: ListTile(
            onLongPress: () => controller.toggleSelect(i),
            onTap: () {
              if (state.selected.isNotEmpty) {
                controller.toggleSelect(i);
              } else {
                _showGroupDetail(context, ref, i);
              }
            },
            leading: _ThumbStack(files: group.files),
            title: _EditableLabel(
              initial: group.label,
              onCommit: (v) => controller.renameGroup(i, v),
            ),
            subtitle: Text('${group.files.length} 张图 · ${group.files.map((f) => f.fileName).take(3).join(', ')}'
                '${group.files.length > 3 ? " …" : ""}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: isSelected
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.drag_handle),
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
          builder: (ctx, scrollController) => Scaffold(
            appBar: AppBar(
              title: Text('分组：${ref.read(importControllerProvider).groups[groupIndex].label}'),
              actions: [
                TextButton(
                  onPressed: selectedPaths.isEmpty
                      ? null
                      : () {
                          controller.splitNewGroup(groupIndex, selectedPaths.toList());
                          Navigator.pop(ctx);
                        },
                  child: Text('移出所选为新组 (${selectedPaths.length})'),
                ),
              ],
            ),
            body: Builder(builder: (ctx) {
              final group = ref.watch(importControllerProvider).groups[groupIndex];
              return GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: group.files.length,
                itemBuilder: (ctx, fi) {
                  final file = group.files[fi];
                  final checked = selectedPaths.contains(file.absPath);
                  return InkWell(
                    onTap: () => setSheetState(() {
                      if (checked) {
                        selectedPaths.remove(file.absPath);
                      } else {
                        selectedPaths.add(file.absPath);
                      }
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          width: checked ? 2 : 1,
                          color: checked
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).dividerColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: Image.file(
                                File(file.absPath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                cacheWidth: 300,
                                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(file.fileName,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx).textTheme.labelSmall),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ThumbStack extends StatelessWidget {
  const _ThumbStack({required this.files});

  final List<FileMeta> files;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          for (var i = 0; i < files.length && i < 3; i++)
            Positioned(
              left: i * 12.0,
              child: Container(
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(files[i].absPath),
                    fit: BoxFit.cover,
                    cacheWidth: 80,
                    errorBuilder: (_, _, _) => const Icon(Icons.image, size: 20),
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
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

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
        border: InputBorder.none,
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
