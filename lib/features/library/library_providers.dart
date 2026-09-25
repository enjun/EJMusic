import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/db/database.dart';

/// 曲库流（不含转换产物，按创建时间倒序）。
final songsStreamProvider = StreamProvider<List<Song>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.songs)
    ..where((s) => s.derived.equals(false))
    ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
  return query.watch();
});

final songProvider = StreamProvider.family<Song?, int>((ref, id) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.songs)..where((s) => s.id.equals(id)))
      .watchSingleOrNull();
});

final songPagesProvider = StreamProvider.family<List<SongPage>, int>((ref, id) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.songPages)
        ..where((pg) => pg.songId.equals(id))
        ..orderBy([(pg) => OrderingTerm.asc(pg.pageIndex)]))
      .watch();
});

/// 分组源图片（详情页展示原图用）。
final songSourceImagesProvider =
    FutureProvider.family<List<SourceImage>, int>((ref, songId) async {
  final db = ref.watch(appDatabaseProvider);
  final song = await db.songsDao.songById(songId);
  final groupId = song.sourceGroupId;
  if (groupId == null) return const [];
  return db.importDao.imagesOfGroup(groupId);
});
