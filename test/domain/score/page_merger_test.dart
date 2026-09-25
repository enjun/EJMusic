import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/merge/page_merger.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('两页合并：编号重排 + meta 取首页', () {
    final p1 = PageFragment(
      page: 1,
      title: '童话',
      composer: '光良',
      keyFifths: 0,
      timeBeats: 4,
      timeBeatType: 4,
      bpm: 88,
      measures: [
        _measure(1, [
          _voice(1, [_note(const Rational(4, 1), 'C', 4)]),
          _voice(2, [_rest(const Rational(4, 1))]),
        ]),
        _measure(2, [
          _voice(1, [_note(const Rational(4, 1), 'D', 4)]),
          _voice(2, [_rest(const Rational(4, 1))]),
        ]),
      ],
    );
    final p2 = PageFragment(page: 2, measures: [
      _measure(3, [
        _voice(1, [_note(const Rational(4, 1), 'E', 4)]),
        _voice(2, [_rest(const Rational(4, 1))]),
      ]),
      _measure(4, [
        _voice(1, [_note(const Rational(4, 1), 'F', 4)]),
        _voice(2, [_rest(const Rational(4, 1))]),
      ]),
    ]);

    final result = PageMerger.merge(fragments: [p2, p1], kind: 'piano');
    final doc = result.document;
    expect(doc.meta.title, '童话');
    expect(doc.meta.composer, '光良');
    final ms = doc.parts.first.measures;
    expect(ms.length, 4);
    expect([for (final m in ms) m.number], [1, 2, 3, 4]);
    // 页序正确（p2 先传入也不影响）
    expect(ms[0].voices.first.events.first.pitches.first.step, 'C');
    expect(ms[2].voices.first.events.first.pitches.first.step, 'E');
  });

  test('cont 小节拼接进前一小节对应 voice（跨页断开小节）', () {
    // 第 1 页末小节只有 2 拍（被下一页承接）
    final p1 = PageFragment(
      page: 1,
      timeBeats: 4,
      timeBeatType: 4,
      title: 'T',
      measures: [
        _measure(1, [
          _voice(1, [_note(const Rational(4, 1), 'C', 4)]),
          _voice(2, [_rest(const Rational(4, 1))]),
        ]),
        ScoreMeasure(
          number: 2,
          voices: [
            _voice(1, [_note(const Rational(2, 1), 'G', 4)]),
            _voice(2, [_rest(const Rational(2, 1))]),
          ],
        ),
      ],
    );
    // 第 2 页首个 cont 小节是上页小节的延续
    final p2 = PageFragment(page: 2, measures: [
      ScoreMeasure(
        number: 2,
        cont: true,
        voices: [
          _voice(1, [_note(const Rational(2, 1), 'A', 4)]),
          _voice(2, [_rest(const Rational(2, 1))]),
        ],
      ),
      _measure(3, [
        _voice(1, [_note(const Rational(4, 1), 'B', 4)]),
        _voice(2, [_rest(const Rational(4, 1))]),
      ]),
    ]);

    final result = PageMerger.merge(fragments: [p1, p2], kind: 'piano');
    final ms = result.document.parts.first.measures;
    expect(ms.length, 3, reason: 'cont 小节被吸收：4 个物理小节 → 3 个逻辑小节');
    expect([for (final m in ms) m.number], [1, 2, 3]);
    final merged = ms[1];
    final rightHand = merged.voices.firstWhere((v) => v.staff == 1);
    expect(rightHand.events.length, 2);
    expect(rightHand.events[0].pitches.first.step, 'G');
    expect(rightHand.events[1].pitches.first.step, 'A');
    expect(rightHand.events[0].dur + rightHand.events[1].dur,
        const Rational(4, 1));
  });

  test('cont 首页小节标记被忽略', () {
    final p1 = PageFragment(
      page: 1,
      title: 'T',
      timeBeats: 4,
      timeBeatType: 4,
      measures: [
        ScoreMeasure(
          number: 1,
          cont: true, // 无前文可承接，直接作为第一小节
          voices: [_voice(1, [_note(const Rational(4, 1), 'C', 4)])],
        ),
      ],
    );
    final result = PageMerger.merge(fragments: [p1], kind: 'piano');
    expect(result.document.parts.first.measures.length, 1);
    expect(result.document.parts.first.measures.first.cont, isFalse);
  });

  test('吉他谱合并', () {
    final frag = PageFragment(
      page: 1,
      title: '指弹练习',
      timeBeats: 4,
      timeBeatType: 4,
      measures: [
        ScoreMeasure(number: 1, voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(
              type: 'note',
              dur: const Rational(4, 1),
              pitches: [
                ScorePitch(step: 'E', octave: 4, tab: TabPosition(string: 1, fret: 0)),
                ScorePitch(step: 'B', octave: 3, tab: TabPosition(string: 2, fret: 0)),
              ],
            ),
          ]),
        ]),
      ],
    );
    final result = PageMerger.merge(fragments: [frag], kind: 'guitar');
    final doc = result.document;
    expect(doc.kind, 'guitar');
    expect(doc.parts.first.staffCount, 1);
    expect(doc.parts.first.instrument, 'guitar');
  });
}

ScoreMeasure _measure(int number, List<ScoreVoice> voices) =>
    ScoreMeasure(number: number, voices: voices);

ScoreVoice _voice(int staff, List<ScoreEvent> events) =>
    ScoreVoice(staff: staff, events: events);

ScoreEvent _note(Rational dur, String step, int octave) => ScoreEvent(
      type: 'note',
      dur: dur,
      pitches: [ScorePitch(step: step, octave: octave)],
    );

ScoreEvent _rest(Rational dur) => ScoreEvent(type: 'rest', dur: dur);
