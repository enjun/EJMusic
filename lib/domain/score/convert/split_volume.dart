import '../../../core/util/rational.dart';
import '../score_document.dart';

/// 长曲分册：小节过多时切分为多个分册文档，逐册渲染避免 WebView 卡顿/OOM。
class ScoreVolume {
  const ScoreVolume({
    required this.document,
    required this.startQ,
    required this.endQ,
    required this.index,
    required this.total,
  });

  /// 该分册的子文档（小节号保留原编号，meta 原样共享）。
  final ScoreDocument document;

  /// 原曲线性拍位区间（不展开反复），供光标映射到分册内局部位置。
  final Rational startQ;
  final Rational endQ;

  final int index;
  final int total;
}

/// 单册曲也返回覆盖全曲的一个 ScoreVolume，调用方无需区分。
/// 切分规则：每册 ≤ [maxMeasures] 小节；cont=true 的跨页小节跟随前一小节，
/// 不会成为新分册的首小节。
List<ScoreVolume> splitIntoVolumes(ScoreDocument doc, {int maxMeasures = 150}) {
  final part = doc.parts.first;
  final measures = part.measures;

  // 每小节的起始拍位（跟随拍号变化）
  final starts = <Rational>[];
  var beats = Rational(doc.meta.timeBeats * 4, doc.meta.timeBeatType);
  var acc = const Rational(0, 1);
  for (final m in measures) {
    final a = m.attributes;
    if (a?.timeBeats != null && a?.timeBeatType != null) {
      beats = Rational(a!.timeBeats! * 4, a.timeBeatType!);
    }
    starts.add(acc);
    // Rational.+/ 不自动约分，长曲逐小节累加分母会指数膨胀溢出，必须逐步约分
    acc = (acc + beats).reduced();
  }

  final chunks = <(int, int)>[];
  if (measures.length <= maxMeasures) {
    chunks.add((0, measures.length));
  } else {
    var begin = 0;
    while (begin < measures.length) {
      var end = (begin + maxMeasures).clamp(begin, measures.length);
      while (end < measures.length && measures[end].cont) {
        end++;
      }
      chunks.add((begin, end));
      begin = end;
    }
  }

  return [
    for (var i = 0; i < chunks.length; i++)
      _buildVolume(
          doc, part, measures, starts, acc, chunks[i].$1, chunks[i].$2, i,
          chunks.length),
  ];
}

ScoreVolume _buildVolume(
  ScoreDocument doc,
  ScorePart part,
  List<ScoreMeasure> measures,
  List<Rational> starts,
  Rational totalEnd,
  int begin,
  int end,
  int index,
  int total,
) {
  final sub = List<ScoreMeasure>.generate(
      end - begin, (i) => measures[begin + i],
      growable: false);
  return ScoreVolume(
    document: ScoreDocument(
      kind: doc.kind,
      meta: doc.meta,
      parts: [
        ScorePart(
          id: part.id,
          instrument: part.instrument,
          staffCount: part.staffCount,
          measures: sub,
        ),
      ],
    ),
    startQ: starts.isEmpty ? const Rational(0, 1) : starts[begin],
    endQ: end == measures.length ? totalEnd : starts[end],
    index: index,
    total: total,
  );
}
