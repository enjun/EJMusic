import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:ejmusic/domain/score/score_validator.dart';
import 'package:flutter_test/flutter_test.dart';

ScoreDocument _pianoDoc({
  bool pickup = false,
  required List<ScoreMeasure> measures,
}) {
  return ScoreDocument(
    kind: 'piano',
    meta: ScoreMeta(title: 'T', timeBeats: 4, timeBeatType: 4, pickup: pickup),
    parts: [ScorePart(measures: measures)],
  );
}

void main() {
  group('拍数检查', () {
    test('足拍小节无错误', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
              ScorePitch(step: 'C', octave: 4),
            ]),
            ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
              ScorePitch(step: 'E', octave: 4),
            ]),
          ]),
          ScoreVoice(staff: 2, events: [
            ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      expect(r.repairs, isEmpty);
    });

    test('欠拍自动补休止', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
              ScorePitch(step: 'C', octave: 4),
            ]),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      expect(r.repairs.join(), contains('补休止'));
      final v = doc.parts.first.measures.first.voices.first;
      expect(v.events.last.isRest, isTrue);
      expect(v.events.last.dur, const Rational(2, 1));
    });

    test('超拍报 error 不修复', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'note', dur: const Rational(4, 1), pitches: [
              ScorePitch(step: 'C', octave: 4),
            ]),
            ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
              ScorePitch(step: 'D', octave: 4),
            ]),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isFalse);
      expect(r.errors.first.code, 'measure_overfull');
      expect(r.errors.first.measureNumber, 1);
    });

    test('弱起小节豁免（首个小节欠拍不补）', () {
      final doc = _pianoDoc(pickup: true, measures: [
        ScoreMeasure(number: 0, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'note', dur: const Rational(1, 1), pitches: [
              ScorePitch(step: 'G', octave: 4),
            ]),
          ]),
        ]),
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      // 弱起小节保持原样
      expect(doc.parts.first.measures.first.voices.first.events.length, 1);
    });

    test('片段校验：末小节跨页延续欠拍不补（lastContinues）', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'rest', dur: const Rational(4, 1)),
          ]),
        ]),
        ScoreMeasure(number: 2, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'note', dur: const Rational(1, 1), pitches: [
              ScorePitch(step: 'C', octave: 4),
            ]),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(
        doc,
        const ValidateOptions(lastContinues: true),
      );
      expect(r.ok, isTrue);
      expect(doc.parts.first.measures.last.voices.first.events.length, 1);
      // 完整校验时才补
      final r2 = ScoreValidator.validateAndRepair(doc);
      expect(r2.repairs.join(), contains('补休止'));
    });

    test('空小节补全小节休止（钢琴双手）', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: []),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      final m = doc.parts.first.measures.first;
      expect(m.voices.length, 2);
      expect(m.voices[0].staff, 1);
      expect(m.voices[1].staff, 2);
    });
  });

  group('时值吸附与附点', () {
    test('非法分数吸附到 1/48 网格', () {
      expect(ScoreValidator.snapRational(const Rational(1, 7)),
          const Rational(7, 48));
      expect(ScoreValidator.snapRational(const Rational(1, 5)),
          const Rational(5, 24)); // 1/5*48=9.6→10 → 10/48=5/24
    });

    test('附点与 dur 不匹配时修正附点数', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(
                type: 'note',
                dur: const Rational(3, 1), // 附点二分
                dots: 0,
                pitches: [ScorePitch(step: 'C', octave: 4)]),
            ScoreEvent(
                type: 'note',
                dur: const Rational(1, 1),
                dots: 2, // 错：quarter 不能带 2 个附点
                pitches: [ScorePitch(step: 'D', octave: 4)]),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      final events = doc.parts.first.measures.first.voices.first.events;
      expect(events[0].dots, 1); // 3 quarters = 附点二分
      expect(events[1].dots, 0);
    });
  });

  group('tie 配对', () {
    test('跨小节配对成功不移除', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(
                type: 'note',
                dur: const Rational(4, 1),
                tie: 'start',
                pitches: [ScorePitch(step: 'C', octave: 4)]),
          ]),
        ]),
        ScoreMeasure(number: 2, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(
                type: 'note',
                dur: const Rational(4, 1),
                tie: 'stop',
                pitches: [ScorePitch(step: 'C', octave: 4)]),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue, reason: r.errors.map((e) => e.message).join('; '));
      expect(doc.parts.first.measures[0].voices.first.events.first.tie, 'start');
      expect(doc.parts.first.measures[1].voices.first.events.first.tie, 'stop');
    });

    test('孤立 start / stop 移除', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(
                type: 'note',
                dur: const Rational(2, 1),
                tie: 'start',
                pitches: [ScorePitch(step: 'C', octave: 4)]),
            ScoreEvent(
                type: 'note',
                dur: const Rational(2, 1),
                tie: 'stop',
                pitches: [ScorePitch(step: 'E', octave: 4)]), // 音高不同
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      final events = doc.parts.first.measures.first.voices.first.events;
      expect(events[0].tie, isNull);
      expect(events[1].tie, isNull);
    });
  });

  group('音域与 tab 修复', () {
    test('钢琴超音域移八度', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'note', dur: const Rational(1, 1), pitches: [
              ScorePitch(step: 'C', octave: 12), // 超高
            ]),
            ScoreEvent(type: 'note', dur: const Rational(1, 1), pitches: [
              ScorePitch(step: 'A', octave: -1), // 超低
            ]),
            ScoreEvent(type: 'rest', dur: const Rational(2, 1)),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      final ps = doc.parts.first.measures.first.voices.first.events;
      expect(ps[0].pitches.first.octave, lessThanOrEqualTo(8));
      expect(ps[1].pitches.first.octave, greaterThanOrEqualTo(0));
    });

    test('吉他：tab 与音高不一致以 tab 为准', () {
      final doc = ScoreDocument(
        kind: 'guitar',
        meta: ScoreMeta(title: 'G', timeBeats: 4, timeBeatType: 4),
        parts: [
          ScorePart(instrument: 'guitar', staffCount: 1, measures: [
            ScoreMeasure(number: 1, voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'note', dur: const Rational(4, 1), pitches: [
                  ScorePitch(
                      step: 'C', // 错误音高
                      octave: 4,
                      tab: TabPosition(string: 1, fret: 3)), // 1弦3品 = G4
                ]),
              ]),
            ]),
          ]),
        ],
      );
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      final p = doc.parts.first.measures.first.voices.first.events.first.pitches.first;
      expect(p.step, 'G');
      expect(p.octave, 4);
    });

    test('吉他：超界品位 clamp、缺 tab 推导', () {
      final doc = ScoreDocument(
        kind: 'guitar',
        meta: ScoreMeta(title: 'G', timeBeats: 4, timeBeatType: 4),
        parts: [
          ScorePart(instrument: 'guitar', staffCount: 1, measures: [
            ScoreMeasure(number: 1, voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
                  ScorePitch(
                      step: 'E', octave: 4, tab: TabPosition(string: 1, fret: 20)),
                ]),
                ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
                  ScorePitch(step: 'A', octave: 4), // 无 tab → 推导：4弦2品? A4=69: 1弦5品(先查1弦: 69-64=5 ≤14 → 1弦5品)
                ]),
              ]),
            ]),
          ]),
        ],
      );
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      final events = doc.parts.first.measures.first.voices.first.events;
      expect(events[0].pitches.first.tab!.fret, 14);
      expect(events[1].pitches.first.tab!.string, 1);
      expect(events[1].pitches.first.tab!.fret, 5);
    });

    test('rest 事件残留 pitches 被清空', () {
      final doc = _pianoDoc(measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(
                type: 'rest',
                dur: const Rational(4, 1),
                pitches: [ScorePitch(step: 'C', octave: 4)]),
          ]),
        ]),
      ]);
      final r = ScoreValidator.validateAndRepair(doc);
      expect(r.ok, isTrue);
      expect(doc.parts.first.measures.first.voices.first.events.first.pitches,
          isEmpty);
    });
  });
}
