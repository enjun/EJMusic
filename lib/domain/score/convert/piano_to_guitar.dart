import '../../../core/util/midi.dart';
import '../../../core/util/rational.dart';
import '../score_document.dart';
import 'convert_result.dart';

/// 钢琴谱 → 吉他谱（六线谱）。
///
/// 做法：小节内按 onset 展平为和弦切片（同 onset 的所有音合成一个事件，
/// 切片时长 = 到下一 onset 的距离，末片延至小节末，保证拍数守恒），
/// 再对每个和弦用回溯搜索分配指位（约束：非空弦跨度 ≤4 品、同弦不双音；
/// 代价：跨度 + 低把位优先 + 与上一和弦的指法跳变 + 横按奖励）。
/// 超出吉他音域 [E2, E6+14] 的音就近移八度并记 warning。
ConvertResult pianoToGuitar(ScoreDocument doc) {
  final warnings = <String>[];
  final measures = <ScoreMeasure>[];
  var shiftedDown = false;
  var shiftedUp = false;

  final beats = Rational(doc.meta.timeBeats * 4, doc.meta.timeBeatType);

  for (final m in doc.parts.expand((p) => p.measures)) {
    // 1) 收集 onset → pitches
    final onsets = <Rational, List<ScorePitch>>{};
    for (final v in m.voices) {
      var t = const Rational(0, 1);
      for (final e in v.events) {
        if (e.isNote) {
          onsets.putIfAbsent(t, () => []).addAll(e.pitches);
        }
        t += e.dur;
      }
    }
    if (onsets.isEmpty) {
      measures.add(ScoreMeasure(
        number: m.number,
        cont: m.cont,
        attributes: m.attributes,
        voices: [
          ScoreVoice(staff: 1, events: [
            ScoreEvent(type: 'rest', dur: beats),
          ]),
        ],
      ));
      continue;
    }

    // 2) 和弦切片：时长 = 下一 onset 边界，末片至小节末
    final keys = onsets.keys.toList()..sort();
    final events = <ScoreEvent>[];
    List<TabPosition> prevChord = const [];
    for (var i = 0; i < keys.length; i++) {
      final sliceDur = (i + 1 < keys.length ? keys[i + 1] : beats) - keys[i];
      final midis = [
        for (final p in onsets[keys[i]]!) pitchToMidi(p.step, p.alter, p.octave)
      ]..sort();
      // 先做音域适配，再分配指位
      final adapted = <int>[];
      for (final midi in midis) {
        var m = midi;
        while (m < guitarOpenStringMidi[5]) {
          m += 12;
          shiftedUp = true;
        }
        while (m > guitarOpenStringMidi[0] + _maxFret) {
          m -= 12;
          shiftedDown = true;
        }
        adapted.add(m);
      }
      final positions = _assignFretboard(adapted, prevChord.isEmpty ? null : prevChord);
      prevChord = positions;
      final fingers = _assignFingers(positions);
      events.add(ScoreEvent(
        type: 'note',
        dur: sliceDur,
        pitches: [
          for (var k = 0; k < adapted.length; k++)
            _buildPitch(adapted[k], positions[k], fingers[k]),
        ],
      ));
    }
    measures.add(ScoreMeasure(
      number: m.number,
      cont: m.cont,
      attributes: m.attributes,
      voices: [ScoreVoice(staff: 1, events: events)],
    ));
  }

  if (shiftedUp) {
    warnings.add('部分音低于吉他音域（E2），已移高八度');
  }
  if (shiftedDown) {
    warnings.add('部分音高于吉他指板音域（1弦14品），已移低八度');
  }
  warnings.add('钢琴谱为多声部，转换按同时发声合并为和弦，延音较长的声部不会保持');

  final out = ScoreDocument(
    kind: 'guitar',
    meta: doc.meta,
    parts: [
      ScorePart(
        id: 'P1',
        instrument: 'guitar',
        staffCount: 1,
        measures: measures,
      ),
    ],
  );
  return ConvertResult(document: out, warnings: warnings);
}

const _maxFret = 14;

ScorePitch _buildPitch(int midi, TabPosition pos, int? finger) {
  final (step, alter, octave) = midiToPitch(midi);
  return ScorePitch(
      step: step, alter: alter, octave: octave, tab: pos, finger: finger);
}

/// 指法：按品低→高分配 1..4；同品相邻弦合并为横按（同指）。
List<int?> _assignFingers(List<TabPosition> positions) {
  final idx = <int>[
    for (var k = 0; k < positions.length; k++)
      if (positions[k].fret > 0) k,
  ]..sort((a, b) {
      final byFret = positions[a].fret.compareTo(positions[b].fret);
      return byFret != 0 ? byFret : positions[b].string.compareTo(positions[a].string);
    });
  final result = List<int?>.filled(positions.length, null);
  var finger = 1;
  var i = 0;
  while (i < idx.length) {
    var j = i;
    while (j + 1 < idx.length &&
        positions[idx[j + 1]].fret == positions[idx[i]].fret &&
        positions[idx[j + 1]].string == positions[idx[j]].string - 1) {
      j++;
    }
    final f = finger > 4 ? 4 : finger;
    for (var k = i; k <= j; k++) {
      result[idx[k]] = f;
    }
    finger++;
    i = j + 1;
  }
  return result;
}

/// 为一个和弦（midis 升序）回溯搜索指位。
List<TabPosition> _assignFretboard(List<int> midis, List<TabPosition>? prev) {
  final candidates = [
    for (final midi in midis)
      [
        for (var s = 1; s <= 6; s++)
          if (midi >= guitarOpenStringMidi[s - 1] &&
              midi - guitarOpenStringMidi[s - 1] <= _maxFret)
            TabPosition(string: s, fret: midi - guitarOpenStringMidi[s - 1]),
      ],
  ];

  var bestCost = double.infinity;
  List<TabPosition>? best;

  void dfs(int i, Set<int> usedStrings, List<int> frets, List<TabPosition> acc,
      double cost) {
    if (cost >= bestCost) return;
    if (i == midis.length) {
      final total = cost + _chordCost(acc, prev);
      if (total < bestCost) {
        bestCost = total;
        best = [...acc];
      }
      return;
    }
    for (final c in candidates[i]) {
      if (usedStrings.contains(c.string)) continue;
      final fretted = [
        for (final p in acc) if (p.fret > 0) p.fret,
        if (c.fret > 0) c.fret,
      ];
      if (fretted.length >= 2) {
        final span = fretted.reduce((a, b) => a > b ? a : b) -
            fretted.reduce((a, b) => a < b ? a : b);
        if (span > 4) continue; // 非空弦跨度约束
      }
      acc.add(c);
      dfs(i + 1, {...usedStrings, c.string}, [...frets, c.fret], acc, cost);
      acc.removeLast();
    }
  }

  dfs(0, {}, [], [], 0);
  // 理论上总可行（每音弦够用），兜底：低把位顺排
  return best ??
      [
        for (var k = 0; k < midis.length; k++)
          TabPosition(string: (k % 6) + 1, fret: 0),
      ];
}

/// 和弦静态代价：跨度 + 低把位 + 横按奖励 + 与上一和弦的跳变。
double _chordCost(List<TabPosition> chord, List<TabPosition>? prev) {
  final fretted = [for (final p in chord) if (p.fret > 0) p.fret];
  var cost = 0.0;
  if (fretted.length >= 2) {
    final span = fretted.reduce((a, b) => a > b ? a : b) -
        fretted.reduce((a, b) => a < b ? a : b);
    cost += span * 1.0;
    cost += (fretted.reduce((a, b) => a + b) / fretted.length) * 0.25;
  }
  // 横按奖励：相邻弦同品
  final sorted = [...chord]..sort((a, b) => a.string.compareTo(b.string));
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].fret == sorted[i - 1].fret &&
        sorted[i].string == sorted[i - 1].string + 1 &&
        sorted[i].fret > 0) {
      cost -= 0.5;
    }
  }
  // 与上一和弦的指法跳变
  if (prev != null && prev.isNotEmpty) {
    var jump = 0.0;
    var matched = 0;
    for (final p in chord) {
      final pp = prev.where((q) => q.string == p.string).toList();
      if (pp.isNotEmpty) {
        jump += (p.fret - pp.first.fret).abs().toDouble();
        matched++;
      }
    }
    if (matched > 0) {
      cost += (jump / matched) * 0.6;
    } else {
      final prevAvg =
          prev.map((p) => p.fret).reduce((a, b) => a + b) / prev.length;
      final curAvg =
          chord.map((p) => p.fret).reduce((a, b) => a + b) / chord.length;
      cost += (curAvg - prevAvg).abs() * 0.5;
    }
  }
  return cost;
}
