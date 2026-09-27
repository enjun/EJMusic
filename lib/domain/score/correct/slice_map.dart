import 'dart:convert';

import '../merge/page_merger.dart';
import '../score_document.dart';

/// 由存量页片段重新合并得到"页 → 合并小节"所有权规格，并校验与当前
/// 曲谱一致（手动编辑不增删小节，小节数相等即可保证 measureIndex 有效；
/// 小节内事件偏移的漂移由 diff 的跨页守卫兜底）。
/// 与当前 doc 不匹配时抛 StateError（文案可直接给用户）。
List<PageSliceSpec> loadSliceSpecs({
  required List<PageFragment> fragments,
  required ScoreDocument current,
  required String kind,
}) {
  if (fragments.isEmpty) {
    throw StateError('没有页识别片段，无法定位页与小节的对应关系'
        '（转换生成的曲谱暂不支持 AI 纠错）');
  }
  final merged = PageMerger.merge(fragments: fragments, kind: kind);
  final mergedLen = merged.document.parts.first.measures.length;
  final currentLen = current.parts.first.measures.length;
  if (mergedLen != currentLen) {
    throw StateError('页片段与当前曲谱小节数不一致（$mergedLen ≠ $currentLen），'
        '无法定位页与小节的对应关系，请重新制作曲谱');
  }
  return merged.slices;
}

/// 按页规格从当前曲谱切出单页文档（深拷贝，不与原谱共享任何子对象）。
/// 切片小节保留合并谱中的完整内容与编号；boundary 小节包含邻页的事件，
/// 由调用方通过 ownedRanges 在 prompt 与 diff 中限制可修改范围。
ScoreDocument buildSliceDocument(ScoreDocument doc, PageSliceSpec spec) {
  final measures = doc.parts.first.measures;
  final sliced = <ScoreMeasure>[];
  for (final ms in spec.measures) {
    final m = measures[ms.measureIndex];
    sliced.add(ScoreMeasure.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>));
  }
  return ScoreDocument(
    kind: doc.kind,
    meta: ScoreMeta.fromJson(jsonDecode(jsonEncode(doc.meta.toJson()))
        as Map<String, dynamic>),
    parts: [
      ScorePart(
        instrument: doc.parts.first.instrument,
        staffCount: doc.parts.first.staffCount,
        measures: sliced,
      ),
    ],
  );
}

/// 快照深拷贝（apply 前保留原始文档）。
ScoreDocument cloneDocument(ScoreDocument doc) => ScoreDocument.fromJson(
    jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>);
