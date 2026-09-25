import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/score/convert/to_musicxml.dart';
import '../../domain/score/score_document.dart';

/// score.json / musicxml 缓存的文件存储。
/// 目录布局：{base}/scores/{songId}/score.json + score.musicxml
class ScoreStore {
  ScoreStore(this.baseDir);

  final String baseDir;

  String scorePath(int songId) =>
      p.join(baseDir, 'scores', songId.toString(), 'score.json');
  String musicXmlPath(int songId) =>
      p.join(baseDir, 'scores', songId.toString(), 'score.musicxml');

  Future<({String scorePath, String musicXmlPath})> save(
    int songId,
    ScoreDocument doc,
  ) async {
    final dir = Directory(p.dirname(scorePath(songId)));
    await dir.create(recursive: true);
    final sp = scorePath(songId);
    final xp = musicXmlPath(songId);
    await File(sp).writeAsString(jsonEncode(doc.toJson()), flush: true);
    await File(xp).writeAsString(scoreToMusicXml(doc), flush: true);
    return (scorePath: sp, musicXmlPath: xp);
  }

  Future<ScoreDocument?> load(int songId) async {
    final f = File(scorePath(songId));
    if (!await f.exists()) return null;
    return ScoreDocument.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  /// 逐页片段（断点续跑/单页重试）。
  String fragmentPath(int songId, int page) =>
      p.join(baseDir, 'scores', songId.toString(), 'pages', 'page_$page.json');

  Future<void> saveFragment(int songId, PageFragment frag) async {
    final f = File(fragmentPath(songId, frag.page));
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(frag.toJson()), flush: true);
  }

  /// 已识别成功的片段，按页序返回。
  Future<List<PageFragment>> loadFragments(int songId) async {
    final dir = Directory(p.dirname(fragmentPath(songId, 1)));
    if (!await dir.exists()) return const [];
    final files = <(int, File)>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = p.basenameWithoutExtension(e.path); // page_N
      final m = RegExp(r'^page_(\d+)$').firstMatch(name);
      if (m != null) files.add((int.parse(m.group(1)!), e));
    }
    files.sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final (_, f) in files)
        PageFragment.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>)
    ];
  }

  Future<void> deleteFragments(int songId) async {
    final dir = Directory(p.dirname(fragmentPath(songId, 1)));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
