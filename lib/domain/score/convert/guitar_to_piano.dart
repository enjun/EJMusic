import '../../../core/util/midi.dart';
import '../../../core/util/rational.dart';
import '../score_document.dart';
import 'convert_result.dart';

/// 吉他谱（六线谱）→ 钢琴谱（大谱表）。
///
/// midi = 空弦音高 + 品数，直接换算音名（升号优先）；
/// 以 C4（midi 60）分手：≥C4 进右手（staff 1），低于 C4 进左手（staff 2），
/// 各声部用休止符补齐空档，保证每小节拍数守恒。时值保持不变。
ConvertResult guitarToPiano(ScoreDocument doc) {
  final beats = Rational(doc.meta.timeBeats * 4, doc.meta.timeBeatType);
  final measures = <ScoreMeasure>[];

  for (final m in doc.parts.expand((p) => p.measures)) {
    final rh = <ScoreEvent>[];
    final lh = <ScoreEvent>[];
    var rhPos = const Rational(0, 1);
    var lhPos = const Rational(0, 1);
    var t = const Rational(0, 1);

    for (final v in m.voices) {
      for (final e in v.events) {
        if (e.isRest) {
          t += e.dur;
          continue;
        }
        final midis = [
          for (final p in e.pitches)
            p.tab != null
                ? tabToMidi(p.tab!.string, p.tab!.fret)
                : pitchToMidi(p.step, p.alter, p.octave),
        ];
        final avg = midis.reduce((a, b) => a + b) / midis.length;
        final toRh = avg >= 60; // C4 分手
        final pitches = [
          for (var k = 0; k < e.pitches.length; k++)
            () {
              final (step, alter, octave) = midiToPitch(midis[k]);
              return ScorePitch(
                  step: step,
                  alter: alter,
                  octave: octave,
                  finger: e.pitches[k].finger);
            }(),
        ];
        final converted = ScoreEvent(
          type: 'note',
          dur: e.dur,
          dots: e.dots,
          pitches: pitches,
          tie: e.tie,
          slur: e.slur,
          tupletActual: e.tupletActual,
          tupletNormal: e.tupletNormal,
          articulations: e.articulations,
        );
        if (toRh) {
          if (rhPos < t) {
            rh.add(ScoreEvent(type: 'rest', dur: t - rhPos));
            rhPos = t;
          }
          rh.add(converted);
          rhPos = t + e.dur;
        } else {
          if (lhPos < t) {
            lh.add(ScoreEvent(type: 'rest', dur: t - lhPos));
            lhPos = t;
          }
          lh.add(converted);
          lhPos = t + e.dur;
        }
        t += e.dur;
      }
    }
    if (rhPos < beats) rh.add(ScoreEvent(type: 'rest', dur: beats - rhPos));
    if (lhPos < beats) lh.add(ScoreEvent(type: 'rest', dur: beats - lhPos));

    measures.add(ScoreMeasure(
      number: m.number,
      cont: m.cont,
      attributes: m.attributes,
      voices: [
        ScoreVoice(staff: 1, events: rh),
        ScoreVoice(staff: 2, events: lh),
      ],
    ));
  }

  final out = ScoreDocument(
    kind: 'piano',
    meta: doc.meta,
    parts: [
      ScorePart(
        id: 'P1',
        instrument: 'piano',
        staffCount: 2,
        measures: measures,
      ),
    ],
  );
  return ConvertResult(document: out);
}
