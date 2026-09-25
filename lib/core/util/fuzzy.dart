/// 曲名归一化与模糊匹配，用于曲谱库去重。
library;

/// 归一化曲名：全角转半角、去空白与标点、转小写。
String normalizeTitle(String raw) {
  final sb = StringBuffer();
  for (final code in raw.runes) {
    var c = code;
    // 全角 ASCII 与空格 → 半角
    if (c == 0x3000) {
      c = 0x20;
    } else if (c >= 0xFF01 && c <= 0xFF5E) {
      c -= 0xFEE0;
    }
    final ch = String.fromCharCode(c);
    if (_isSeparator(c)) continue;
    sb.write(ch.toLowerCase());
  }
  return sb.toString();
}

bool _isSeparator(int c) {
  if (c <= 0x20) return true;
  // ASCII 标点
  if ((c >= 0x21 && c <= 0x2F) || (c >= 0x3A && c <= 0x40) || (c >= 0x5B && c <= 0x60) || (c >= 0x7B && c <= 0x7E)) {
    return true;
  }
  // CJK 标点与符号（。、《》【】·—…等）
  if (c >= 0x3000 && c <= 0x303F) return true;
  if (c == 0x00B7 || c == 0x2013 || c == 0x2014 || c == 0x2018 || c == 0x2019 || c == 0x201C || c == 0x201D || c == 0x2026) {
    return true;
  }
  return false;
}

/// 编辑距离（Levenshtein），基于两行动态规划。
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final aUnits = a.runes.toList();
  final bUnits = b.runes.toList();
  var prev = List<int>.generate(bUnits.length + 1, (i) => i);
  var curr = List<int>.filled(bUnits.length + 1, 0);
  for (var i = 1; i <= aUnits.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= bUnits.length; j++) {
      final cost = aUnits[i - 1] == bUnits[j - 1] ? 0 : 1;
      var best = prev[j] + 1; // 删除
      final insert = curr[j - 1] + 1; // 插入
      if (insert < best) best = insert;
      final subst = prev[j - 1] + cost; // 替换
      if (subst < best) best = subst;
      curr[j] = best;
    }
    final tmp = prev;
    prev = curr;
    curr = tmp; // 下一轮整体覆盖，无需清空
  }
  return prev[bUnits.length];
}

/// 相似度比率 [0,1]：1 - 编辑距离 / 较长串长度。
double similarityRatio(String a, String b) {
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1.0;
  return 1.0 - levenshtein(a, b) / maxLen;
}
