import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'songs_dao.g.dart';

@DriftAccessor(tables: [Songs, SongPages])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  // ignore: unused_element_parameter
  SongsDao(super.db);

  /// 曲库列表（不含转换产物，按创建时间倒序）。
  Future<List<Song>> listSongs({bool includeDerived = false}) {
    final query = select(songs);
    if (!includeDerived) query.where((s) => s.derived.equals(false));
    query.orderBy([(s) => OrderingTerm.desc(s.createdAt)]);
    return query.get();
  }

  Future<Song> songById(int id) =>
      (select(songs)..where((s) => s.id.equals(id))).getSingle();

  Future<List<SongPage>> pagesOfSong(int songId) {
    return (select(songPages)
          ..where((pg) => pg.songId.equals(songId))
          ..orderBy([(pg) => OrderingTerm.asc(pg.pageIndex)]))
        .get();
  }

  /// 页与源图片联查（制作管线输入），按页序返回。
  Future<List<({SongPage page, SourceImage image})>> pagesWithImages(
      int songId) {
    return (select(songPages).join([
      innerJoin(sourceImages, sourceImages.id.equalsExp(songPages.sourceImageId)),
    ])
          ..where(songPages.songId.equals(songId))
          ..orderBy([OrderingTerm.asc(songPages.pageIndex)]))
        .get()
        .then((rows) => [
              for (final r in rows)
                (
                  page: r.readTable(songPages),
                  image: r.readTable(sourceImages),
                )
            ]);
  }

  /// 更新一页的识别结果。
  Future<void> updatePageLlmResult({
    required int pageId,
    required PageLlmStatus status,
    required int attempts,
    String? error,
  }) {
    return (update(songPages)..where((pg) => pg.id.equals(pageId))).write(
      SongPagesCompanion(
        llmStatus: Value(status.name),
        attempts: Value(attempts),
        llmError: Value(error),
      ),
    );
  }

  /// 写入制作完成后的曲谱信息。
  Future<void> updateScoreResult({
    required int songId,
    required SongStatus status,
    String? composer,
    int? keyFifths,
    int? timeBeats,
    int? timeBeatType,
    int? bpm,
    required String? scorePath,
    required String? musicxmlCachePath,
    String? errorMsg,
  }) {
    return (update(songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(
        status: Value(status.name),
        composer: composer == null ? const Value.absent() : Value(composer),
        keyFifths: keyFifths == null ? const Value.absent() : Value(keyFifths),
        timeBeats: timeBeats == null ? const Value.absent() : Value(timeBeats),
        timeBeatType:
            timeBeatType == null ? const Value.absent() : Value(timeBeatType),
        bpm: bpm == null ? const Value.absent() : Value(bpm),
        scorePath: Value(scorePath),
        musicxmlCachePath: Value(musicxmlCachePath),
        errorMsg: Value(errorMsg),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 去重候选：归一化曲名近似的所有曲目（含指纹汇总由调用方查页表）。
  Future<List<Song>> allSongsForDedupe() {
    return select(songs).get();
  }

  Future<int> insertSong(SongsCompanion entry) => into(songs).insert(entry);

  Future<void> updateStatus(int songId, SongStatus status, {String? errorMsg}) {
    return (update(songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(
        status: Value(status.name),
        errorMsg: Value(errorMsg),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSong(int songId) {
    return transaction(() async {
      await (delete(songPages)..where((pg) => pg.songId.equals(songId))).go();
      await (delete(songs)..where((s) => s.id.equals(songId))).go();
    });
  }
}
