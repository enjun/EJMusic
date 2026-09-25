import 'package:drift/drift.dart';

/// 曲子制作状态。
enum SongStatus { grouped, generating, ready, partial, failed }

SongStatus songStatusFromName(String name) => SongStatus.values
    .firstWhere((v) => v.name == name, orElse: () => SongStatus.grouped);

/// 单页 LLM 识别状态。
enum PageLlmStatus { pending, ok, failed }

PageLlmStatus pageLlmStatusFromName(String name) => PageLlmStatus.values
    .firstWhere((v) => v.name == name, orElse: () => PageLlmStatus.pending);

/// 导入分组（一次导入的一个目录内按前缀聚类的组）。
class ImageGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dirPath => text()();
  TextColumn get label => text()();
  IntColumn get imageCount => integer()();
  BoolColumn get closed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 源扫描图片（带感知哈希指纹，用于去重）。
class SourceImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get absPath => text().unique()();
  TextColumn get fileName => text()();
  TextColumn get phash => text().nullable()();
  IntColumn get bytes => integer()();
  IntColumn get mtimeMs => integer()();
  IntColumn get groupId => integer().references(ImageGroups, #id)();
  IntColumn get pageIndexInGroup => integer()();
}

/// 曲目（含转换产物：derived=true, sourceSongId 指向原曲）。
@TableIndex(name: 'idx_songs_title_norm', columns: {#titleNorm})
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get titleNorm => text()();
  TextColumn get composer => text().nullable()();
  TextColumn get kind => text().withLength(min: 1, max: 16).withDefault(const Constant('piano'))();
  IntColumn get keyFifths => integer().nullable()();
  IntColumn get timeBeats => integer().nullable()();
  IntColumn get timeBeatType => integer().nullable()();
  IntColumn get bpm => integer().nullable()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('grouped'))();
  TextColumn get scorePath => text().nullable()();
  TextColumn get musicxmlCachePath => text().nullable()();
  TextColumn get errorMsg => text().nullable()();
  IntColumn get sourceGroupId => integer().nullable().references(ImageGroups, #id)();
  IntColumn get sourceSongId => integer().nullable().references(Songs, #id)();
  BoolColumn get derived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 曲子的页（与源图片一一对应，记录 LLM 识别进度）。
class SongPages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId => integer().references(Songs, #id)();
  IntColumn get pageIndex => integer()();
  IntColumn get sourceImageId => integer().references(SourceImages, #id)();
  TextColumn get phash => text().nullable()();
  TextColumn get llmStatus => text().withDefault(const Constant('pending'))();
  TextColumn get llmError => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

/// LLM 任务队列（断点续跑：App 中断后可继续未完成页）。
class LlmJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(ImageGroups, #id)();
  IntColumn get pageIndex => integer()();
  TextColumn get status => text().withLength(min: 1, max: 16).withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 键值设置（非敏感项；api key 存 flutter_secure_storage）。
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
