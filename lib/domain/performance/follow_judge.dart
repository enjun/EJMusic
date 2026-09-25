import '../score/convert/to_event_timeline.dart';

/// 演奏模式：跟弹（self-paced，按对才推进）/ 聆听（自动播放，只反馈对错）。
enum FollowMode { followAlong, listen }

enum JudgePhase { idle, awaiting, done }

/// 单次按键的判定反馈。
class JudgeFeedback {
  const JudgeFeedback({
    required this.correct,
    required this.chordCompleted,
    required this.remaining,
  });

  final bool correct;

  /// 本和弦是否已全部按对（跟弹模式下触发推进）。
  final bool chordCompleted;

  /// 还剩哪些音未按对。
  final Set<int> remaining;
}

/// 跟弹判定状态机（纯逻辑，无 IO/依赖 flutter）。
///
/// Idle → start() → Awaiting{expected=当前和弦} →（按对全部音）→ 下一和弦
/// → 全曲完成 → Done。
class FollowJudge {
  FollowJudge({required this.notes, this.mode = FollowMode.followAlong});

  final List<TimelineNote> notes;
  FollowMode mode;

  JudgePhase phase = JudgePhase.idle;
  int noteIndex = -1;

  /// 当前期望按下的音集合。
  Set<int> expected = {};

  /// 已按对的音。
  final Set<int> satisfied = {};

  int correctCount = 0;
  int wrongCount = 0;

  bool get isDone => phase == JudgePhase.done;

  /// 当前音符（无则 null）。
  TimelineNote? get current =>
      noteIndex >= 0 && noteIndex < notes.length ? notes[noteIndex] : null;

  /// 开始（从第一个发音点起）。
  void start() {
    correctCount = 0;
    wrongCount = 0;
    satisfied.clear();
    phase = JudgePhase.awaiting;
    _syncTo(0);
  }

  void reset() {
    phase = JudgePhase.idle;
    noteIndex = -1;
    expected = {};
    satisfied.clear();
  }

  /// 聆听模式：由播放引擎驱动位置同步。
  /// 跟弹模式不要调用（位置由 [pressKey] 推进）。
  void syncTo(int index) {
    if (mode != FollowMode.listen) return;
    if (index == noteIndex) return;
    if (index < 0) return; // 引擎复位事件
    phase = index >= notes.length ? JudgePhase.done : JudgePhase.awaiting;
    _syncTo(index);
  }

  void _syncTo(int index) {
    noteIndex = index;
    satisfied.clear();
    if (index >= notes.length) {
      phase = JudgePhase.done;
      expected = {};
      return;
    }
    expected = {...notes[index].midis};
    if (expected.isEmpty) {
      // 休止点：自动跳到下一个发音点
      _syncTo(index + 1);
    }
  }

  /// 跟弹推进到下一个发音点。
  void advance() => _syncTo(noteIndex + 1);

  /// 用户按下一个琴键。
  JudgeFeedback pressKey(int midi) {
    if (phase != JudgePhase.awaiting || expected.isEmpty) {
      return JudgeFeedback(correct: false, chordCompleted: false, remaining: {});
    }
    if (expected.contains(midi) && !satisfied.contains(midi)) {
      satisfied.add(midi);
      correctCount++;
      final completed = satisfied.length == expected.length;
      if (completed && mode == FollowMode.followAlong) {
        advance();
      }
      return JudgeFeedback(
        correct: true,
        chordCompleted: completed,
        remaining: {...expected}..removeAll(satisfied),
      );
    }
    wrongCount++;
    return JudgeFeedback(
      correct: false,
      chordCompleted: false,
      remaining: {...expected}..removeAll(satisfied),
    );
  }

  /// 当前得分（正确按键数 / 总期望按键数）。
  double get accuracy {
    final total = correctCount + wrongCount;
    return total == 0 ? 1.0 : correctCount / total;
  }
}
