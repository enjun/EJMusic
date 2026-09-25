import 'package:ejmusic/core/util/rational.dart';
import 'package:ejmusic/domain/performance/follow_judge.dart';
import 'package:ejmusic/domain/score/convert/to_event_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

TimelineNote _note(int startQ, List<int> midis) => TimelineNote(
      startQ: Rational(startQ, 1),
      durQ: const Rational(1, 1),
      midis: midis,
      originalStartQ: Rational(startQ, 1),
      measureNumber: 1,
    );

void main() {
  test('跟弹：按对和弦推进，错键计数', () {
    final judge = FollowJudge(
      notes: [_note(0, [60]), _note(1, [64, 67]), _note(2, [72])],
      mode: FollowMode.followAlong,
    );
    judge.start();
    expect(judge.phase, JudgePhase.awaiting);
    expect(judge.expected, {60});

    // 错键
    final wrong = judge.pressKey(62);
    expect(wrong.correct, isFalse);
    expect(judge.wrongCount, 1);
    expect(judge.noteIndex, 0);

    // 对键 → 推进
    expect(judge.pressKey(60).chordCompleted, isTrue);
    expect(judge.noteIndex, 1);
    expect(judge.expected, {64, 67});

    // 和弦按一半
    final half = judge.pressKey(64);
    expect(half.correct, isTrue);
    expect(half.chordCompleted, isFalse);
    expect(half.remaining, {67});

    expect(judge.pressKey(67).chordCompleted, isTrue);
    expect(judge.noteIndex, 2);

    expect(judge.pressKey(72).chordCompleted, isTrue);
    expect(judge.phase, JudgePhase.done);
    expect(judge.correctCount, 4);
    expect(judge.accuracy, closeTo(4 / 5, 1e-9));
  });

  test('跟弹：休止点自动跳过', () {
    final judge = FollowJudge(
      notes: [_note(0, [60]), _note(1, const []), _note(2, [67])],
      mode: FollowMode.followAlong,
    );
    judge.start();
    expect(judge.noteIndex, 0);
    judge.pressKey(60);
    // 推进经过休止直达发音点
    expect(judge.noteIndex, 2);
    expect(judge.expected, {67});
  });

  test('聆听模式：syncTo 同步但不推进', () {
    final judge = FollowJudge(
      notes: [_note(0, [60]), _note(1, [67])],
      mode: FollowMode.listen,
    );
    judge.start();
    expect(judge.noteIndex, 0);
    judge.pressKey(60); // 聆听模式下按对也不推进
    expect(judge.noteIndex, 0);

    judge.syncTo(1);
    expect(judge.noteIndex, 1);
    expect(judge.expected, {67});

    judge.syncTo(-1); // 引擎复位：忽略
    expect(judge.noteIndex, 1);

    judge.syncTo(99);
    expect(judge.phase, JudgePhase.done);
  });

  test('未 start 时按键不判定', () {
    final judge = FollowJudge(notes: [_note(0, [60])]);
    final fb = judge.pressKey(60);
    expect(fb.correct, isFalse);
    expect(judge.phase, JudgePhase.idle);
  });
}
