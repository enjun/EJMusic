import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/db/daos/import_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/util/fuzzy.dart';
import '../../../domain/group/grouping_engine.dart';
import 'dedupe_check.dart';
import 'import_scan.dart';

/// 导入向导中的一个分组草稿。
class ImportDraftGroup {
  ImportDraftGroup({required this.label, required this.files});

  String label;
  final List<FileMeta> files;

  ImportDraftGroup clone() => ImportDraftGroup(
        label: label,
        files: files.map((f) => FileMeta(
              fileName: f.fileName,
              absPath: f.absPath,
              bytes: f.bytes,
              mtimeMs: f.mtimeMs,
              phash: f.phash,
            )).toList(),
      );
}

/// 导入向导状态。
class ImportState {
  const ImportState({
    this.dirPath,
    this.groups = const [],
    this.scanning = false,
    this.phashDone = 0,
    this.phashTotal = 0,
    this.selected = const {},
    this.committing = false,
    this.error,
  });

  final String? dirPath;
  final List<ImportDraftGroup> groups;
  final bool scanning;
  final int phashDone;
  final int phashTotal;
  final Set<int> selected;
  final bool committing;
  final String? error;

  bool get hasSelection => selected.isNotEmpty;

  ImportState copyWith({
    String? dirPath,
    List<ImportDraftGroup>? groups,
    bool? scanning,
    int? phashDone,
    int? phashTotal,
    Set<int>? selected,
    bool? committing,
    String? error,
    bool clearError = false,
  }) {
    return ImportState(
      dirPath: dirPath ?? this.dirPath,
      groups: groups ?? this.groups,
      scanning: scanning ?? this.scanning,
      phashDone: phashDone ?? this.phashDone,
      phashTotal: phashTotal ?? this.phashTotal,
      selected: selected ?? this.selected,
      committing: committing ?? this.committing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);

class ImportController extends Notifier<ImportState> {
  int _scanGeneration = 0;

  @override
  ImportState build() => const ImportState();

  void clearError() => state = state.copyWith(clearError: true);

  /// 选择目录并扫描分组。
  Future<void> pickAndScan() async {
    final lastDir = await loadLastImportDir();
    final picked = await FilePicker.getDirectoryPath(
      initialDirectory: lastDir.isEmpty ? null : lastDir,
    );
    if (picked == null) return;
    await scanDirectory(picked);
    await saveLastImportDir(picked);
  }

  /// 对指定目录执行扫描与分组（也供重扫调用）。
  Future<void> scanDirectory(String dirPath) async {
    final gen = ++_scanGeneration;
    state = state.copyWith(scanning: true, clearError: true, selected: {});
    try {
      final metas = await scanImageDirectory(dirPath);
      final byName = {for (final m in metas) m.fileName: m};
      final drafts = groupByPrefix(metas.map((m) => m.fileName));
      final groups = [
        for (final d in drafts)
          ImportDraftGroup(label: d.label, files: [
            for (final name in d.files)
              if (byName[name] != null) byName[name]!,
          ]),
      ];
      if (gen != _scanGeneration) return;
      state = state.copyWith(
        dirPath: dirPath,
        groups: groups,
        scanning: false,
        phashDone: 0,
        phashTotal: metas.length,
      );
      unawaited(_computeHashes(gen));
    } catch (e) {
      state = state.copyWith(scanning: false, error: '扫描失败：$e');
    }
  }

  /// 后台逐图计算 pHash（带代际防串扰）。
  Future<void> _computeHashes(int gen) async {
    for (var gi = 0; gi < state.groups.length; gi++) {
      for (var fi = 0; fi < state.groups[gi].files.length; fi++) {
        if (gen != _scanGeneration) return;
        final file = state.groups[gi].files[fi];
        if (file.phash != null) {
          state = state.copyWith(phashDone: state.phashDone + 1);
          continue;
        }
        final hash = await computeImagePHash(file.absPath);
        if (gen != _scanGeneration) return;
        if (hash != null) file.phash = hash;
        state = state.copyWith(phashDone: state.phashDone + 1);
      }
    }
  }

  void renameGroup(int index, String label) {
    final groups = [...state.groups];
    groups[index] = groups[index]..label = label;
    state = state.copyWith(groups: groups);
  }

  void removeGroup(int index) {
    final groups = [...state.groups]..removeAt(index);
    state = state.copyWith(groups: groups, selected: {});
  }

  void toggleSelect(int index) {
    final selected = {...state.selected};
    if (!selected.add(index)) selected.remove(index);
    state = state.copyWith(selected: selected);
  }

  void clearSelection() => state = state.copyWith(selected: {});

  /// 合并所选分组为第一个分组。
  void mergeSelected() {
    final sel = state.selected.toList()..sort();
    if (sel.length < 2) return;
    final groups = [...state.groups];
    final target = groups[sel.first];
    for (var i = 1; i < sel.length; i++) {
      target.files.addAll(groups[sel[i]].files);
    }
    for (final idx in sel.reversed) {
      groups.removeAt(idx);
    }
    state = state.copyWith(groups: groups, selected: {});
  }

  /// 把 [absPaths] 从分组 [groupIndex] 移出为新组。
  void splitNewGroup(int groupIndex, List<String> absPaths) {
    final groups = [...state.groups];
    final source = groups[groupIndex];
    final moved = source.files.where((f) => absPaths.contains(f.absPath)).toList();
    if (moved.isEmpty) return;
    groups[groupIndex] = ImportDraftGroup(
      label: source.label,
      files: source.files.where((f) => !absPaths.contains(f.absPath)).toList(),
    );
    groups.insert(groupIndex + 1, ImportDraftGroup(label: source.label, files: moved));
    // 新组默认加"新"后缀避免同名
    groups[groupIndex + 1].label = '${source.label}(新)';
    state = state.copyWith(groups: groups);
  }

  /// 对所有分组执行去重检查，返回每组匹配结果（下标对齐 groups）。
  Future<List<List<DedupeMatch>>> checkAllDuplication() async {
    final db = ref.read(appDatabaseProvider);
    final results = <List<DedupeMatch>>[];
    for (final group in state.groups) {
      results.add(await checkGroupDuplication(db, group.label, group.files));
    }
    return results;
  }

  /// 提交导入：跳过 [skipIndices]，其余入库并创建曲目。
  Future<List<int>> commit(Set<int> skipIndices) async {
    final dirPath = state.dirPath;
    if (dirPath == null) return const [];
    state = state.copyWith(committing: true, clearError: true);
    try {
      final db = ref.read(appDatabaseProvider);
      final createdSongIds = <int>[];
      for (var gi = 0; gi < state.groups.length; gi++) {
        if (skipIndices.contains(gi)) continue;
        final group = state.groups[gi];
        if (group.files.isEmpty) continue;

        final groupId = await db.importDao.insertGroupWithImages(
          dirPath: dirPath,
          label: group.label,
          images: [
            for (final f in group.files)
              SourceImageSeed(
                absPath: f.absPath,
                fileName: f.fileName,
                bytes: f.bytes,
                mtimeMs: f.mtimeMs,
                phash: f.phash,
              ),
          ],
        );
        final images = await db.importDao.imagesOfGroup(groupId);
        final songId = await db.songsDao.insertSong(SongsCompanion.insert(
          title: group.label,
          titleNorm: normalizeTitle(group.label),
          sourceGroupId: Value(groupId),
        ));
        await db.importDao.createSongPages(
          songId: songId,
          sourceImageIds: [for (final img in images) img.id],
        );
        createdSongIds.add(songId);
      }
      state = ImportState(); // 重置向导
      return createdSongIds;
    } catch (e) {
      state = state.copyWith(committing: false, error: '入库失败：$e');
      return const [];
    }
  }
}
