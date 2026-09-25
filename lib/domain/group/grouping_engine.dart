/// 目录图片按曲子自动分组：剥离文件名尾部的页码/序号后按前缀聚类。
library;

/// 一组待确认的曲子图片分组。
class ImageGroupDraft {
  ImageGroupDraft({required this.label, required this.files});

  /// 前缀（去掉页码后的文件名主体），作为默认曲名候选。
  String label;
  final List<String> files;
}

/// 将图片文件名列表（相对于目录或纯文件名均可）按前缀聚类。
///
/// [names] 无需预先排序，结果内部按自然序排列，分组顺序按首个文件的出现顺序。
List<ImageGroupDraft> groupByPrefix(Iterable<String> names) {
  final ordered = naturalSort(names.toList());
  final groups = <String, ImageGroupDraft>{};
  final order = <String>[];
  for (final name in ordered) {
    final prefix = extractPrefix(name);
    final group = groups.putIfAbsent(prefix, () {
      final g = ImageGroupDraft(label: prefix, files: []);
      order.add(prefix);
      return g;
    });
    group.files.add(name);
  }
  return [for (final p in order) groups[p]!];
}

/// 从文件名提取曲子前缀：去掉扩展名与尾部页码/序号模式。
String extractPrefix(String fileName) {
  var base = fileName;
  final dot = base.lastIndexOf('.');
  if (dot > 0) base = base.substring(0, dot);

  // 反复剥离尾部模式："(3)"、"（02）"、" _7 "、" - 12"、"第3页"、"page04"、"scan 5"
  var changed = true;
  while (changed) {
    changed = false;
    final m = _trailingPatterns.firstMatch(base);
    if (m != null && m.start > 0) {
      base = base.substring(0, m.start).trim();
      changed = true;
    }
  }
  base = _trimTrailingSeparators(base).trim();
  return base.isEmpty ? fileName : base;
}

final RegExp _trailingPatterns = RegExp(
  r'[\s_\-—·.]*[(（]?\d{1,4}[)）]?$'
  r'|[\s_\-—·.]*第\s*\d{1,4}\s*页$'
  r'|[\s_\-—·.]*\d{1,4}\s*页$'
  r'|[\s_\-—·.]+(?:page|scan|img|图片|p)\s*\d{1,4}$',
  caseSensitive: false,
);

String _trimTrailingSeparators(String s) {
  while (s.isNotEmpty && RegExp(r'[\s_\-—·.（(]').hasMatch(s[s.length - 1])) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 自然排序：数字段按数值比较，避免 img10.jpg 排在 img2.jpg 前。
List<String> naturalSort(List<String> input) {
  final list = [...input]..sort(_naturalCompare);
  return list;
}

int _naturalCompare(String a, String b) {
  var ia = 0;
  var ib = 0;
  while (ia < a.length && ib < b.length) {
    final ca = a[ia];
    final cb = b[ib];
    final digitA = _isDigit(ca);
    final digitB = _isDigit(cb);
    if (digitA && digitB) {
      var ja = ia;
      var jb = ib;
      while (ja < a.length && _isDigit(a[ja])) {
        ja++;
      }
      while (jb < b.length && _isDigit(b[jb])) {
        jb++;
      }
      final na = int.parse(a.substring(ia, ja));
      final nb = int.parse(b.substring(ib, jb));
      final cmp = na.compareTo(nb);
      if (cmp != 0) return cmp;
      ia = ja;
      ib = jb;
    } else {
      final cmp = ca.compareTo(cb);
      if (cmp != 0) return cmp;
      ia++;
      ib++;
    }
  }
  return (a.length - ia).compareTo(b.length - ib);
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
