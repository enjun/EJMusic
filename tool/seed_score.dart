// 开发辅助：向真实 App 数据库种入一首成品「小星星」（跳过 LLM 制作）。
// flutter test tool/seed_score_test.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ejmusic/core/db/database.dart';
import 'package:ejmusic/core/db/tables.dart';
import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/data/score/score_store.dart';
import 'package:ejmusic/domain/score/score_document.dart';

const dbPath =
    r'C:\Users\hp\AppData\Roaming\com.ejmusic\ejmusic\ejmusic.sqlite';
const baseDir = r'C:\Users\hp\AppData\Roaming\com.ejmusic\ejmusic';

Future<String> seed() async {
  final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
  final store = ScoreStore(baseDir);

  // 幂等：同名曲已存在则跳过
  final existing = await db.select(db.songs).get();
  final hit = existing.where((s) => s.title == '小星星（种入）');
  if (hit.isNotEmpty) {
    await db.close();
    return '已存在 song ${hit.first.id}';
  }

  final doc = _littleStar();

  final songId = await db.into(db.songs).insert(SongsCompanion.insert(
        title: '小星星（种入）',
        titleNorm: '小星星（种入）',
        kind: const Value('piano'),
        status: const Value('ready'),
      ));
  final paths = await store.save(songId, doc);
  await db.songsDao.updateScoreResult(
    songId: songId,
    status: SongStatus.ready,
    composer: 'Trad.',
    keyFifths: 0,
    timeBeats: 4,
    timeBeatType: 4,
    bpm: 96,
    scorePath: paths.scorePath,
    musicxmlCachePath: paths.musicXmlPath,
  );
  await db.close();
  return '种入完成 songId=$songId';
}

ScoreDocument _littleStar() {
  ScoreEvent n(String step, int octave, Rational dur) => ScoreEvent(
        type: 'note',
        dur: dur,
        pitches: [ScorePitch(step: step, octave: octave)],
      );
  ScoreEvent lhChord(List<(String, int)> notes) => ScoreEvent(
        type: 'note',
        dur: const Rational(4, 1),
        pitches: [for (final (s, o) in notes) ScorePitch(step: s, octave: o)],
      );

  final q = Rational(1, 1);
  final h = Rational(2, 1);

  // (旋律事件列表, 左手和弦)
  final bars = <(List<ScoreEvent>, List<(String, int)>)>[
    (
      [n('C', 4, q), n('C', 4, q), n('G', 4, q), n('G', 4, q)],
      [('C', 3), ('G', 3)]
    ),
    (
      [n('A', 4, q), n('A', 4, q), n('G', 4, h)],
      [('F', 3), ('A', 3)]
    ),
    (
      [n('F', 4, q), n('F', 4, q), n('E', 4, q), n('E', 4, q)],
      [('F', 3), ('A', 3)]
    ),
    (
      [n('D', 4, q), n('D', 4, q), n('C', 4, h)],
      [('G', 3), ('B', 3)]
    ),
    (
      [n('G', 4, q), n('G', 4, q), n('F', 4, q), n('F', 4, q)],
      [('C', 3), ('E', 3)]
    ),
    (
      [n('E', 4, q), n('E', 4, q), n('D', 4, h)],
      [('C', 3), ('E', 3)]
    ),
    (
      [n('G', 4, q), n('G', 4, q), n('F', 4, q), n('F', 4, q)],
      [('C', 3), ('E', 3)]
    ),
    (
      [n('E', 4, q), n('E', 4, q), n('D', 4, h)],
      [('G', 3), ('B', 3)]
    ),
    (
      [n('C', 4, q), n('C', 4, q), n('G', 4, q), n('G', 4, q)],
      [('C', 3), ('G', 3)]
    ),
    (
      [n('A', 4, q), n('A', 4, q), n('G', 4, h)],
      [('F', 3), ('A', 3)]
    ),
    (
      [n('F', 4, q), n('F', 4, q), n('E', 4, q), n('E', 4, q)],
      [('F', 3), ('A', 3)]
    ),
    (
      [n('D', 4, q), n('D', 4, q), n('C', 4, h)],
      [('C', 3), ('E', 3), ('G', 3)]
    ),
  ];

  final measures = <ScoreMeasure>[];
  for (var i = 0; i < bars.length; i++) {
    final (melody, bass) = bars[i];
    final attrs = MeasureAttributes(
      repeatStart: i == 4,
      repeatEnd: i == 5,
      bpm: i == 0 ? 96 : null,
    );
    measures.add(ScoreMeasure(
      number: i + 1,
      attributes: attrs.isEmpty ? null : attrs,
      voices: [
        ScoreVoice(staff: 1, events: melody),
        ScoreVoice(staff: 2, events: [lhChord(bass)]),
      ],
    ));
  }

  return ScoreDocument(
    kind: 'piano',
    meta: ScoreMeta(
      title: '小星星',
      composer: 'Trad.',
      keyFifths: 0,
      timeBeats: 4,
      timeBeatType: 4,
      bpm: 96,
    ),
    parts: [
      ScorePart(instrument: 'piano', staffCount: 2, measures: measures),
    ],
  );
}
