import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/util/fuzzy.dart';
import '../../../domain/score/convert/convert_result.dart';
import '../../../domain/score/convert/guitar_to_piano.dart';
import '../../../domain/score/convert/piano_to_guitar.dart';
import '../../../domain/score/score_validator.dart';
import '../../generation/logic/generation_controller.dart';
import '../../library/library_providers.dart';

class ConvertState {
  const ConvertState({
    this.running = false,
    this.error,
    this.resultSongId,
    this.warnings = const [],
  });

  final bool running;
  final String? error;
  final int? resultSongId;
  final List<String> warnings;

  ConvertState copyWith({
    bool? running,
    String? error,
    int? resultSongId,
    List<String>? warnings,
  }) =>
      ConvertState(
        running: running ?? this.running,
        error: error,
        resultSongId: resultSongId ?? this.resultSongId,
        warnings: warnings ?? this.warnings,
      );
}

/// 谱式转换：钢琴 ↔ 吉他互转，产物存为新曲目（derived=1）。
class ConvertController extends Notifier<ConvertState> {
  ConvertController(this.songId);

  final int songId;

  @override
  ConvertState build() => ConvertState();

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> convert() async {
    if (state.running) return;
    state = ConvertState(running: true);
    try {
      final song = await _db.songsDao.songById(songId);
      final store = await ref.read(scoreStoreProvider.future);
      final doc = await store.load(songId);
      if (doc == null) {
        state = ConvertState(error: '源曲谱数据缺失，无法转换');
        return;
      }

      final ConvertResult result;
      final String suffix;
      if (doc.kind == 'piano') {
        result = pianoToGuitar(doc);
        suffix = '吉他版';
      } else {
        result = guitarToPiano(doc);
        suffix = '钢琴版';
      }
      final out = result.document;
      final validation = ScoreValidator.validateAndRepair(out);

      final baseTitle = _stripSuffix(song.title);
      final newTitle = '$baseTitle（$suffix）';
      final newSongId = await _db.into(_db.songs).insert(SongsCompanion.insert(
            title: newTitle,
            titleNorm: normalizeTitle(newTitle),
            composer: Value(song.composer),
            kind: Value(out.kind),
            bpm: Value(out.meta.bpm),
            status: const Value('ready'),
            sourceSongId: Value(songId),
            derived: const Value(true),
          ));

      final paths = await store.save(newSongId, out);
      await _db.songsDao.updateScoreResult(
        songId: newSongId,
        status: SongStatus.ready,
        composer: out.meta.composer,
        keyFifths: out.meta.keyFifths,
        timeBeats: out.meta.timeBeats,
        timeBeatType: out.meta.timeBeatType,
        bpm: out.meta.bpm,
        scorePath: paths.scorePath,
        musicxmlCachePath: paths.musicXmlPath,
        errorMsg: validation.errors.isEmpty
            ? null
            : '校验提示：${validation.errors.first.message}',
      );

      ref.invalidate(songsStreamProvider);
      ref.invalidate(songProvider(newSongId));
      state = ConvertState(
        resultSongId: newSongId,
        warnings: [
          ...result.warnings,
          for (final e in validation.errors) '校验：${e.message}',
        ],
      );
    } catch (e) {
      state = ConvertState(error: e.toString());
    }
  }

  /// 去掉既有「（xx版）」后缀，避免反复转换时后缀叠加。
  String _stripSuffix(String title) =>
      title.replaceFirst(RegExp(r'（(吉他|钢琴)版）$'), '');
}

final convertControllerProvider =
    NotifierProvider.family<ConvertController, ConvertState, int>(
  ConvertController.new,
);
