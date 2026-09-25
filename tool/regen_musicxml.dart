// 开发辅助：用当前代码重新生成所有已有曲谱的 musicxml 缓存。
// 用途：to_musicxml 修复后刷新开发库中的旧缓存。
// flutter test tool/regen_musicxml_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:ejmusic/core/db/database.dart';
import 'package:ejmusic/data/score/score_store.dart';

const dbPath =
    r'C:\Users\hp\AppData\Roaming\com.ejmusic\ejmusic\ejmusic.sqlite';
const baseDir = r'C:\Users\hp\AppData\Roaming\com.ejmusic\ejmusic';

Future<String> regenAll() async {
  final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
  final store = ScoreStore(baseDir);
  final songs = await db.select(db.songs).get();
  var n = 0;
  for (final s in songs) {
    if (s.scorePath == null) continue;
    final doc = await store.load(s.id);
    if (doc == null) continue;
    await store.save(s.id, doc);
    // ignore: avoid_print
    print('regen song ${s.id} ${s.title}');
    n++;
  }
  await db.close();
  return '重新生成 $n 份缓存';
}
