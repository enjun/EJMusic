import '../../../core/util/midi.dart';
import '../../../core/util/rational.dart';
import '../score_document.dart';

/// 演奏时间轴上的一个发音点（和弦或单音，休止不生成）。
class TimelineNote {
  TimelineNote({
    required this.startQ,
    required this.durQ,
    required this.midis,
    required this.originalStartQ,
    required this.measureNumber,
  });

  /// 展开反复后的位置（四分音符单位）。
  final Rational startQ;
  final Rational durQ;

  /// 发音的 MIDI 音高集合（键盘高亮/跟弹判定用）。
  final List<int> midis;

  /// 原谱（未展开反复）中的位置——用于驱动渲染光标。
  final Rational originalStartQ;
  final int measureNumber;

  bool get isRest => midis.isEmpty;
}

/// 演奏事件轴。
class EventTimeline {
  EventTimeline({required this.notes, required this.totalQ});

  final List<TimelineNote> notes;

  /// 展开反复后的总时长（四分音符单位）。
  final Rational totalQ;

  /// 所有出现的 midi（键盘可见范围参考）。
  Set<int> get allMidis => {for (final n in notes) ...n.midis};

  /// 给定展开位置（四分音符）求当前音符下标；休止/空隙取上一个发音点。
  int indexAtQ(Rational q) {
    var lo = 0;
    var hi = notes.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (notes[mid].startQ <= q) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

/// 由 EJScore 构建演奏事件轴：展开反复/volta，展平为发音点序列。
EventTimeline buildTimeline(ScoreDocument doc) {
  final measures = doc.parts.expand((p) => p.measures).toList();

  // 1) 原谱每小节起始位置与小节拍数（跟随拍号变更）
  final starts = <Rational>[];
  final beatsOf = <Rational>[];
  var curBeats = Rational(doc.meta.timeBeats * 4, doc.meta.timeBeatType);
  var acc = const Rational(0, 1);
  for (final m in measures) {
    final a = m.attributes;
    if (a?.timeBeats != null && a?.timeBeatType != null) {
      curBeats = Rational(a!.timeBeats! * 4, a.timeBeatType!);
    }
    starts.add(acc);
    beatsOf.add(curBeats);
    acc += curBeats;
  }

  // 2) 反复/volta 展开为原谱小节下标序列
  final order = _expandRepeats(measures);

  // 3) 展平事件：同一 onset 的所有声部音合并为一个发音点
  final notes = <TimelineNote>[];
  var expandedQ = const Rational(0, 1);
  for (final i in order) {
    final m = measures[i];
    final beats = beatsOf[i];
    final midisByOnset = <Rational, List<int>>{};
    final durByOnset = <Rational, Rational>{};
    for (final v in m.voices) {
      var t = const Rational(0, 1);
      for (final e in v.events) {
        if (e.isNote) {
          final list = midisByOnset.putIfAbsent(t, () => []);
          for (final p in e.pitches) {
            list.add(p.tab != null
                ? tabToMidi(p.tab!.string, p.tab!.fret)
                : pitchToMidi(p.step, p.alter, p.octave));
          }
          if (e.dur > (durByOnset[t] ?? const Rational(0, 1))) {
            durByOnset[t] = e.dur;
          }
        }
        t += e.dur;
      }
    }
    for (final onset in midisByOnset.keys) {
      final midis = midisByOnset[onset]!..sort();
      notes.add(TimelineNote(
        startQ: expandedQ + onset,
        durQ: durByOnset[onset] ?? beats - onset,
        midis: midis,
        originalStartQ: starts[i] + onset,
        measureNumber: m.number,
      ));
    }
    expandedQ += beats;
  }

  notes.sort((a, b) => a.startQ.compareTo(b.startQ));
  return EventTimeline(notes: notes, totalQ: expandedQ);
}

/// 展开反复/volta，返回原谱小节下标的播放顺序。
/// MVP 支持单层 `|: … :|`（含 repeatTimes）与 volta 1/2 结尾；D.S./Coda 跳过。
List<int> _expandRepeats(List<ScoreMeasure> measures) {
  final order = <int>[];
  var repeatStart = 0; // 最近未闭合的反复起点
  var pass = 1;

  var i = 0;
  while (i < measures.length) {
    final a = measures[i].attributes;
    final volta = a?.voltaNo;

    if (volta != null && volta != pass) {
      // 跳过本轮不该演奏的 volta 块
      while (i < measures.length && measures[i].attributes?.voltaNo == volta) {
        i++;
      }
      continue;
    }

    if (a?.repeatStart == true) {
      repeatStart = i;
    }

    order.add(i);

    var voltaBlockEnded = false;
    if (volta != null) {
      // 走完该 volta 块
      while (i + 1 < measures.length &&
          measures[i + 1].attributes?.voltaNo == volta) {
        i++;
        order.add(i);
      }
      final hasNextVolta = i + 1 < measures.length &&
          measures[i + 1].attributes?.voltaNo == volta + 1;
      if (!hasNextVolta) voltaBlockEnded = true;
    }

    if (a?.repeatEnd == true) {
      final times = a?.repeatTimes ?? 2;
      if (pass < times) {
        pass++;
        i = repeatStart;
        continue;
      }
      pass = 1;
      repeatStart = 0;
    } else if (voltaBlockEnded) {
      pass = 1;
      repeatStart = 0;
    }
    i++;
  }
  return order;
}
