import '../score_document.dart';

/// 谱式转换结果：新曲谱 + 转换警告（音域移位、声部取舍等）。
class ConvertResult {
  ConvertResult({required this.document, this.warnings = const []});

  final ScoreDocument document;
  final List<String> warnings;
}
