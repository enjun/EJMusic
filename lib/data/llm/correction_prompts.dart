import 'prompts.dart';

/// AI 纠错（校对模式）Prompt：复用识别 schema 契约，追加校对规则。
class CorrectionPrompts {
  /// System = 识别规则原文 + 校对模式补充（同一 schema 保证可解析）。
  static String system(String kind) {
    final sb = StringBuffer(Prompts.system(kind));
    sb.writeln();
    sb.writeln('【校对模式】这次你收到的不是空白乐谱，而是已识别的曲谱 JSON 切片'
        '（对应图片中的同一页）。切片可能存在识别错误：音高/八度错误、升降号错误、'
        '时值错误、多音/漏音、音符与休止混淆、连音线错误等。');
    sb.writeln('校对规则：');
    sb.writeln('A. 逐小节对照图片核对，只修正与图片不符之处；与图片一致的内容必须原样保留，不要重排、不要美化、不要改变记谱习惯。');
    sb.writeln('B. 输出与输入完全相同 schema、相同小节数量、相同小节号的完整 JSON（measures 数组长度必须与输入一致）。');
    sb.writeln('C. 不要修改 title/作曲者/调号/拍号/速度等元信息（除非图片明确显示与 JSON 不符）。');
    sb.writeln('D. 如果切片中标注了"来自上一页/下一页、必须原样保留"的事件，这些事件不在本页图片范围内，禁止修改它们。');
    sb.writeln('E. 实在没有把握的地方保持原样，不要凭猜测改动。');
    return sb.toString();
  }

  /// User：当前切片 JSON + 上下文 + 跨页边界提示 + 回喂。
  static String user({
    required int pageIndex,
    required String kind,
    required String sliceJson,
    String? carryInJson,
    String? boundaryHint,
    List<String>? repairFeedback,
    String? previousAttemptJson,
  }) {
    final sb = StringBuffer();
    sb.write('这是第 $pageIndex 页的${kind == 'guitar' ? '吉他' : '钢琴'}谱图片，'
        '以及该页对应的当前曲谱 JSON 切片。');
    if (carryInJson != null) {
      sb.write('切片前一个小节的 JSON 如下（仅供上下文参考，禁止输出它）：');
      sb.write(carryInJson);
      sb.write('。');
    }
    if (boundaryHint != null) {
      sb.write('\n');
      sb.write(boundaryHint);
    }
    sb.write('\n当前曲谱 JSON 切片：');
    sb.write(sliceJson);
    sb.write('\n请对照图片校对上述切片，输出修正后的完整 JSON'
        '（相同小节数、相同小节号）。');
    if (repairFeedback != null && repairFeedback.isNotEmpty) {
      sb.write('\n\n你上一次的输出未通过校验，问题如下：');
      for (final e in repairFeedback) {
        sb.write('\n- $e');
      }
      if (previousAttemptJson != null) {
        sb.write('\n上一次输出：$previousAttemptJson');
      }
      sb.write('\n请修正以上问题后重新输出完整 JSON。');
    }
    return sb.toString();
  }

  /// 跨页小节提示：列出本页不可修改的事件区间（含上一页头部与下一页尾部）。
  static String boundaryHint({
    required List<BoundaryRestriction> restrictions,
  }) {
    final sb = StringBuffer('跨页小节说明（必须严格遵守）：\n');
    for (final r in restrictions) {
      sb.write('- 第 ${r.measureNumber} 小节'
          '${r.tail ? '（其尾部事件属于下一页）' : '（其头部事件来自上一页）'}：');
      sb.write(r.descriptions.join('；'));
      sb.write('。这些事件禁止修改，只核对其余部分。\n');
    }
    return sb.toString();
  }
}

/// 一条跨页限制（某小节内某些声部的某些事件不可修改）。
class BoundaryRestriction {
  BoundaryRestriction({
    required this.measureNumber,
    required this.tail,
    required this.descriptions,
  });

  final int measureNumber;
  final bool tail; // true=尾部属于下一页
  final List<String> descriptions;
}
