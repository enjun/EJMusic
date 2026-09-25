import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'import_dao.g.dart';

@DriftAccessor(tables: [ImageGroups, SourceImages, Songs, SongPages])
class ImportDao extends DatabaseAccessor<AppDatabase> with _$ImportDaoMixin {
  // ignore: unused_element_parameter
  ImportDao(super.db);

  /// 插入一个分组及其图片（同目录事务），返回 groupId。
  Future<int> insertGroupWithImages({
    required String dirPath,
    required String label,
    required List<SourceImageSeed> images,
  }) {
    return transaction(() async {
      final groupId = await into(imageGroups).insert(
        ImageGroupsCompanion.insert(
          dirPath: dirPath,
          label: label,
          imageCount: images.length,
        ),
      );
      for (var i = 0; i < images.length; i++) {
        final img = images[i];
        await into(sourceImages).insertOnConflictUpdate(
          SourceImagesCompanion.insert(
            absPath: img.absPath,
            fileName: img.fileName,
            bytes: img.bytes,
            mtimeMs: img.mtimeMs,
            groupId: groupId,
            pageIndexInGroup: i,
            phash: Value(img.phash),
          ),
        );
      }
      return groupId;
    });
  }

  /// 为曲目创建页记录并回填曲子的页数（页指纹继承自源图片）。
  Future<void> createSongPages({
    required int songId,
    required List<int> sourceImageIds,
  }) {
    return transaction(() async {
      for (var i = 0; i < sourceImageIds.length; i++) {
        final img = await (select(sourceImages)
              ..where((s) => s.id.equals(sourceImageIds[i])))
            .getSingle();
        await into(songPages).insert(
          SongPagesCompanion.insert(
            songId: songId,
            pageIndex: i,
            sourceImageId: sourceImageIds[i],
            phash: Value(img.phash),
          ),
        );
      }
      await (update(songs)..where((s) => s.id.equals(songId))).write(
        SongsCompanion(pageCount: Value(sourceImageIds.length)),
      );
    });
  }

  /// 按 groupId 取图片，按页序返回。
  Future<List<SourceImage>> imagesOfGroup(int groupId) {
    return (select(sourceImages)
          ..where((i) => i.groupId.equals(groupId))
          ..orderBy([(i) => OrderingTerm.asc(i.pageIndexInGroup)]))
        .get();
  }

  /// 目录下已导入过的图片绝对路径（用于跳过重复文件）。
  Future<Set<String>> importedPathsInDir(String dirPath) async {
    final rows = await (select(sourceImages).join([
      innerJoin(imageGroups, imageGroups.id.equalsExp(sourceImages.groupId)),
    ])
          ..where(imageGroups.dirPath.equals(dirPath)))
        .get();
    return rows.map((r) => r.readTable(sourceImages).absPath).toSet();
  }
}

/// 插入图片所需的最小数据。
class SourceImageSeed {
  SourceImageSeed({
    required this.absPath,
    required this.fileName,
    required this.bytes,
    required this.mtimeMs,
    this.phash,
  });

  final String absPath;
  final String fileName;
  final int bytes;
  final int mtimeMs;
  final String? phash;
}
