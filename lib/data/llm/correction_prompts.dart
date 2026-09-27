import 'prompts.dart';

/// AI 纠错（盲重新识别模式）Prompt。
///
/// 不把当前曲谱 JSON 给模型（避免自我确认偏置：模型倾向于确认自己
/// 之前的识别输出），而是让它对每页原图做独立全新识别，由本地
/// diffSlice 与当前谱比对产出修改候选。
class CorrectionPrompts {
  /// System = 识别规则原文 + 独立识别强调（同一 schema 保证可解析）。
  static String system(String kind) {
    final sb = StringBuffer(Prompts.system(kind));
    sb.writeln();
    sb.writeln('【独立识别模式】这是一次独立的全新识别，请把这张图片当作'
        '第一次见到，逐小节、逐音符仔细读谱。特别小心以下易错点：');
    sb.writeln('1. 音高与八度：符头的线间位置决定音高，高八度/低八度是最常见错误，'
        '务必根据谱号和谱表位置仔细判断每个音的 octave。');
    sb.writeln('2. 升降号与调号：先确认调号，再看临时升降号，别把调号内的升降遗漏。');
    sb.writeln('3. 附点、休止符与连线：附点改变时值；整小节休止与局部休止要区分；'
        '跨小节延音线意味着前一个音延长、不新起音。');
    sb.writeln('4. 和弦：同一符杆上的多个音是同一事件的多音，不要漏掉任何一个。');
    return sb.toString();
  }

  /// User：与制谱识别完全同构（图片 + 页号 + 上一页衔接上下文 + 回喂），
  /// 绝不携带当前曲谱内容。
  static String user({
    required int pageIndex,
    required String kind,
    String? carryInJson,
    List<String>? repairFeedback,
    String? previousAttemptJson,
  }) {
    return Prompts.user(
      pageIndex: pageIndex,
      kind: kind,
      carryInJson: carryInJson,
      repairFeedback: repairFeedback,
      previousAttemptJson: previousAttemptJson,
    );
  }
}
