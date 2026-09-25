import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/convert/split_volume.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:flutter_test/flutter_test.dart';

ScoreMeasure _m(int number, {MeasureAttributes? attrs, bool cont = false}) =>
    ScoreMeasure(
      number: number,
      attributes: attrs,
      cont: cont,
      voices: [
        ScoreVoice(staff: 1, events: [
          ScoreEvent(
              type: 'note',
              dur: const Rational(1, 1),
              pitches: [ScorePitch(step: 'C', octave: 4)]),
        ]),
      ],
    );

ScoreDocument _doc(List<ScoreMeasure> ms) => ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
      parts: [ScorePart(measures: ms)],
    );

void main() {
  test('小曲不分册：单卷覆盖全曲', () {
    final doc = _doc([for (var i = 1; i <= 10; i++) _m(i)]);
    final vols = splitIntoVolumes(doc);
    expect(vols.length, 1);
    expect(vols.single.startQ, const Rational(0, 1));
    expect(vols.single.endQ, const Rational(40, 1));
    expect(vols.single.index, 0);
    expect(vols.single.total, 1);
  });

  test('320 小节 → 150/150/20 三册，拍位连续、小节号保留', () {
    final doc = _doc([for (var i = 1; i <= 320; i++) _m(i)]);
    final vols = splitIntoVolumes(doc);
    expect(vols.length, 3);
    expect(vols[0].document.parts.single.measures.length, 150);
    expect(vols[1].document.parts.single.measures.length, 150);
    expect(vols[2].document.parts.single.measures.length, 20);
    expect(vols[0].startQ, const Rational(0, 1));
    expect(vols[0].endQ, const Rational(600, 1));
    expect(vols[1].startQ, const Rational(600, 1));
    expect(vols[1].endQ, const Rational(1200, 1));
    expect(vols[2].startQ, const Rational(1200, 1));
    expect(vols[2].endQ, const Rational(1280, 1));
    // 小节号保留原编号
    expect(
        vols[1].document.parts.single.measures.first.number, 151);
    expect(
        vols[2].document.parts.single.measures.first.number, 301);
  });

  test('cont 小节跟随前一册，不作为新册首小节', () {
    final ms = <ScoreMeasure>[
      for (var i = 1; i <= 300; i++) _m(i, cont: i == 151),
    ];
    final vols = splitIntoVolumes(_doc(ms));
    expect(vols.length, 2);
    // 第 151 小节 cont=true → 归入第一册（151 小节）
    expect(vols[0].document.parts.single.measures.length, 151);
    expect(vols[1].document.parts.single.measures.first.number, 152);
  });

  test('中途变拍号：区间按新拍数累计', () {
    final ms = <ScoreMeasure>[
      for (var i = 1; i <= 200; i++)
        _m(i,
            attrs: i == 101
                ? MeasureAttributes(timeBeats: 3, timeBeatType: 4)
                : null),
    ];
    final vols = splitIntoVolumes(_doc(ms), maxMeasures: 100);
    expect(vols.length, 2);
    // 前 100 小节 4/4 = 400 拍，第二册从第 101 小节（3/4）开始
    expect(vols[1].startQ, const Rational(400, 1));
    expect(vols[1].endQ, const Rational(400 + 100 * 3, 1));
    expect(vols[1].document.parts.single.measures.first.number, 101);
  });

  test('空曲谱不崩溃', () {
    final vols = splitIntoVolumes(_doc([]));
    expect(vols.length, 1);
    expect(vols.single.endQ, const Rational(0, 1));
  });
}
