/// LLM Prompt 构建（页面片段 JSON Schema 规则 + carry-in 上下文）。
class Prompts {
  /// System：曲谱识别规则。kind = piano | guitar。
  static String system(String kind) {
    final sb = StringBuffer();
    sb.writeln('你是一个专业的乐谱数字化引擎。用户会给你一张扫描的${kind == 'guitar' ? '吉他' : '钢琴'}谱图片，'
        '你必须输出严格的 JSON（不要 markdown 代码块、不要解释文字）。');
    sb.writeln();
    sb.writeln('输出顶层结构：');
    sb.writeln(r'''{
  "page": <页码，从 1 开始>,
  "title": "<曲名，页面上没有则 null>",
  "composer": "<作曲者，没有则 null>",
  "keyFifths": <五度圈调号 -7..7，C大调=0>,
  "keyMode": "major" | "minor",
  "timeBeats": <每小节拍数，如 4>,
  "timeBeatType": <以几分音符为一拍，如 4>,
  "bpm": <速度，没有标记则估计>,
  "pickup": <是否弱起小节 true/false>,
  "measures": [...],
  "warnings": ["<识别不确定的地方>"]
}''');
    sb.writeln();
    sb.writeln('measures 元素结构：');
    sb.writeln(r'''{
  "number": <小节号>,
  "cont": <仅当本小节是上一页末尾被截断小节的延续时为 true>,
  "attributes": { "keyFifths":0, "time":{"beats":4,"beatType":4}, "tempo":{"bpm":88},
                  "repeat":{"start":true,"end":false,"times":2}, "volta":{"no":1,"of":2} },
  "voices": [
    {"staff": 1, "events": [...]},   // staff 1 = 高音谱表（钢琴右手/吉他主旋律）
    {"staff": 2, "events": [...]}    // staff 2 = 低音谱表（钢琴左手；吉他谱省略）
  ]
}''');
    sb.writeln();
    sb.writeln('events 元素（音符或休止）：');
    sb.writeln(r'''{"type":"note", "dur":{"n":1,"d":1}, "dots":0,
 "pitches":[{"step":"C","alter":0,"octave":4,"finger":1}],
 "tie":"start|stop|continue", "tuplet":{"actual":3,"normal":2}}''');
    sb.writeln(r'''{"type":"rest", "dur":{"n":1,"d":1}, "dots":0}''');
    sb.writeln();
    sb.writeln('规则（必须严格遵守）：');
    sb.writeln('1. dur 是精确分数，单位=四分音符：四分=1/1，二分=2/1，八分=1/2，十六分=1/4，附点四分=3/2，三连音八分=1/3。');
    sb.writeln('2. 每个 voice 内一个小节所有 events 的 dur 之和必须等于拍号总时值（4/4 拍=4；3/4 拍=3；6/8 拍=3，因为 6/8 以附点四分为一拍即 6×1/2=3）。弱起小节（pickup=true 的第一小节）除外。');
    sb.writeln('3. 音高：step 用 CDEFGAB，alter -1/0/1，octave 用科学记谱（中央 C=C4）。');
    sb.writeln('4. 和弦（同时演奏的音）放进同一个 event 的 pitches 数组。');
    sb.writeln('5. 连音线 tie：跨小节/跨页延音，本音标 "start"，下一个相同音高的音标 "stop"，中间延续标 "continue"。必须成对。');
    if (kind == 'guitar') {
      sb.writeln('6. 吉他谱：每个 pitch 必须带 "tab":{"string":<1-6>,"fret":<0-14>}。string 1=最细弦（高音E），6=最粗弦（低音E）。品 0=空弦。');
    } else {
      sb.writeln('6. 钢琴谱：staff 1 放右手（高音谱表），staff 2 放左手（低音谱表）。');
    }
    sb.writeln('7. 反复记号：前反复记号所在小节 attributes.repeat.start=true；后反复记号所在小节 repeat.end=true；第一/第二结尾 volta。');
    sb.writeln('8. 看不清或不确定的音，宁可用 rest 并写进 warnings，也不要编造。');
    sb.writeln('9. 只输出 JSON 本身。');
    return sb.toString();
  }

  /// User：carry-in 上下文（上一页最后 ≤2 小节的 JSON）+ 指令。
  static String user({
    required int pageIndex,
    required String kind,
    String? carryInJson,
    List<String>? repairFeedback,
    String? previousAttemptJson,
  }) {
    final sb = StringBuffer();
    sb.write('这是第 $pageIndex 页的${kind == 'guitar' ? '吉他' : '钢琴'}谱图片。');
    if (carryInJson != null) {
      sb.write('上一页最后的小节 JSON 如下（仅供上下文衔接，不要重复输出它们）：');
      sb.write(carryInJson);
      sb.write(' 如果本页第一小节是上一页末尾小节的延续，把该小节标为 cont:true 并只输出延续部分的音符。');
    }
    sb.write('请按系统规则输出这一页的 JSON。');
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
}
