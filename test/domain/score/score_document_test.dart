import 'dart:convert';

import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EJScore 模型序列化', () {
    test('完整文档 round-trip', () {
      final doc = ScoreDocument(
        kind: 'piano',
        meta: ScoreMeta(
          title: '童话',
          composer: '光良',
          keyFifths: 2,
          timeBeats: 4,
          timeBeatType: 4,
          bpm: 88,
        ),
        parts: [
          ScorePart(measures: [
            ScoreMeasure(
              number: 1,
              attributes: MeasureAttributes(repeatStart: true),
              voices: [
                ScoreVoice(staff: 1, events: [
                  ScoreEvent(
                    type: 'note',
                    dur: const Rational(3, 2),
                    dots: 1,
                    pitches: [
                      ScorePitch(step: 'G', octave: 4, finger: 3),
                    ],
                    tie: 'start',
                  ),
                  ScoreEvent(type: 'rest', dur: const Rational(1, 4)),
                ]),
                ScoreVoice(staff: 2, events: [
                  ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
                ]),
              ],
            ),
          ]),
        ],
      );
      final s = jsonEncode(doc.toJson());
      final back = ScoreDocument.fromJson(jsonDecode(s) as Map<String, dynamic>);
      expect(back.kind, 'piano');
      expect(back.meta.title, '童话');
      expect(back.meta.composer, '光良');
      expect(back.meta.keyFifths, 2);
      final m = back.parts.first.measures.first;
      expect(m.attributes!.repeatStart, isTrue);
      expect(m.voices.length, 2);
      final note = m.voices.first.events.first;
      expect(note.dur, const Rational(3, 2));
      expect(note.dots, 1);
      expect(note.pitches.first.step, 'G');
      expect(note.pitches.first.finger, 3);
      expect(note.tie, 'start');
    });

    test('宽容解析：十进制 dur / 缺字段 / 非法 type', () {
      final e = ScoreEvent.fromJson({
        'type': 'note',
        'dur': 0.5,
        'pitches': [
          {'step': 'f', 'octave': 4}
        ],
      });
      expect(e.dur, const Rational(1, 2));
      expect(e.pitches.first.step, 'F');
      expect(e.pitches.first.alter, 0);
      final rest = ScoreEvent.fromJson({'type': 'unknown'});
      expect(rest.isRest, isTrue);
      expect(rest.dur, const Rational(1, 1));
    });

    test('吉他谱 tab 字段 round-trip', () {
      final doc = ScoreDocument(
        kind: 'guitar',
        meta: ScoreMeta(title: 'Test'),
        parts: [
          ScorePart(
            instrument: 'guitar',
            staffCount: 1,
            measures: [
              ScoreMeasure(number: 1, voices: [
                ScoreVoice(staff: 1, events: [
                  ScoreEvent(
                    type: 'note',
                    dur: const Rational(1, 1),
                    pitches: [
                      ScorePitch(
                          step: 'G',
                          octave: 4,
                          tab: TabPosition(string: 1, fret: 3)),
                    ],
                  ),
                ]),
              ]),
            ],
          ),
        ],
      );
      final back = ScoreDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>);
      final p = back.parts.first.measures.first.voices.first.events.first.pitches.first;
      expect(p.tab!.string, 1);
      expect(p.tab!.fret, 3);
    });
  });

  group('noteTypeName', () {
    test('标准时值', () {
      expect(noteTypeName(const Rational(4, 1), 0), 'whole');
      expect(noteTypeName(const Rational(2, 1), 0), 'half');
      expect(noteTypeName(const Rational(1, 1), 0), 'quarter');
      expect(noteTypeName(const Rational(1, 2), 0), 'eighth');
      expect(noteTypeName(const Rational(1, 4), 0), '16th');
      expect(noteTypeName(const Rational(3, 1), 1), 'half'); // 附点二分
      expect(noteTypeName(const Rational(3, 2), 1), 'quarter'); // 附点四分
      expect(noteTypeName(const Rational(3, 4), 1), 'eighth'); // 附点八分
      expect(noteTypeName(const Rational(7, 4), 2), 'quarter'); // 双附点四分
      expect(noteTypeName(const Rational(7, 8), 2), 'eighth'); // 双附点八分
    });
    test('非标准时值返回 null', () {
      expect(noteTypeName(const Rational(1, 3), 0), isNull); // 三连音
      expect(noteTypeName(const Rational(5, 4), 0), isNull);
      expect(noteTypeName(const Rational(3, 2), 0), isNull); // 无附点标记的 3/2
    });
  });
}
