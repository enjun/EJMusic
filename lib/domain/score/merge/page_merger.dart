import 'dart:convert';

import '../score_document.dart';
import '../score_validator.dart';

/// 某页对合并谱中一个小节的所有权规格（AI 纠错按页切片用）。
class MeasureSliceSpec {
  MeasureSliceSpec({required this.measureIndex, this.boundary = false});

  /// 在 part.measures 中的下标（0 基）。
  final int measureIndex;

  /// 跨页小节：多个页共同拥有这个小节的不同事件区间。
  bool boundary = false;

  /// voiceKey 'staff:voiceNo' → 本页拥有的事件区间列表 [start, end)。
  /// boundary=false 时为空（拥有整个小节）。
  final Map<String, List<(int, int)>> ownedRanges = {};

  /// 本页是否拥有该 voice 的 [index] 事件（boundary=false 恒 true）。
  bool owns(String voiceKey, int index) {
    if (!boundary) return true;
    final ranges = ownedRanges[voiceKey];
    if (ranges == null) return false;
    for (final (s, e) in ranges) {
      if (index >= s && index < e) return true;
    }
    return false;
  }
}

/// 一页拥有的合并小节切片规格（按小节在合并谱中出现的顺序）。
class PageSliceSpec {
  PageSliceSpec({required this.page});

  final int page;
  final List<MeasureSliceSpec> measures = [];

  MeasureSliceSpec? specFor(int measureIndex) {
    for (final m in measures) {
      if (m.measureIndex == measureIndex) return m;
    }
    return null;
  }
}

/// 单页识别片段合并为完整曲谱。
/// - 按 page 顺序拼接 measures，重新编号
/// - cont 小节按 staff+voiceNo 拼接进前一小节（跨页断开的小节）
/// - meta 取首个非空片段；pageCount/imageNames 由调用方补充
/// - 同时产出 slices：每页对合并小节（及跨页小节内事件区间）的所有权
class PageMerger {
  static MergeResult merge({
    required List<PageFragment> fragments,
    required String kind,
  }) {
    final warnings = <String>[];
    // 深拷贝：merge 会吸收/改写小节对象（cont 标记清零、事件追加），
    // 不能让调用方持有的 fragments/合并谱被二次 merge 污染
    final frags = (fragments.toList()
          ..sort((a, b) => a.page.compareTo(b.page)))
        .map((f) => PageFragment.fromJson(
            jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>))
        .toList();

    final mergedMeasures = <ScoreMeasure>[];
    final measureOwner = <int>[]; // 合并小节下标 → 创建页 page 号
    final slices = <int, PageSliceSpec>{};
    ScoreMeta? firstMeta;

    PageSliceSpec specOf(int page) =>
        slices.putIfAbsent(page, () => PageSliceSpec(page: page));

    for (final frag in frags) {
      if (frag.measures.isEmpty) {
        warnings.add('第 ${frag.page} 页没有识别到任何小节');
        continue;
      }
      firstMeta ??= _metaFromFragment(frag);
      final spec = specOf(frag.page);
      for (final m in frag.measures) {
        if (m.cont && mergedMeasures.isNotEmpty) {
          final prevIndex = mergedMeasures.length - 1;
          final prev = mergedMeasures[prevIndex];
          final ownerPage = measureOwner[prevIndex];
          _absorbContinuation(
            prev, m, warnings,
            pageIndex: frag.page,
            measureIndex: prevIndex,
            ownerPage: ownerPage,
            onOwn: (voiceKey, start, end) {
              // 本页拥有 [start, end)
              final self = spec.specFor(prevIndex) ??
                  () {
                    final s = MeasureSliceSpec(
                        measureIndex: prevIndex, boundary: true);
                    spec.measures.add(s);
                    return s;
                  }();
              self.boundary = true;
              final ranges = self.ownedRanges.putIfAbsent(voiceKey, () => []);
              if (ranges.isNotEmpty && ranges.last.$2 == start) {
                ranges[ranges.length - 1] = (ranges.last.$1, end);
              } else {
                ranges.add((start, end));
              }
            },
            onOwnerCap: (voiceKey, start) {
              // 创建页对小节头部的所有权封顶到 [0, start)。
              // 只在首次吸收时记录：链式 cont 的后续封顶 start 只会更大，
              // 创建页拥有的始终是最初的头部，不能跟着扩大
              final ownerSpec = specOf(ownerPage).specFor(prevIndex);
              if (ownerSpec == null) return;
              ownerSpec.boundary = true;
              final ranges = ownerSpec.ownedRanges.putIfAbsent(voiceKey, () => []);
              if (ranges.isEmpty) {
                ranges.add((0, start));
              }
            },
          );
        } else {
          m.cont = false;
          mergedMeasures.add(m);
          measureOwner.add(frag.page);
          spec.measures.add(MeasureSliceSpec(measureIndex: mergedMeasures.length - 1));
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
    final sliceList = [
      for (final page in slices.keys.toList()..sort()) slices[page]!,
    ];
    return MergeResult(
      document: doc,
      warnings: warnings,
      slices: sliceList,
    );
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

  /// 把 cont 小节的各 voice 事件拼进前一小节对应 voice，并记录事件所有权：
  /// cont 页拥有新追加的 [start, end) 区间，创建页的头部所有权封顶到 start。
  static void _absorbContinuation(
    ScoreMeasure prev,
    ScoreMeasure cont,
    List<String> warnings, {
    required int pageIndex,
    required int measureIndex,
    required int ownerPage,
    required void Function(String voiceKey, int start, int end) onOwn,
    required void Function(String voiceKey, int start) onOwnerCap,
  }) {
    if (cont.attributes != null && !cont.attributes!.isEmpty) {
      warnings.add('小节承接（原编号 ${cont.number}）携带的属性被忽略');
    }
    for (final v in cont.voices) {
      final key = '${v.staff}:${v.voiceNo}';
      final target = prev.voices.where((x) =>
          x.staff == v.staff && x.voiceNo == v.voiceNo).firstOrNull;
      if (target == null) {
        warnings.add('承接 voice(staff${v.staff}/v${v.voiceNo}) 在前一小节不存在，已追加');
        prev.voices.add(v);
        onOwn(key, 0, v.events.length);
      } else {
        final start = target.events.length;
        target.events.addAll(v.events);
        onOwn(key, start, target.events.length);
        onOwnerCap(key, start);
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
  MergeResult({
    required this.document,
    required this.warnings,
    this.slices = const [],
  });

  final ScoreDocument document;
  final List<String> warnings;

  /// 每页对合并小节的所有权规格（按页号排序），AI 纠错按页切片用。
  final List<PageSliceSpec> slices;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final x in this) {
      return x;
    }
    return null;
  }
}
