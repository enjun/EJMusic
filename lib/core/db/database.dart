import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/import_dao.dart';
import 'daos/songs_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  ImageGroups,
  SourceImages,
  Songs,
  SongPages,
  LlmJobs,
  AppSettings,
], daos: [ImportDao, SongsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<String> get appDocDir async {
    final dir = await getApplicationSupportDirectory();
    final songsDir = p.join(dir.path, 'songs');
    await Directory(songsDir).create(recursive: true);
    return songsDir;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'ejmusic.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
