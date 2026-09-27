import 'dart:convert';

import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/score/correct/score_diff.dart';
import 'package:ejmusic/domain/score/correct/slice_map.dart';
import 'package:ejmusic/domain/score/merge/page_merger.dart';
import 'package:ejmusic/domain/score/score_document.dart';
import 'package:flutter_test/flutter_test.dart';

ScoreMeasure _measure(int number, List<ScoreVoice> voices,
        {MeasureAttributes? attributes}) =>
    ScoreMeasure(number: number, attributes: attributes, voices: voices);

ScoreVoice _voice(int staff, List<ScoreEvent> events,
        {int voiceNo = 1}) =>
    ScoreVoice(staff: staff, voiceNo: voiceNo, events: events);

ScoreEvent _note(Rational dur, String step, int octave) => ScoreEvent(
      type: 'note',
      dur: dur,
      pitches: [ScorePitch(step: step, octave: octave)],
    );

ScoreEvent _rest(Rational dur) => ScoreEvent(type: 'rest', dur: dur);

ScoreDocument _doc(String kind, ScoreMeta meta, List<ScoreMeasure> measures) =>
    ScoreDocument(
      kind: kind,
      meta: meta,
      parts: [
        ScorePart(instrument: kind, staffCount: 2, measures: measures),
      ],
    );

PageFragment _frag(int page, List<ScoreMeasure> measures) =>
    PageFragment(page: page, title: 'T', measures: measures);

void main() {
  test('loadSliceSpecs：fragments 重合并产出规格', () {
    final fragments = [
      _frag(1, [
        _measure(1, [_voice(1, [_note(const Rational(4, 1), 'C', 4)])]),
      ]),
      _frag(2, [
        _measure(2, [_voice(1, [_note(const Rational(4, 1), 'D', 4)])]),
      ]),
    ];
    final merged = PageMerger.merge(fragments: fragments, kind: 'piano');
    final specs = loadSliceSpecs(
      fragments: fragments,
      current: merged.document,
      kind: 'piano',
    );
    expect(specs.length, 2);
    expect(specs[0].measures.single.measureIndex, 0);
    expect(specs[1].measures.single.measureIndex, 1);
  });

  test('loadSliceSpecs：小节数不匹配抛错', () {
    final fragments = [
      _frag(1, [
        _measure(1, [_voice(1, [_note(const Rational(4, 1), 'C', 4)])]),
      ]),
    ];
    final merged = PageMerger.merge(fragments: fragments, kind: 'piano');
    // 当前谱多了一个小节
    final current = _doc('piano', merged.document.meta, [
      ...merged.document.parts.first.measures,
      _measure(2, [_voice(1, [_note(const Rational(4, 1), 'D', 4)])]),
    ]);
    expect(
      () => loadSliceSpecs(
          fragments: fragments, current: current, kind: 'piano'),
      throwsStateError,
    );
  });

  test('buildSliceDocument：深拷贝 + boundary 小节完整内容', () {
    final fragments = [
      _frag(1, [
        _measure(1, [_voice(1, [_note(const Rational(2, 1), 'C', 4)])]),
      ]),
      _frag(2, [
        ScoreMeasure(number: 1, cont: true, voices: [
          _voice(1, [_note(const Rational(2, 1), 'D', 4)]),
        ]),
      ]),
    ];
    final merged = PageMerger.merge(fragments: fragments, kind: 'piano');
    final doc = merged.document;
    final specs = loadSliceSpecs(
        fragments: fragments, current: doc, kind: 'piano');

    final slice2 = buildSliceDocument(doc, specs[1]);
    expect(slice2.parts.first.measures.length, 1);
    final m = slice2.parts.first.measures.single;
    expect(m.voices.single.events.length, 2,
        reason: 'boundary 小节切出完整内容（含上一页头部）');
    // 深拷贝：改切片不影响原谱
    m.voices.single.events[0] = _rest(const Rational(1, 1));
    expect(doc.parts.first.measures[0].voices.single.events[0].type, 'note');

    final slice1 = buildSliceDocument(doc, specs[0]);
    expect(slice1.parts.first.measures.single.number, 1,
        reason: '保留合并谱小节号');
  });

  test('diffSlice：改音高 → modifyEvent；applyChanges 往返', () {
    final original = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'C', 4),
          _note(const Rational(1, 1), 'E', 4),
        ]),
        _voice(2, [_rest(const Rational(2, 1))]),
      ]),
      _measure(2, [
        _voice(1, [_note(const Rational(2, 1), 'G', 4)]),
      ]),
    ]);
    final corrected = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'C', 4),
          _note(const Rational(1, 1), 'G', 4), // E4 → G4
        ]),
        _voice(2, [_rest(const Rational(2, 1))]),
      ]),
      _measure(2, [
        _voice(1, [_note(const Rational(2, 1), 'G', 4)]),
      ]),
    ]);
    final spec = PageSliceSpec(page: 1)
      ..measures.addAll([
        MeasureSliceSpec(measureIndex: 0),
        MeasureSliceSpec(measureIndex: 1),
      ]);
    final (changes: changes, warnings: warnings) = diffSlice(
      original: original,
      corrected: corrected,
      spec: spec,
      page: 1,
    );
    expect(warnings, isEmpty);
    expect(changes.length, 1);
    expect(changes.single.kind, ScoreChangeKind.modifyEvent);
    expect(changes.single.eventIndex, 1);
    expect(changes.single.before, contains('E4'));
    expect(changes.single.after, contains('G4'));
    expect(changes.single.selected, isTrue);

    // apply 往返
    final target = cloneDocument(original);
    applyChanges(target, changes);
    expect(
      jsonEncode(target.parts.first.measures[0].voices[0].events[1].toJson()),
      jsonEncode(corrected.parts.first.measures[0].voices[0].events[1].toJson()),
    );
  });

  test('diffSlice：事件数变化 → rewriteVoice；属性变化 → modifyAttributes', () {
    final original = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'C', 4),
          _note(const Rational(1, 1), 'E', 4),
        ]),
      ], attributes: MeasureAttributes(repeatStart: true)),
    ]);
    final corrected = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(2, 1), 'C', 4),
        ]),
      ], attributes: MeasureAttributes(repeatStart: false)),
    ]);
    final spec = PageSliceSpec(page: 1)
      ..measures.add(MeasureSliceSpec(measureIndex: 0));
    final (changes: changes, warnings: _) = diffSlice(
      original: original,
      corrected: corrected,
      spec: spec,
      page: 1,
    );
    final kinds = [for (final c in changes) c.kind];
    expect(kinds, containsAll([
      ScoreChangeKind.rewriteVoice,
      ScoreChangeKind.modifyAttributes,
    ]));
  });

  test('diffSlice：boundary 小节未拥有区间被改 → 守卫拦截 + 告警', () {
    // 合并谱小节 0：staff1 两个事件，本页只拥有第 2 个（区间 (1,2)）
    final original = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'C', 4), // 上一页的头部，不可改
          _note(const Rational(1, 1), 'E', 4),
        ]),
      ]),
    ]);
    // LLM 把头部 C4 也改了 → 守卫必须拦截整个小节
    final corrected = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'G', 3),
          _note(const Rational(1, 1), 'A', 4),
        ]),
      ]),
    ]);
    final spec = PageSliceSpec(page: 2);
    final ms = MeasureSliceSpec(measureIndex: 0, boundary: true)
      ..ownedRanges['1:1'] = [(1, 2)];
    spec.measures.add(ms);

    final (changes: changes, warnings: warnings) = diffSlice(
      original: original,
      corrected: corrected,
      spec: spec,
      page: 2,
    );
    expect(changes, isEmpty, reason: '跨界改动的小节整段丢弃');
    expect(warnings, isNotEmpty);
    expect(warnings.first, contains('跨页'));
  });

  test('diffSlice：boundary 小节只改拥有区间 → 正常产出', () {
    final original = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'C', 4),
          _note(const Rational(1, 1), 'E', 4),
        ]),
      ]),
    ]);
    final corrected = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [
          _note(const Rational(1, 1), 'C', 4),
          _note(const Rational(1, 1), 'G', 4), // 拥有区间内 E4 → G4
        ]),
      ]),
    ]);
    final spec = PageSliceSpec(page: 2);
    final ms = MeasureSliceSpec(measureIndex: 0, boundary: true)
      ..ownedRanges['1:1'] = [(1, 2)];
    spec.measures.add(ms);
    final (changes: changes, warnings: warnings) = diffSlice(
      original: original,
      corrected: corrected,
      spec: spec,
      page: 2,
    );
    expect(warnings, isEmpty);
    expect(changes.length, 1);
    expect(changes.single.kind, ScoreChangeKind.modifyEvent);
    expect(changes.single.eventIndex, 1);
  });

  test('applyChanges：跳过未勾选的改动', () {
    final doc = _doc('piano', ScoreMeta(), [
      _measure(1, [
        _voice(1, [_note(const Rational(1, 1), 'C', 4)]),
      ]),
    ]);
    final change = ScoreChange(
      page: 1,
      measureIndex: 0,
      measureNumber: 1,
      staff: 1,
      voiceNo: 1,
      eventIndex: 0,
      kind: ScoreChangeKind.modifyEvent,
      description: 'test',
      event: _note(const Rational(1, 1), 'D', 4),
      selected: false,
    );
    applyChanges(doc, [change]);
    expect(doc.parts.first.measures[0].voices[0].events[0].pitches.first.step,
        'C', reason: '未勾选不应用');
    change.selected = true;
    applyChanges(doc, [change]);
    expect(doc.parts.first.measures[0].voices[0].events[0].pitches.first.step,
        'D');
  });
}
