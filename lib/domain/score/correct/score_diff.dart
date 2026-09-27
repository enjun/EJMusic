import 'dart:convert';

import '../../../core/util/rational.dart';
import '../merge/page_merger.dart';
import '../score_document.dart';

/// 纠错改动类型。
enum ScoreChangeKind {
  modifyAttributes, // 小节属性（调号/拍号/反复等）
  modifyEvent, // 单事件修改
  rewriteVoice, // 整声部重写（事件数变化或差异过多时折叠）
  addVoice, // 新增声部
  removeVoice, // 删除声部
}

/// 一处纠错改动。载荷字段在 diff 时深拷贝，apply 时写回目标谱。
class ScoreChange {
  ScoreChange({
    required this.page,
    required this.measureIndex,
    required this.measureNumber,
    required this.kind,
    this.staff = 0,
    this.voiceNo,
    this.eventIndex,
    this.before = '',
    this.after = '',
    required this.description,
    this.event,
    this.events,
    this.attributes,
    this.selected = true,
  });

  final int page;
  final int measureIndex; // 0 基，apply 定位用
  final int measureNumber; // 显示用（合并谱中已重编号，= measureIndex+1）
  final ScoreChangeKind kind;
  final int staff; // attributes 改动时为 0
  final int? voiceNo;
  final int? eventIndex; // modifyEvent 用
  final String before;
  final String after;
  final String description;
  final ScoreEvent? event; // modifyEvent 的新事件
  final List<ScoreEvent>? events; // rewriteVoice/addVoice
  final MeasureAttributes? attributes; // modifyAttributes
  bool selected;
}

/// 事件紧凑文本（domain 层不能反向依赖编辑器的 eventLabel，此处内联）。
String eventBrief(ScoreEvent e) {
  final d = e.dur.reduced();
  final dur = d.denominator == 1 ? '${d.numerator}' : '${d.numerator}/${d.denominator}';
  if (e.isRest) return '休止$dur';
  final pitches = e.pitches.isEmpty
      ? '?'
      : e.pitches.map((p) {
          final alter = p.alter == 0
              ? ''
              : (p.alter > 0 ? '#' * p.alter : 'b' * (-p.alter));
          return '${p.step}$alter${p.octave}';
        }).join('+');
  final tie = e.tie == null ? '' : '~';
  return '$pitches$tie $dur';
}

String _voiceLabel(int staff) =>
    staff == 1 ? '右手' : staff == 2 ? '左手' : '谱表$staff';

/// 比较 LLM 修正切片与原切片，产出可应用的改动清单与守卫告警。
/// 跨页小节（boundary）中不属于本页的事件区间必须与原切片逐事件一致，
/// 否则该小节的全部改动丢弃（LLM 改写了它图片范围外的内容，不可信）。
({List<ScoreChange> changes, List<String> warnings}) diffSlice({
  required ScoreDocument original,
  required ScoreDocument corrected,
  required PageSliceSpec spec,
  required int page,
}) {
  final changes = <ScoreChange>[];
  final warnings = <String>[];
  final origMeasures = original.parts.first.measures;
  final corrMeasures = corrected.parts.first.measures;

  for (final ms in spec.measures) {
    final mi = ms.measureIndex;
    if (mi >= origMeasures.length || mi >= corrMeasures.length) continue;
    final om = origMeasures[mi];
    final cm = corrMeasures[mi];

    // 跨页守卫：不拥有的事件必须原样保留
    if (ms.boundary && !_unownedIntact(om, cm, ms)) {
      warnings.add('第 ${mi + 1} 小节：跨页部分被改动，为安全起见已跳过'
          '（请在编辑器中手动核对）');
      continue;
    }

    // 小节属性：跨页小节的属性归头部（创建页），非创建页不改
    final attrChanged = _attrJson(om.attributes) != _attrJson(cm.attributes);
    if (attrChanged) {
      if (ms.boundary) {
        warnings.add('第 ${mi + 1} 小节：跨页小节属性被改动，已跳过');
      } else {
        changes.add(ScoreChange(
          page: page,
          measureIndex: mi,
          measureNumber: mi + 1,
          kind: ScoreChangeKind.modifyAttributes,
          description: '第 ${mi + 1} 小节 属性修改',
          attributes: cm.attributes == null
              ? null
              : MeasureAttributes.fromJson(cm.attributes!.toJson()),
        ));
      }
    }

    // 声部级比较
    final omVoices = {for (final v in om.voices) '${v.staff}:${v.voiceNo}': v};
    final cmVoices = {for (final v in cm.voices) '${v.staff}:${v.voiceNo}': v};
    final keys = <String>{...omVoices.keys, ...cmVoices.keys};
    for (final key in keys) {
      final parts = key.split(':');
      final staff = int.parse(parts[0]);
      final voiceNo = int.parse(parts[1]);
      final ov = omVoices[key];
      final cv = cmVoices[key];
      final label = '$_voiceLabel(staff$staff${voiceNo == 1 ? '' : '/v$voiceNo'})';

      if (ov == null && cv != null) {
        if (ms.boundary && ms.ownedRanges[key] == null) {
          warnings.add('第 ${mi + 1} 小节：$label 声部不属于本页，新增被跳过');
          continue;
        }
        changes.add(ScoreChange(
          page: page,
          measureIndex: mi,
          measureNumber: mi + 1,
          staff: staff,
          voiceNo: voiceNo,
          kind: ScoreChangeKind.addVoice,
          description: '第 ${mi + 1} 小节 $label：新增声部'
              '（${cv.events.length} 个事件）',
          events: _cloneEvents(cv.events),
        ));
        continue;
      }
      if (ov != null && cv == null) {
        changes.add(ScoreChange(
          page: page,
          measureIndex: mi,
          measureNumber: mi + 1,
          staff: staff,
          voiceNo: voiceNo,
          kind: ScoreChangeKind.removeVoice,
          before: _eventsBrief(ov.events),
          description: '第 ${mi + 1} 小节 $label：删除声部',
        ));
        continue;
      }
      if (ov == null || cv == null) continue;

      final voiceChanges = _diffVoice(
        page: page,
        measureIndex: mi,
        staff: staff,
        voiceNo: voiceNo,
        label: label,
        ov: ov,
        cv: cv,
        ownedOnly: ms.boundary,
        ownedRanges: ms.ownedRanges[key],
      );
      changes.addAll(voiceChanges);
    }
  }
  return (changes: changes, warnings: warnings);
}

List<ScoreChange> _diffVoice({
  required int page,
  required int measureIndex,
  required int staff,
  required int voiceNo,
  required String label,
  required ScoreVoice ov,
  required ScoreVoice cv,
  required bool ownedOnly,
  required List<(int, int)>? ownedRanges,
}) {
  bool owned(int i) =>
      !ownedOnly ||
      (ownedRanges?.any((r) => i >= r.$1 && i < r.$2) ?? false);

  if (ov.events.length == cv.events.length) {
    final diffs = <ScoreChange>[];
    for (var i = 0; i < ov.events.length; i++) {
      if (!owned(i)) continue;
      if (jsonEncode(ov.events[i].toJson()) ==
          jsonEncode(cv.events[i].toJson())) {
        continue;
      }
      diffs.add(ScoreChange(
        page: page,
        measureIndex: measureIndex,
        measureNumber: measureIndex + 1,
        staff: staff,
        voiceNo: voiceNo,
        eventIndex: i,
        kind: ScoreChangeKind.modifyEvent,
        before: eventBrief(ov.events[i]),
        after: eventBrief(cv.events[i]),
        description:
            '第 ${measureIndex + 1} 小节 $label：${eventBrief(ov.events[i])}'
            ' → ${eventBrief(cv.events[i])}',
        event: ScoreEvent.fromJson(cv.events[i].toJson()),
      ));
    }
    // 差异过多时折叠为整声部重写，避免清单爆炸
    if (diffs.length > 8) {
      return [
        ScoreChange(
          page: page,
          measureIndex: measureIndex,
          measureNumber: measureIndex + 1,
          staff: staff,
          voiceNo: voiceNo,
          kind: ScoreChangeKind.rewriteVoice,
          before: _eventsBrief(ov.events),
          after: _eventsBrief(cv.events),
          description: '第 ${measureIndex + 1} 小节 $label：整声部重写'
              '（${diffs.length} 处修改）',
          events: _cloneEvents(cv.events),
        ),
      ];
    }
    return diffs;
  }

  // 事件数不同：整声部替换
  if (ownedOnly) {
    // 边界小节：未拥有区间已由守卫保证一致，只替换拥有区间内的事件
    final merged = _cloneEvents(ov.events);
    var replaced = 0;
    for (var i = 0; i < merged.length && i < cv.events.length; i++) {
      if (owned(i) &&
          jsonEncode(merged[i].toJson()) != jsonEncode(cv.events[i].toJson())) {
        merged[i] = ScoreEvent.fromJson(cv.events[i].toJson());
        replaced++;
      }
    }
    if (replaced == 0) return const [];
    return [
      ScoreChange(
        page: page,
        measureIndex: measureIndex,
        measureNumber: measureIndex + 1,
        staff: staff,
        voiceNo: voiceNo,
        kind: ScoreChangeKind.rewriteVoice,
        before: _eventsBrief(ov.events),
        after: _eventsBrief(cv.events),
        description: '第 ${measureIndex + 1} 小节 $label：事件数变化，'
            '整声部按修正结果重写（本页范围内）',
        events: merged,
      ),
    ];
  }
  return [
    ScoreChange(
      page: page,
      measureIndex: measureIndex,
      measureNumber: measureIndex + 1,
      staff: staff,
      voiceNo: voiceNo,
      kind: ScoreChangeKind.rewriteVoice,
      before: _eventsBrief(ov.events),
      after: _eventsBrief(cv.events),
      description: '第 ${measureIndex + 1} 小节 $label：事件数变化'
          '（${ov.events.length} → ${cv.events.length}），整声部重写',
      events: _cloneEvents(cv.events),
    ),
  ];
}

/// 跨页守卫：corrected 中不归本页区间的事件必须与 original 全等。
bool _unownedIntact(ScoreMeasure om, ScoreMeasure cm, MeasureSliceSpec ms) {
  final omVoices = {for (final v in om.voices) '${v.staff}:${v.voiceNo}': v};
  final cmVoices = {for (final v in cm.voices) '${v.staff}:${v.voiceNo}': v};
  for (final entry in omVoices.entries) {
    final key = entry.key;
    final cv = cmVoices[key];
    if (cv == null) return false; // 本页不拥有却整声部消失
    final ranges = ms.ownedRanges[key];
    final ov = entry.value;
    if (ov.events.length != cv.events.length) {
      // 长度变化只允许发生在拥有区间内（尾部）
      if (ranges == null) return false;
      final lastOwned = ranges.map((r) => r.$2).reduce((a, b) => a > b ? a : b);
      if (lastOwned < ov.events.length) return false;
      if (cv.events.length < ov.events.length) return false;
    }
    for (var i = 0; i < ov.events.length; i++) {
      final owned = ranges?.any((r) => i >= r.$1 && i < r.$2) ?? false;
      if (owned) continue;
      if (jsonEncode(ov.events[i].toJson()) !=
          jsonEncode(cv.events[i].toJson())) {
        return false;
      }
    }
  }
  // corrected 新增的声部若不属于本页 → 不可信
  for (final key in cmVoices.keys) {
    if (!omVoices.containsKey(key) && ms.ownedRanges[key] == null) {
      return false;
    }
  }
  return true;
}

String _attrJson(MeasureAttributes? a) => jsonEncode(a?.toJson() ?? {});

List<ScoreEvent> _cloneEvents(List<ScoreEvent> events) => [
      for (final e in events) ScoreEvent.fromJson(e.toJson()),
    ];

String _eventsBrief(List<ScoreEvent> events, [int max = 6]) {
  final parts = [
    for (final e in events.take(max)) eventBrief(e),
  ];
  if (events.length > max) parts.add('…');
  return parts.join('、');
}

/// 把改动清单就地应用到曲谱（深拷贝载荷，避免与 probe 共享引用）。
void applyChanges(ScoreDocument doc, List<ScoreChange> changes) {
  final measures = doc.parts.first.measures;
  for (final c in changes) {
    if (!c.selected) continue;
    if (c.measureIndex < 0 || c.measureIndex >= measures.length) continue;
    final m = measures[c.measureIndex];
    switch (c.kind) {
      case ScoreChangeKind.modifyAttributes:
        m.attributes = c.attributes == null
            ? null
            : MeasureAttributes.fromJson(c.attributes!.toJson());
      case ScoreChangeKind.modifyEvent:
        final v = _findVoice(m, c.staff, c.voiceNo);
        final idx = c.eventIndex;
        if (v != null && idx != null && idx < v.events.length) {
          v.events[idx] = ScoreEvent.fromJson(c.event!.toJson());
        }
      case ScoreChangeKind.rewriteVoice:
        final v = _findVoice(m, c.staff, c.voiceNo);
        if (v != null && c.events != null) {
          v.events
            ..clear()
            ..addAll(_cloneEvents(c.events!));
        }
      case ScoreChangeKind.addVoice:
        if (c.events != null) {
          m.voices.add(ScoreVoice(
            staff: c.staff,
            voiceNo: c.voiceNo ?? 1,
            events: _cloneEvents(c.events!),
          ));
        }
      case ScoreChangeKind.removeVoice:
        m.voices.removeWhere(
            (v) => v.staff == c.staff && v.voiceNo == (c.voiceNo ?? 1));
    }
  }
}

ScoreVoice? _findVoice(ScoreMeasure m, int staff, int? voiceNo) {
  final vn = voiceNo ?? 1;
  for (final v in m.voices) {
    if (v.staff == staff && v.voiceNo == vn) return v;
  }
  return null;
}

/// 时值显示（分数文本，附点补充说明）。
String durText(Rational dur) {
  final d = dur.reduced();
  return d.denominator == 1 ? '${d.numerator}' : '${d.numerator}/${d.denominator}';
}
