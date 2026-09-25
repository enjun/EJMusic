import '../../core/util/midi.dart';
import '../../core/util/rational.dart';
import 'score_document.dart';

class ValidationIssue {
  ValidationIssue({
    required this.code,
    required this.message,
    this.measureNumber,
    this.severity = 'error',
  });

  final String code;
  final String message;
  final int? measureNumber;
  final String severity; // error | warning

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (measureNumber != null) 'measure': measureNumber,
        'severity': severity,
      };
}

class ValidationResult {
  ValidationResult({required this.errors, required this.repairs});

  final List<ValidationIssue> errors; // 未修复的问题（触发 LLM 重试）
  final List<String> repairs; // 已自动修复的描述

  bool get ok => errors.isEmpty;
}

/// 校验选项：单页片段的首/末小节可能不完整（跨页延续），跳过拍数检查。
class ValidateOptions {
  const ValidateOptions({
    this.firstContinues = false,
    this.lastContinues = false,
    this.firstIsPickup = false,
  });

  final bool firstContinues;
  final bool lastContinues;
  final bool firstIsPickup;

  /// 完整曲谱（合并后）的校验选项。
  static const full = ValidateOptions();
}

/// 校验 + 就地修复。时值/音域/tab/tie/附点问题尽量自动修复；
/// 超拍（小节时长超出拍号）等结构性错误保留为 error。
class ScoreValidator {
  /// LLM 时值最小粒度：1/48 四分音符（覆盖 64 分音符与各类三连音）。
  static const snapDenominator = 48;

  static ValidationResult validateAndRepair(
    ScoreDocument doc, [
    ValidateOptions? options,
  ]) {
    final opts = options ??
        ValidateOptions(firstIsPickup: doc.meta.pickup);
    final errors = <ValidationIssue>[];
    final repairs = <String>[];
    if (doc.parts.isEmpty) {
      errors.add(ValidationIssue(code: 'no_parts', message: '曲谱没有任何声部'));
      return ValidationResult(errors: errors, repairs: repairs);
    }
    for (final part in doc.parts) {
      for (var i = 0; i < part.measures.length; i++) {
        final measure = part.measures[i];
        _snapAndFixDots(measure, repairs);
        _fixPitches(doc.kind, measure, errors, repairs);
      }
      _pairTies(part, repairs);
      _checkMeasureFill(doc, part, opts, errors, repairs);
    }
    if (doc.parts.first.measures.isEmpty) {
      errors.add(ValidationIssue(code: 'no_measures', message: '曲谱没有任何小节'));
    }
    return ValidationResult(errors: errors, repairs: repairs);
  }

  /// 时值吸附到 1/48 + 附点数与 dur 一致性修复。
  static void _snapAndFixDots(ScoreMeasure measure, List<String> repairs) {
    for (final voice in measure.voices) {
      for (final e in voice.events) {
        final r = e.dur.reduced();
        if (r.denominator > 1 && (snapDenominator % r.denominator) != 0) {
          final snapped = snapRational(r);
          repairs.add('小节${measure.number}: 时值 $r 吸附为 $snapped');
          e.dur = snapped;
        }
        if (noteTypeName(e.dur, e.dots) == null) {
          var fixed = -1;
          for (final d in [1, 2]) {
            if (noteTypeName(e.dur, d) != null) {
              fixed = d;
              break;
            }
          }
          if (fixed >= 0) {
            repairs.add('小节${measure.number}: 附点数 ${e.dots}→$fixed（与 dur=${e.dur} 匹配）');
            e.dots = fixed;
          } else if (e.dots > 0) {
            repairs.add('小节${measure.number}: 附点标记清除（dur=${e.dur} 非标准附点时值）');
            e.dots = 0;
          }
        }
      }
    }
  }

  /// 吸附到最近的 1/48 四分音符。
  static Rational snapRational(Rational r) {
    final n = (r.numerator * snapDenominator / r.denominator).round();
    if (n < 1) return const Rational(1, snapDenominator);
    return Rational(n, snapDenominator).reduced();
  }

  /// 音域与 tab 指位修复。
  static void _fixPitches(
    String kind,
    ScoreMeasure measure,
    List<ValidationIssue> errors,
    List<String> repairs,
  ) {
    for (final voice in measure.voices) {
      if (voice.staff < 1 || voice.staff > 2) {
        errors.add(ValidationIssue(
          code: 'bad_staff',
          message: 'staff 必须是 1 或 2，实际 ${voice.staff}',
          measureNumber: measure.number,
        ));
      }
      for (final e in voice.events) {
        if (e.isRest) {
          if (e.pitches.isNotEmpty) e.pitches = const [];
          continue;
        }
        if (e.pitches.isEmpty) {
          errors.add(ValidationIssue(
            code: 'note_without_pitch',
            message: '音符事件缺少 pitches',
            measureNumber: measure.number,
          ));
          continue;
        }
        for (final p in e.pitches) {
          if (kind == 'guitar') {
            _fixTab(measure, p, repairs);
          } else {
            _fixPianoRange(measure, p, repairs);
          }
        }
      }
    }
  }

  static void _fixPianoRange(ScoreMeasure measure, ScorePitch p, List<String> repairs) {
    var midi = pitchToMidi(p.step, p.alter, p.octave);
    while (midi < 21) {
      p.octave++;
      midi += 12;
      repairs.add('小节${measure.number}: 音低于钢琴音域，已升八度');
    }
    while (midi > 108) {
      p.octave--;
      midi -= 12;
      repairs.add('小节${measure.number}: 音高于钢琴音域，已降八度');
    }
  }

  static void _fixTab(ScoreMeasure measure, ScorePitch p, List<String> repairs) {
    if (p.tab != null) {
      final tab = p.tab!;
      if (tab.string < 1 || tab.string > 6) {
        repairs.add('小节${measure.number}: 弦号 ${tab.string} 超界，按音高重新推导指位');
        p.tab = null;
      } else if (tab.fret < 0 || tab.fret > 14) {
        final clamped = tab.fret.clamp(0, 14);
        repairs.add('小节${measure.number}: 品位 ${tab.fret}→$clamped');
        p.tab = TabPosition(string: tab.string, fret: clamped);
      }
      if (p.tab != null) {
        // tab 与音高不一致时以 tab 为准修正音高
        final midi = tabToMidi(p.tab!.string, p.tab!.fret);
        final (step, alter, octave) = midiToPitch(midi);
        if (step != p.step || alter != p.alter || octave != p.octave) {
          repairs.add('小节${measure.number}: 音高与 tab(${p.tab!.string}弦${p.tab!.fret}品)'
              ' 不符，以 tab 为准改为 $step$octave');
          p.step = step;
          p.alter = alter;
          p.octave = octave;
        }
        return;
      }
    }
    // 缺 tab：按音高推导（优先高弦低品）
    var midi = pitchToMidi(p.step, p.alter, p.octave);
    while (midi < guitarOpenStringMidi[5]) {
      midi += 12;
      p.octave++;
      repairs.add('小节${measure.number}: 音低于吉他音域，已升八度');
    }
    while (midi > guitarOpenStringMidi[0] + 14) {
      midi -= 12;
      p.octave--;
      repairs.add('小节${measure.number}: 音高于吉他常用音域，已降八度');
    }
    for (var s = 1; s <= 6; s++) {
      final fret = midi - guitarOpenStringMidi[s - 1];
      if (fret >= 0 && fret <= 14) {
        p.tab = TabPosition(string: s, fret: fret);
        return;
      }
    }
  }

  /// tie 配对：同 staff+voiceNo 逻辑声部内（可跨小节）start 必须有后续同音高 stop；
  /// 无法配对的标记移除。
  static void _pairTies(ScorePart part, List<String> repairs) {
    // key: staff*100+voiceNo → (midi → 未闭合 start 事件队列)
    final open = <int, Map<int, List<ScoreEvent>>>{};
    for (final m in part.measures) {
      for (final v in m.voices) {
        final voiceKey = v.staff * 100 + v.voiceNo;
        final byVoice = open.putIfAbsent(voiceKey, () => {});
        for (final e in v.events) {
          if (e.isRest || e.tie == null) continue;
          final midi = _eventMidi(e);
          if (midi == null) continue;
          if (e.tie == 'start') {
            byVoice.putIfAbsent(midi, () => []).add(e);
          } else if (e.tie == 'stop' || e.tie == 'continue') {
            final starts = byVoice[midi];
            if (starts == null || starts.isEmpty) {
              repairs.add('小节${m.number}: 孤立 tie=${e.tie}（${_eventLabel(e)}）已移除');
              e.tie = e.tie == 'continue' ? 'start' : null;
              if (e.tie == 'start') byVoice.putIfAbsent(midi, () => []).add(e);
            } else {
              starts.removeLast();
            }
          }
        }
      }
    }
    for (final byVoice in open.values) {
      for (final starts in byVoice.values) {
        for (final e in starts) {
          repairs.add('未闭合 tie=start（${_eventLabel(e)}）已移除');
          e.tie = null;
        }
      }
    }
  }

  static int? _eventMidi(ScoreEvent e) {
    if (e.pitches.isEmpty) return null;
    final p = e.pitches.first;
    return pitchToMidi(p.step, p.alter, p.octave);
  }

  static String _eventLabel(ScoreEvent e) {
    if (e.pitches.isEmpty) return '空';
    final p = e.pitches.first;
    return '${p.step}${p.alter > 0 ? '#' : ''}${p.octave}';
  }

  /// 小节拍数检查：欠拍补 rest（弱起/跨页延续豁免），超拍报 error。
  static void _checkMeasureFill(
    ScoreDocument doc,
    ScorePart part,
    ValidateOptions options,
    List<ValidationIssue> errors,
    List<String> repairs,
  ) {
    final measures = part.measures;
    var beats = Rational(doc.meta.timeBeats * 4, doc.meta.timeBeatType);
    for (var i = 0; i < measures.length; i++) {
      final m = measures[i];
      final a = m.attributes;
      if (a?.timeBeats != null && a?.timeBeatType != null) {
        beats = Rational(a!.timeBeats! * 4, a.timeBeatType!);
      }
      final isFirst = i == 0;
      final isLast = i == measures.length - 1;
      final pickupExempt = isFirst && options.firstIsPickup;
      final skipIfShort = (isFirst && options.firstContinues) ||
          (isLast && options.lastContinues) ||
          pickupExempt;

      if (m.voices.isEmpty) {
        repairs.add('小节${m.number}: 空小节补全小节休止');
        m.voices.add(ScoreVoice(
          staff: 1,
          events: [ScoreEvent(type: 'rest', dur: beats)],
        ));
        if (part.staffCount >= 2 && doc.kind == 'piano') {
          m.voices.add(ScoreVoice(
            staff: 2,
            events: [ScoreEvent(type: 'rest', dur: beats)],
          ));
        }
        continue;
      }
      for (final v in m.voices) {
        var sum = Rational.zero();
        for (final e in v.events) {
          sum += e.dur;
        }
        if (sum < beats) {
          if (skipIfShort) continue;
          repairs.add('小节${m.number}(staff${v.staff}): 欠拍 ${beats - sum}，补休止');
          v.events.add(ScoreEvent(type: 'rest', dur: (beats - sum).reduced()));
        } else if (sum > beats) {
          if (pickupExempt && isLast && options.lastContinues) continue;
          errors.add(ValidationIssue(
            code: 'measure_overfull',
            message: 'staff${v.staff} 时值合计 $sum 超过拍数 $beats',
            measureNumber: m.number,
          ));
        }
      }
    }
  }
}
