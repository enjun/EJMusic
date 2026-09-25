// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_dao.dart';

// ignore_for_file: type=lint
mixin _$ImportDaoMixin on DatabaseAccessor<AppDatabase> {
  $ImageGroupsTable get imageGroups => attachedDatabase.imageGroups;
  $SourceImagesTable get sourceImages => attachedDatabase.sourceImages;
  $SongsTable get songs => attachedDatabase.songs;
  $SongPagesTable get songPages => attachedDatabase.songPages;
  ImportDaoManager get managers => ImportDaoManager(this);
}

class ImportDaoManager {
  final _$ImportDaoMixin _db;
  ImportDaoManager(this._db);
  $$ImageGroupsTableTableManager get imageGroups =>
      $$ImageGroupsTableTableManager(_db.attachedDatabase, _db.imageGroups);
  $$SourceImagesTableTableManager get sourceImages =>
      $$SourceImagesTableTableManager(_db.attachedDatabase, _db.sourceImages);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$SongPagesTableTableManager get songPages =>
      $$SongPagesTableTableManager(_db.attachedDatabase, _db.songPages);
}
