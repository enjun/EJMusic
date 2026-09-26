import '../../../core/util/rational.dart';
import '../../../domain/score/score_document.dart';
import '../../../domain/score/score_validator.dart';
import '../../../data/score/score_store.dart';

const kStepNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

const kAlterNames = {-2: '重降', -1: '降', 0: '本位', 1: '升', 2: '重升'};

String alterSymbol(int alter) {
  switch (alter) {
    case -2:
      return 'bb';
    case -1:
      return 'b';
    case 1:
      return '#';
    case 2:
      return 'x';
    default:
      return '';
  }
}

/// 音名（C4 / F#3）；和弦返回 "C4+E4"。
String pitchLabel(ScorePitch p) =>
    '${p.step}${alterSymbol(p.alter)}${p.octave}';

/// 事件摘要（事件列表 chip 与编辑器标题共用）。
String eventLabel(ScoreEvent e) {
  final dur = '${e.dur.numerator}/${e.dur.denominator}';
  if (e.isRest) return '休止 $dur';
  final pitches = e.pitches.isEmpty ? '?' : e.pitches.map(pitchLabel).join('+');
  final tie = e.tie == null ? '' : '~';
  return '$pitches$tie $dur';
}

/// 常用时值预设（附点在事件上单独叠加）。
const kDurPresets = <String, Rational>{
  '全音符': Rational(4, 1),
  '二分音符': Rational(2, 1),
  '附点二分': Rational(3, 1),
  '四分音符': Rational(1, 1),
  '附点四分': Rational(3, 2),
  '八分音符': Rational(1, 2),
  '十六分音符': Rational(1, 4),
};

/// 保存编辑后的曲谱：校验+就地修复 → 落盘（score.json + MusicXML 缓存）。
/// 返回给用户看的警告/错误文案。
Future<({List<String> warnings, List<String> errors})> saveEditedScore({
  required ScoreStore store,
  required int songId,
  required ScoreDocument doc,
}) async {
  final validation = ScoreValidator.validateAndRepair(doc);
  await store.save(songId, doc);
  return (
    warnings: [...validation.repairs],
    errors: [for (final e in validation.errors) '${e.code}: ${e.message}'],
  );
}
