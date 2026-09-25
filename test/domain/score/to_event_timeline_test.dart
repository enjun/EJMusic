import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/convert/to_event_timeline.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:flutter_test/flutter_test.dart';

ScoreDocument _doc(List<ScoreMeasure> measures) => ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
      parts: [ScorePart(measures: measures)],
    );

ScoreMeasure _m(int number,
        {bool repeatStart = false,
        bool repeatEnd = false,
        int? repeatTimes,
        int? voltaNo,
        int? voltaOf,
        List<int> steps = const [60]}) =>
    ScoreMeasure(
      number: number,
      attributes: repeatStart || repeatEnd || voltaNo != null
          ? MeasureAttributes(
              repeatStart: repeatStart,
              repeatEnd: repeatEnd,
              repeatTimes: repeatTimes,
              voltaNo: voltaNo,
              voltaOf: voltaOf,
            )
          : null,
      voices: [
        ScoreVoice(staff: 1, events: [
          for (final s in steps)
            ScoreEvent(
                type: 'note',
                dur: const Rational(1, 1),
                pitches: [ScorePitch(step: 'C', octave: s ~/ 12 - 1, alter: s % 12)]),
        ]),
      ],
    );

void main() {
  test('无反复：按原顺序展开', () {
    final t = buildTimeline(_doc([_m(1), _m(2), _m(3)]));
    expect(t.notes.map((n) => n.measureNumber), [1, 2, 3]);
    expect(t.totalQ, const Rational(12, 1));
    expect(t.notes.first.startQ, const Rational(0, 1));
    expect(t.notes[1].startQ, const Rational(4, 1));
  });

  test('反复记号 |: A :| B：A 演两遍', () {
    final t = buildTimeline(_doc([
      _m(1, repeatStart: true),
      _m(2, repeatEnd: true),
      _m(3),
    ]));
    expect(t.notes.map((n) => n.measureNumber), [1, 2, 1, 2, 3]);
    expect(t.totalQ, const Rational(20, 1));
    // 第二遍的 originalStartQ 仍指向原谱位置
    final second = t.notes[2];
    expect(second.startQ, const Rational(8, 1));
    expect(second.originalStartQ, const Rational(0, 1));
    expect(second.measureNumber, 1);
  });

  test('volta 1/2 结尾', () {
    final t = buildTimeline(_doc([
      _m(1, repeatStart: true),
      _m(2, repeatEnd: true, voltaNo: 1, voltaOf: 2),
      _m(3, voltaNo: 2, voltaOf: 2),
    ]));
    // 第一遍：1 2；第二遍：1 3
    expect(t.notes.map((n) => n.measureNumber), [1, 2, 1, 3]);
  });

  test('repeatTimes=3', () {
    final t = buildTimeline(_doc([
      _m(1, repeatStart: true),
      _m(2, repeatEnd: true, repeatTimes: 3),
    ]));
    expect(t.notes.map((n) => n.measureNumber), [1, 2, 1, 2, 1, 2]);
  });

  test('同 onset 声部合并 + midi 集合', () {
    final doc = ScoreDocument(
      kind: 'guitar',
      meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(instrument: 'guitar', staffCount: 1, measures: [
          ScoreMeasure(
            number: 1,
            voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(type: 'note', dur: const Rational(4, 1), pitches: [
                  ScorePitch(step: 'C', octave: 4,
                      tab: TabPosition(string: 2, fret: 1)), // 60
                  ScorePitch(step: 'E', octave: 4,
                      tab: TabPosition(string: 1, fret: 0)), // 64
                ]),
              ]),
            ],
          ),
        ]),
      ],
    );
    final t = buildTimeline(doc);
    expect(t.notes.single.midis, [60, 64]);
    expect(t.allMidis, {60, 64});
  });

  test('indexAtQ 二分定位', () {
    final t = buildTimeline(_doc([_m(1), _m(2)]));
    expect(t.indexAtQ(const Rational(0, 1)), 0);
    expect(t.indexAtQ(const Rational(3, 1)), 0);
    expect(t.indexAtQ(const Rational(5, 1)), 1);
  });
}
