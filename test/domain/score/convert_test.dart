import 'package:ejmusic/core/util/midi.dart';
import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/convert/guitar_to_piano.dart';
import 'package:ejmusic/domain/score/convert/piano_to_guitar.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:ejmusic/domain/score/score_validator.dart';
import 'package:flutter_test/flutter_test.dart';

ScoreDocument _piano4_4() => ScoreDocument(
      kind: 'piano',
      meta: ScoreMeta(title: '测试曲', timeBeats: 4, timeBeatType: 4),
      parts: [
        ScorePart(measures: [
          ScoreMeasure(
            number: 1,
            voices: [
              ScoreVoice(staff: 1, events: [
                ScoreEvent(
                    type: 'note',
                    dur: const Rational(1, 1),
                    pitches: [
                      ScorePitch(step: 'C', octave: 4),
                      ScorePitch(step: 'E', octave: 4),
                      ScorePitch(step: 'G', octave: 4),
                    ]),
                ScoreEvent(
                    type: 'note',
                    dur: const Rational(1, 1),
                    pitches: [ScorePitch(step: 'D', octave: 4)]),
                ScoreEvent(
                    type: 'note',
                    dur: const Rational(1, 1),
                    pitches: [ScorePitch(step: 'E', octave: 4)]),
                ScoreEvent(
                    type: 'note',
                    dur: const Rational(1, 1),
                    pitches: [ScorePitch(step: 'F', octave: 4)]),
              ]),
            ],
          ),
        ]),
      ],
    );

void main() {
  group('pianoToGuitar', () {
    test('单音按最近指位转换：C4 → 2弦1品', () {
      final doc = ScoreDocument(
        kind: 'piano',
        meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
        parts: [
          ScorePart(measures: [
            ScoreMeasure(
              number: 1,
              voices: [
                ScoreVoice(staff: 1, events: [
                  ScoreEvent(
                      type: 'note',
                      dur: const Rational(4, 1),
                      pitches: [ScorePitch(step: 'C', octave: 4)]),
                ]),
              ],
            ),
          ]),
        ],
      );
      final r = pianoToGuitar(doc);
      final e = r.document.parts.first.measures.first.voices.first.events.single;
      final p = e.pitches.single;
      expect(p.tab!.string, 2);
      expect(p.tab!.fret, 1); // 60 - 59
      expect(p.finger, 1);
    });

    test('和弦合并为同一事件且跨度 ≤4', () {
      final r = pianoToGuitar(_piano4_4());
      final m = r.document.parts.first.measures.first;
      final events = m.voices.first.events;
      // 4 个 onset → 4 个事件
      expect(events.length, 4);
      final chord = events.first.pitches;
      expect(chord.length, 3);
      // 每个音都有 tab，非空弦跨度 ≤4
      final fretted = [
        for (final p in chord)
          if (p.tab!.fret > 0) p.tab!.fret,
      ];
      if (fretted.length >= 2) {
        expect(fretted.reduce((a, b) => a > b ? a : b) -
                fretted.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(4));
      }
      // 同一事件内不共用弦
      expect(chord.map((p) => p.tab!.string).toSet().length, chord.length);
    });

    test('切片时长填满小节（拍数守恒），校验无超拍', () {
      final r = pianoToGuitar(_piano4_4());
      final v = ScoreValidator.validateAndRepair(r.document);
      final durSum = r.document.parts.first.measures.first.voices.first.events
          .fold(const Rational(0, 1), (a, e) => a + e.dur);
      expect(durSum, const Rational(4, 1));
      expect(v.errors.where((e) => e.code == 'measure_overfull'), isEmpty);
    });

    test('低于音域的音移高八度并给出 warning', () {
      final doc = ScoreDocument(
        kind: 'piano',
        meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
        parts: [
          ScorePart(measures: [
            ScoreMeasure(
              number: 1,
              voices: [
                ScoreVoice(staff: 2, events: [
                  ScoreEvent(
                      type: 'note',
                      dur: const Rational(4, 1),
                      pitches: [ScorePitch(step: 'C', octave: 2)]), // 36 < E2=40
                ]),
              ],
            ),
          ]),
        ],
      );
      final r = pianoToGuitar(doc);
      final p = r.document.parts.first.measures.first.voices.first.events
          .single.pitches.single;
      expect(pitchToMidi(p.step, p.alter, p.octave), 48); // C3
      expect(r.warnings.join(), contains('移高八度'));
    });

    test('guitar 产物带重复记号属性', () {
      final doc = _piano4_4();
      doc.parts.first.measures.first.attributes =
          MeasureAttributes(repeatStart: true, repeatEnd: true);
      final r = pianoToGuitar(doc);
      expect(
          r.document.parts.first.measures.first.attributes!.repeatStart, isTrue);
    });
  });

  group('guitarToPiano', () {
    test('tab → 音高换算正确，C4 分手', () {
      final doc = ScoreDocument(
        kind: 'guitar',
        meta: ScoreMeta(timeBeats: 4, timeBeatType: 4),
        parts: [
          ScorePart(instrument: 'guitar', staffCount: 1, measures: [
            ScoreMeasure(
              number: 1,
              voices: [
                ScoreVoice(staff: 1, events: [
                  // G3 (3弦0品=55) → 左手；E4 (1弦0品=64) → 右手
                  ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
                    ScorePitch(step: 'G', octave: 3,
                        tab: TabPosition(string: 3, fret: 0)),
                  ]),
                  ScoreEvent(type: 'note', dur: const Rational(2, 1), pitches: [
                    ScorePitch(step: 'E', octave: 4,
                        tab: TabPosition(string: 1, fret: 0)),
                  ]),
                ]),
              ],
            ),
          ]),
        ],
      );
      final r = guitarToPiano(doc);
      expect(r.document.kind, 'piano');
      final m = r.document.parts.first.measures.first;
      expect(m.voices.length, 2);
      final rh = m.voices.firstWhere((v) => v.staff == 1);
      final lh = m.voices.firstWhere((v) => v.staff == 2);
      // 左手：补 1 拍 rest？不对——G3 在 onset 0，占 2 拍 → lh=[G3 二分]; 后 2 拍无音 → 补 rest
      expect(lh.events.first.pitches.single.octave, 3);
      expect(lh.events.fold(const Rational(0, 1), (a, e) => a + e.dur),
          const Rational(4, 1));
      // 右手：onset 2 起 → 先补 2 拍 rest，再 E4 二分
      expect(rh.events.first.isRest, isTrue);
      expect(rh.events.first.dur, const Rational(2, 1));
      expect(rh.events.last.pitches.single.step, 'E');
    });

    test('拍数守恒 + 校验通过', () {
      final doc = ScoreDocument(
        kind: 'guitar',
        meta: ScoreMeta(timeBeats: 3, timeBeatType: 4),
        parts: [
          ScorePart(instrument: 'guitar', staffCount: 1, measures: [
            ScoreMeasure(
              number: 1,
              voices: [
                ScoreVoice(staff: 1, events: [
                  for (final f in [0, 2, 4])
                    ScoreEvent(type: 'note', dur: const Rational(1, 1), pitches: [
                      ScorePitch(step: 'C', octave: 4,
                          tab: TabPosition(string: 2, fret: f)),
                    ]),
                ]),
              ],
            ),
          ]),
        ],
      );
      final r = guitarToPiano(doc);
      final v = ScoreValidator.validateAndRepair(r.document);
      expect(v.errors, isEmpty);
    });
  });
}
