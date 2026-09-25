import '../score_document.dart';
import '../score_validator.dart';

/// 单页识别片段合并为完整曲谱。
/// - 按 page 顺序拼接 measures，重新编号
/// - cont 小节按 staff+voiceNo 拼接进前一小节（跨页断开的小节）
/// - meta 取首个非空片段；pageCount/imageNames 由调用方补充
class PageMerger {
  static MergeResult merge({
    required List<PageFragment> fragments,
    required String kind,
  }) {
    final warnings = <String>[];
    final frags = [...fragments]..sort((a, b) => a.page.compareTo(b.page));

    final mergedMeasures = <ScoreMeasure>[];
    ScoreMeta? firstMeta;

    for (final frag in frags) {
      if (frag.measures.isEmpty) {
        warnings.add('第 ${frag.page} 页没有识别到任何小节');
        continue;
      }
      firstMeta ??= _metaFromFragment(frag);
      for (final m in frag.measures) {
        if (m.cont && mergedMeasures.isNotEmpty) {
          final prev = mergedMeasures.last;
          _absorbContinuation(prev, m, warnings);
        } else {
          m.cont = false;
          mergedMeasures.add(m);
        }
      }
    }

    // 重编号
    for (var i = 0; i < mergedMeasures.length; i++) {
      mergedMeasures[i].number = i + 1;
    }

    final doc = ScoreDocument(
      kind: kind,
      meta: firstMeta ?? ScoreMeta(),
      parts: [
        ScorePart(
          instrument: kind,
          staffCount: kind == 'guitar' ? 1 : 2,
          measures: mergedMeasures,
        ),
      ],
    );
    if (mergedMeasures.isEmpty) {
      warnings.add('合并后没有任何小节');
    }
    return MergeResult(document: doc, warnings: warnings);
  }

  static ScoreMeta _metaFromFragment(PageFragment frag) => ScoreMeta(
        title: frag.title ?? '',
        composer: frag.composer,
        keyFifths: frag.keyFifths ?? 0,
        keyMode: frag.keyMode ?? 'major',
        timeBeats: frag.timeBeats ?? 4,
        timeBeatType: frag.timeBeatType ?? 4,
        bpm: frag.bpm ?? 88,
        pickup: frag.pickup ?? false,
      );

  /// 把 cont 小节的各 voice 事件拼进前一小节对应 voice。
  static void _absorbContinuation(
    ScoreMeasure prev,
    ScoreMeasure cont,
    List<String> warnings,
  ) {
    if (cont.attributes != null && !cont.attributes!.isEmpty) {
      warnings.add('小节承接（原编号 ${cont.number}）携带的属性被忽略');
    }
    for (final v in cont.voices) {
      final target = prev.voices.where((x) =>
          x.staff == v.staff && x.voiceNo == v.voiceNo).firstOrNull;
      if (target == null) {
        warnings.add('承接 voice(staff${v.staff}/v${v.voiceNo}) 在前一小节不存在，已追加');
        prev.voices.add(v);
      } else {
        target.events.addAll(v.events);
      }
    }
  }

  /// 片段级校验选项：首小节承接上页 / 末小节可能被下页承接。
  static ValidateOptions fragmentOptions(PageFragment frag, {required bool isLastPage}) {
    final firstContinues = frag.measures.isNotEmpty && frag.measures.first.cont;
    return ValidateOptions(
      firstContinues: firstContinues,
      lastContinues: !isLastPage,
      firstIsPickup: frag.pickup ?? false,
    );
  }
}

class MergeResult {
  MergeResult({required this.document, required this.warnings});

  final ScoreDocument document;
  final List<String> warnings;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final x in this) {
      return x;
    }
    return null;
  }
}
