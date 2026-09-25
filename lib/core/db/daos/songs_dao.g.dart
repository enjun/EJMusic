// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'songs_dao.dart';

// ignore_for_file: type=lint
mixin _$SongsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ImageGroupsTable get imageGroups => attachedDatabase.imageGroups;
  $SongsTable get songs => attachedDatabase.songs;
  $SourceImagesTable get sourceImages => attachedDatabase.sourceImages;
  $SongPagesTable get songPages => attachedDatabase.songPages;
  SongsDaoManager get managers => SongsDaoManager(this);
}

class SongsDaoManager {
  final _$SongsDaoMixin _db;
  SongsDaoManager(this._db);
  $$ImageGroupsTableTableManager get imageGroups =>
      $$ImageGroupsTableTableManager(_db.attachedDatabase, _db.imageGroups);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db.attachedDatabase, _db.songs);
  $$SourceImagesTableTableManager get sourceImages =>
      $$SourceImagesTableTableManager(_db.attachedDatabase, _db.sourceImages);
  $$SongPagesTableTableManager get songPages =>
      $$SongPagesTableTableManager(_db.attachedDatabase, _db.songPages);
}
