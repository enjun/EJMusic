import '../../../core/db/database.dart';
import '../../../core/util/fuzzy.dart';
import '../../../core/util/phash.dart';
import 'import_scan.dart';

/// 阈值：曲名相似度达到此值才进入候选。
const titleSimilarityThreshold = 0.82;
/// 阈值：候选曲目的页面指纹匹配比例达到此值判定为重复。
const phashMatchRatioThreshold = 0.6;
/// pHash 汉明距离 ≤ 此值视为同一张图。
const phashHammingThreshold = 10;

/// 一首待导入曲子与库内某曲目的匹配结果。
class DedupeMatch {
  DedupeMatch({
    required this.existingSong,
    required this.titleRatio,
    required this.phashRatio,
    required this.matchedPages,
    required this.totalPages,
  });

  final Song existingSong;
  final double titleRatio;
  final double phashRatio;
  final int matchedPages;
  final int totalPages;

  bool get isDuplicate => titleRatio >= titleSimilarityThreshold && phashRatio >= phashMatchRatioThreshold;
}

/// 对一个分组执行库内去重比对。
Future<List<DedupeMatch>> checkGroupDuplication(
  AppDatabase db,
  String label,
  List<FileMeta> files,
) async {
  final labelNorm = normalizeTitle(label);
  if (labelNorm.isEmpty || files.isEmpty) return const [];

  final songs = await db.songsDao.allSongsForDedupe();
  final matches = <DedupeMatch>[];
  for (final song in songs) {
    final ratio = similarityRatio(labelNorm, song.titleNorm);
    if (ratio < titleSimilarityThreshold) continue;

    final pages = await db.songsDao.pagesOfSong(song.id);
    final hashes = pages.map((pg) => pg.phash).whereType<String>().toList();
    if (hashes.isEmpty) {
      matches.add(DedupeMatch(
        existingSong: song,
        titleRatio: ratio,
        phashRatio: 0,
        matchedPages: 0,
        totalPages: 0,
      ));
      continue;
    }

    var matched = 0;
    for (final file in files) {
      final hash = file.phash;
      if (hash == null) continue;
      final best = hashes
          .map((h) => hammingDistance(hash, h))
          .reduce((a, b) => a < b ? a : b);
      if (best <= phashHammingThreshold) matched++;
    }
    final phashRatio = files.isEmpty ? 0.0 : matched / files.length;
    matches.add(DedupeMatch(
      existingSong: song,
      titleRatio: ratio,
      phashRatio: phashRatio,
      matchedPages: matched,
      totalPages: files.length,
    ));
  }
  matches.sort((a, b) => b.phashRatio.compareTo(a.phashRatio));
  return matches;
}
