import 'dart:io';

import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/data/score/score_store.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:ejmusic/features/editor/logic/score_editor.dart';
import 'package:flutter_test/flutter_test.dart';

ScoreDocument _doc(List<ScoreEvent> rightHand) {
  return ScoreDocument(
    kind: 'piano',
    meta: ScoreMeta(title: '测试曲', bpm: 96),
    parts: [
      ScorePart(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: rightHand),
          ScoreVoice(staff: 2, events: [
            ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
          ]),
        ]),
      ]),
    ],
  );
}

void main() {
  group('标签格式化', () {
    test('音符标签含音名/升降/八度', () {
      final e = ScoreEvent(
        type: 'note',
        dur: const Rational(1, 1),
        pitches: [ScorePitch(step: 'F', alter: 1, octave: 3)],
      );
      expect(eventLabel(e), 'F#3 1/1');
      expect(pitchLabel(e.pitches.first), 'F#3');
    });

    test('和弦用 + 连接，延音线加 ~', () {
      final e = ScoreEvent(
        type: 'note',
        dur: const Rational(3, 2),
        tie: 'start',
        pitches: [
          ScorePitch(step: 'C', octave: 4),
          ScorePitch(step: 'E', octave: 4),
        ],
      );
      expect(eventLabel(e), 'C4+E4~ 3/2');
    });

    test('休止标签', () {
      final e = ScoreEvent(type: 'rest', dur: const Rational(1, 4));
      expect(eventLabel(e), '休止 1/4');
    });

    test('时值预设为约简分数', () {
      expect(kDurPresets['附点二分'], const Rational(3, 1));
      expect(kDurPresets['附点四分'], const Rational(3, 2));
      expect(kDurPresets['十六分音符'], const Rational(1, 4));
    });
  });

  group('saveEditedScore', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ejmusic_editor_test_');
    });
    tearDown(() async => tempDir.delete(recursive: true));

    test('保存后可原样读回，MusicXML 缓存同步生成', () async {
      final store = ScoreStore(tempDir.path);
      final doc = _doc([
        ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
          ScorePitch(step: 'C', octave: 4),
        ]),
        ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
          ScorePitch(step: 'E', octave: 4),
        ]),
      ]);
      final r = await saveEditedScore(store: store, songId: 7, doc: doc);
      expect(r.errors, isEmpty);
      expect(r.warnings, isEmpty);

      final reloaded = (await store.load(7))!;
      expect(reloaded.meta.title, '测试曲');
      expect(reloaded.parts.first.measures.first.voices.first.events.length, 2);
      expect(File(store.musicXmlPath(7)).existsSync(), isTrue);
    });

    test('改音符后保存生效', () async {
      final store = ScoreStore(tempDir.path);
      final doc = _doc([
        ScoreEvent(type: 'note', dur: const Rational(4, 1), pitches: [
          ScorePitch(step: 'C', octave: 4),
        ]),
      ]);
      await saveEditedScore(store: store, songId: 7, doc: doc);

      final loaded = (await store.load(7))!;
      final e = loaded.parts.first.measures.first.voices.first.events.first;
      e.pitches[0] = ScorePitch(step: 'D', alter: -1, octave: 5);
      e.dur = const Rational(1, 1);
      await saveEditedScore(store: store, songId: 7, doc: loaded);

      final reloaded = (await store.load(7))!;
      final e2 = reloaded.parts.first.measures.first.voices.first.events.first;
      expect(pitchLabel(e2.pitches.single), 'Db5');
      expect(e2.dur, const Rational(1, 1));
      // MusicXML 缓存也跟着更新了
      final xml = File(store.musicXmlPath(7)).readAsStringSync();
      expect(xml.contains('<step>D</step>'), isTrue);
      expect(xml.contains('<alter>-1</alter>'), isTrue);
    });

    test('欠拍小节自动补休止并以警告返回', () async {
      final store = ScoreStore(tempDir.path);
      final doc = _doc([
        ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
          ScorePitch(step: 'C', octave: 4),
        ]),
      ]);
      final r = await saveEditedScore(store: store, songId: 7, doc: doc);
      expect(r.warnings, isNotEmpty);
      expect(r.errors, isEmpty);

      final reloaded = (await store.load(7))!;
      final events = reloaded.parts.first.measures.first.voices.first.events;
      expect(events.length, 2);
      expect(events.last.isRest, isTrue);
    });
  });
}
