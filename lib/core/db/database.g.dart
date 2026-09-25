// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ImageGroupsTable extends ImageGroups
    with TableInfo<$ImageGroupsTable, ImageGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dirPathMeta = const VerificationMeta(
    'dirPath',
  );
  @override
  late final GeneratedColumn<String> dirPath = GeneratedColumn<String>(
    'dir_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageCountMeta = const VerificationMeta(
    'imageCount',
  );
  @override
  late final GeneratedColumn<int> imageCount = GeneratedColumn<int>(
    'image_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedMeta = const VerificationMeta('closed');
  @override
  late final GeneratedColumn<bool> closed = GeneratedColumn<bool>(
    'closed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dirPath,
    label,
    imageCount,
    closed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dir_path')) {
      context.handle(
        _dirPathMeta,
        dirPath.isAcceptableOrUnknown(data['dir_path']!, _dirPathMeta),
      );
    } else if (isInserting) {
      context.missing(_dirPathMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('image_count')) {
      context.handle(
        _imageCountMeta,
        imageCount.isAcceptableOrUnknown(data['image_count']!, _imageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_imageCountMeta);
    }
    if (data.containsKey('closed')) {
      context.handle(
        _closedMeta,
        closed.isAcceptableOrUnknown(data['closed']!, _closedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImageGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dirPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dir_path'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      imageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_count'],
      )!,
      closed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ImageGroupsTable createAlias(String alias) {
    return $ImageGroupsTable(attachedDatabase, alias);
  }
}

class ImageGroup extends DataClass implements Insertable<ImageGroup> {
  final int id;
  final String dirPath;
  final String label;
  final int imageCount;
  final bool closed;
  final DateTime createdAt;
  const ImageGroup({
    required this.id,
    required this.dirPath,
    required this.label,
    required this.imageCount,
    required this.closed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dir_path'] = Variable<String>(dirPath);
    map['label'] = Variable<String>(label);
    map['image_count'] = Variable<int>(imageCount);
    map['closed'] = Variable<bool>(closed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ImageGroupsCompanion toCompanion(bool nullToAbsent) {
    return ImageGroupsCompanion(
      id: Value(id),
      dirPath: Value(dirPath),
      label: Value(label),
      imageCount: Value(imageCount),
      closed: Value(closed),
      createdAt: Value(createdAt),
    );
  }

  factory ImageGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageGroup(
      id: serializer.fromJson<int>(json['id']),
      dirPath: serializer.fromJson<String>(json['dirPath']),
      label: serializer.fromJson<String>(json['label']),
      imageCount: serializer.fromJson<int>(json['imageCount']),
      closed: serializer.fromJson<bool>(json['closed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dirPath': serializer.toJson<String>(dirPath),
      'label': serializer.toJson<String>(label),
      'imageCount': serializer.toJson<int>(imageCount),
      'closed': serializer.toJson<bool>(closed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ImageGroup copyWith({
    int? id,
    String? dirPath,
    String? label,
    int? imageCount,
    bool? closed,
    DateTime? createdAt,
  }) => ImageGroup(
    id: id ?? this.id,
    dirPath: dirPath ?? this.dirPath,
    label: label ?? this.label,
    imageCount: imageCount ?? this.imageCount,
    closed: closed ?? this.closed,
    createdAt: createdAt ?? this.createdAt,
  );
  ImageGroup copyWithCompanion(ImageGroupsCompanion data) {
    return ImageGroup(
      id: data.id.present ? data.id.value : this.id,
      dirPath: data.dirPath.present ? data.dirPath.value : this.dirPath,
      label: data.label.present ? data.label.value : this.label,
      imageCount: data.imageCount.present
          ? data.imageCount.value
          : this.imageCount,
      closed: data.closed.present ? data.closed.value : this.closed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageGroup(')
          ..write('id: $id, ')
          ..write('dirPath: $dirPath, ')
          ..write('label: $label, ')
          ..write('imageCount: $imageCount, ')
          ..write('closed: $closed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dirPath, label, imageCount, closed, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageGroup &&
          other.id == this.id &&
          other.dirPath == this.dirPath &&
          other.label == this.label &&
          other.imageCount == this.imageCount &&
          other.closed == this.closed &&
          other.createdAt == this.createdAt);
}

class ImageGroupsCompanion extends UpdateCompanion<ImageGroup> {
  final Value<int> id;
  final Value<String> dirPath;
  final Value<String> label;
  final Value<int> imageCount;
  final Value<bool> closed;
  final Value<DateTime> createdAt;
  const ImageGroupsCompanion({
    this.id = const Value.absent(),
    this.dirPath = const Value.absent(),
    this.label = const Value.absent(),
    this.imageCount = const Value.absent(),
    this.closed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ImageGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String dirPath,
    required String label,
    required int imageCount,
    this.closed = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : dirPath = Value(dirPath),
       label = Value(label),
       imageCount = Value(imageCount);
  static Insertable<ImageGroup> custom({
    Expression<int>? id,
    Expression<String>? dirPath,
    Expression<String>? label,
    Expression<int>? imageCount,
    Expression<bool>? closed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dirPath != null) 'dir_path': dirPath,
      if (label != null) 'label': label,
      if (imageCount != null) 'image_count': imageCount,
      if (closed != null) 'closed': closed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ImageGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? dirPath,
    Value<String>? label,
    Value<int>? imageCount,
    Value<bool>? closed,
    Value<DateTime>? createdAt,
  }) {
    return ImageGroupsCompanion(
      id: id ?? this.id,
      dirPath: dirPath ?? this.dirPath,
      label: label ?? this.label,
      imageCount: imageCount ?? this.imageCount,
      closed: closed ?? this.closed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dirPath.present) {
      map['dir_path'] = Variable<String>(dirPath.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (imageCount.present) {
      map['image_count'] = Variable<int>(imageCount.value);
    }
    if (closed.present) {
      map['closed'] = Variable<bool>(closed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageGroupsCompanion(')
          ..write('id: $id, ')
          ..write('dirPath: $dirPath, ')
          ..write('label: $label, ')
          ..write('imageCount: $imageCount, ')
          ..write('closed: $closed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SourceImagesTable extends SourceImages
    with TableInfo<$SourceImagesTable, SourceImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _absPathMeta = const VerificationMeta(
    'absPath',
  );
  @override
  late final GeneratedColumn<String> absPath = GeneratedColumn<String>(
    'abs_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phashMeta = const VerificationMeta('phash');
  @override
  late final GeneratedColumn<String> phash = GeneratedColumn<String>(
    'phash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES image_groups (id)',
    ),
  );
  static const VerificationMeta _pageIndexInGroupMeta = const VerificationMeta(
    'pageIndexInGroup',
  );
  @override
  late final GeneratedColumn<int> pageIndexInGroup = GeneratedColumn<int>(
    'page_index_in_group',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    absPath,
    fileName,
    phash,
    bytes,
    mtimeMs,
    groupId,
    pageIndexInGroup,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('abs_path')) {
      context.handle(
        _absPathMeta,
        absPath.isAcceptableOrUnknown(data['abs_path']!, _absPathMeta),
      );
    } else if (isInserting) {
      context.missing(_absPathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('phash')) {
      context.handle(
        _phashMeta,
        phash.isAcceptableOrUnknown(data['phash']!, _phashMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMsMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('page_index_in_group')) {
      context.handle(
        _pageIndexInGroupMeta,
        pageIndexInGroup.isAcceptableOrUnknown(
          data['page_index_in_group']!,
          _pageIndexInGroupMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pageIndexInGroupMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      absPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abs_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      phash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phash'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      pageIndexInGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index_in_group'],
      )!,
    );
  }

  @override
  $SourceImagesTable createAlias(String alias) {
    return $SourceImagesTable(attachedDatabase, alias);
  }
}

class SourceImage extends DataClass implements Insertable<SourceImage> {
  final int id;
  final String absPath;
  final String fileName;
  final String? phash;
  final int bytes;
  final int mtimeMs;
  final int groupId;
  final int pageIndexInGroup;
  const SourceImage({
    required this.id,
    required this.absPath,
    required this.fileName,
    this.phash,
    required this.bytes,
    required this.mtimeMs,
    required this.groupId,
    required this.pageIndexInGroup,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['abs_path'] = Variable<String>(absPath);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || phash != null) {
      map['phash'] = Variable<String>(phash);
    }
    map['bytes'] = Variable<int>(bytes);
    map['mtime_ms'] = Variable<int>(mtimeMs);
    map['group_id'] = Variable<int>(groupId);
    map['page_index_in_group'] = Variable<int>(pageIndexInGroup);
    return map;
  }

  SourceImagesCompanion toCompanion(bool nullToAbsent) {
    return SourceImagesCompanion(
      id: Value(id),
      absPath: Value(absPath),
      fileName: Value(fileName),
      phash: phash == null && nullToAbsent
          ? const Value.absent()
          : Value(phash),
      bytes: Value(bytes),
      mtimeMs: Value(mtimeMs),
      groupId: Value(groupId),
      pageIndexInGroup: Value(pageIndexInGroup),
    );
  }

  factory SourceImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceImage(
      id: serializer.fromJson<int>(json['id']),
      absPath: serializer.fromJson<String>(json['absPath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      phash: serializer.fromJson<String?>(json['phash']),
      bytes: serializer.fromJson<int>(json['bytes']),
      mtimeMs: serializer.fromJson<int>(json['mtimeMs']),
      groupId: serializer.fromJson<int>(json['groupId']),
      pageIndexInGroup: serializer.fromJson<int>(json['pageIndexInGroup']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'absPath': serializer.toJson<String>(absPath),
      'fileName': serializer.toJson<String>(fileName),
      'phash': serializer.toJson<String?>(phash),
      'bytes': serializer.toJson<int>(bytes),
      'mtimeMs': serializer.toJson<int>(mtimeMs),
      'groupId': serializer.toJson<int>(groupId),
      'pageIndexInGroup': serializer.toJson<int>(pageIndexInGroup),
    };
  }

  SourceImage copyWith({
    int? id,
    String? absPath,
    String? fileName,
    Value<String?> phash = const Value.absent(),
    int? bytes,
    int? mtimeMs,
    int? groupId,
    int? pageIndexInGroup,
  }) => SourceImage(
    id: id ?? this.id,
    absPath: absPath ?? this.absPath,
    fileName: fileName ?? this.fileName,
    phash: phash.present ? phash.value : this.phash,
    bytes: bytes ?? this.bytes,
    mtimeMs: mtimeMs ?? this.mtimeMs,
    groupId: groupId ?? this.groupId,
    pageIndexInGroup: pageIndexInGroup ?? this.pageIndexInGroup,
  );
  SourceImage copyWithCompanion(SourceImagesCompanion data) {
    return SourceImage(
      id: data.id.present ? data.id.value : this.id,
      absPath: data.absPath.present ? data.absPath.value : this.absPath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      phash: data.phash.present ? data.phash.value : this.phash,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      pageIndexInGroup: data.pageIndexInGroup.present
          ? data.pageIndexInGroup.value
          : this.pageIndexInGroup,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceImage(')
          ..write('id: $id, ')
          ..write('absPath: $absPath, ')
          ..write('fileName: $fileName, ')
          ..write('phash: $phash, ')
          ..write('bytes: $bytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('groupId: $groupId, ')
          ..write('pageIndexInGroup: $pageIndexInGroup')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    absPath,
    fileName,
    phash,
    bytes,
    mtimeMs,
    groupId,
    pageIndexInGroup,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceImage &&
          other.id == this.id &&
          other.absPath == this.absPath &&
          other.fileName == this.fileName &&
          other.phash == this.phash &&
          other.bytes == this.bytes &&
          other.mtimeMs == this.mtimeMs &&
          other.groupId == this.groupId &&
          other.pageIndexInGroup == this.pageIndexInGroup);
}

class SourceImagesCompanion extends UpdateCompanion<SourceImage> {
  final Value<int> id;
  final Value<String> absPath;
  final Value<String> fileName;
  final Value<String?> phash;
  final Value<int> bytes;
  final Value<int> mtimeMs;
  final Value<int> groupId;
  final Value<int> pageIndexInGroup;
  const SourceImagesCompanion({
    this.id = const Value.absent(),
    this.absPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.phash = const Value.absent(),
    this.bytes = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.groupId = const Value.absent(),
    this.pageIndexInGroup = const Value.absent(),
  });
  SourceImagesCompanion.insert({
    this.id = const Value.absent(),
    required String absPath,
    required String fileName,
    this.phash = const Value.absent(),
    required int bytes,
    required int mtimeMs,
    required int groupId,
    required int pageIndexInGroup,
  }) : absPath = Value(absPath),
       fileName = Value(fileName),
       bytes = Value(bytes),
       mtimeMs = Value(mtimeMs),
       groupId = Value(groupId),
       pageIndexInGroup = Value(pageIndexInGroup);
  static Insertable<SourceImage> custom({
    Expression<int>? id,
    Expression<String>? absPath,
    Expression<String>? fileName,
    Expression<String>? phash,
    Expression<int>? bytes,
    Expression<int>? mtimeMs,
    Expression<int>? groupId,
    Expression<int>? pageIndexInGroup,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (absPath != null) 'abs_path': absPath,
      if (fileName != null) 'file_name': fileName,
      if (phash != null) 'phash': phash,
      if (bytes != null) 'bytes': bytes,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (groupId != null) 'group_id': groupId,
      if (pageIndexInGroup != null) 'page_index_in_group': pageIndexInGroup,
    });
  }

  SourceImagesCompanion copyWith({
    Value<int>? id,
    Value<String>? absPath,
    Value<String>? fileName,
    Value<String?>? phash,
    Value<int>? bytes,
    Value<int>? mtimeMs,
    Value<int>? groupId,
    Value<int>? pageIndexInGroup,
  }) {
    return SourceImagesCompanion(
      id: id ?? this.id,
      absPath: absPath ?? this.absPath,
      fileName: fileName ?? this.fileName,
      phash: phash ?? this.phash,
      bytes: bytes ?? this.bytes,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      groupId: groupId ?? this.groupId,
      pageIndexInGroup: pageIndexInGroup ?? this.pageIndexInGroup,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (absPath.present) {
      map['abs_path'] = Variable<String>(absPath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (phash.present) {
      map['phash'] = Variable<String>(phash.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (pageIndexInGroup.present) {
      map['page_index_in_group'] = Variable<int>(pageIndexInGroup.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceImagesCompanion(')
          ..write('id: $id, ')
          ..write('absPath: $absPath, ')
          ..write('fileName: $fileName, ')
          ..write('phash: $phash, ')
          ..write('bytes: $bytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('groupId: $groupId, ')
          ..write('pageIndexInGroup: $pageIndexInGroup')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleNormMeta = const VerificationMeta(
    'titleNorm',
  );
  @override
  late final GeneratedColumn<String> titleNorm = GeneratedColumn<String>(
    'title_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _composerMeta = const VerificationMeta(
    'composer',
  );
  @override
  late final GeneratedColumn<String> composer = GeneratedColumn<String>(
    'composer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('piano'),
  );
  static const VerificationMeta _keyFifthsMeta = const VerificationMeta(
    'keyFifths',
  );
  @override
  late final GeneratedColumn<int> keyFifths = GeneratedColumn<int>(
    'key_fifths',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeBeatsMeta = const VerificationMeta(
    'timeBeats',
  );
  @override
  late final GeneratedColumn<int> timeBeats = GeneratedColumn<int>(
    'time_beats',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeBeatTypeMeta = const VerificationMeta(
    'timeBeatType',
  );
  @override
  late final GeneratedColumn<int> timeBeatType = GeneratedColumn<int>(
    'time_beat_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('grouped'),
  );
  static const VerificationMeta _scorePathMeta = const VerificationMeta(
    'scorePath',
  );
  @override
  late final GeneratedColumn<String> scorePath = GeneratedColumn<String>(
    'score_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _musicxmlCachePathMeta = const VerificationMeta(
    'musicxmlCachePath',
  );
  @override
  late final GeneratedColumn<String> musicxmlCachePath =
      GeneratedColumn<String>(
        'musicxml_cache_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorMsgMeta = const VerificationMeta(
    'errorMsg',
  );
  @override
  late final GeneratedColumn<String> errorMsg = GeneratedColumn<String>(
    'error_msg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceGroupIdMeta = const VerificationMeta(
    'sourceGroupId',
  );
  @override
  late final GeneratedColumn<int> sourceGroupId = GeneratedColumn<int>(
    'source_group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES image_groups (id)',
    ),
  );
  static const VerificationMeta _sourceSongIdMeta = const VerificationMeta(
    'sourceSongId',
  );
  @override
  late final GeneratedColumn<int> sourceSongId = GeneratedColumn<int>(
    'source_song_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _derivedMeta = const VerificationMeta(
    'derived',
  );
  @override
  late final GeneratedColumn<bool> derived = GeneratedColumn<bool>(
    'derived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("derived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    titleNorm,
    composer,
    kind,
    keyFifths,
    timeBeats,
    timeBeatType,
    bpm,
    pageCount,
    status,
    scorePath,
    musicxmlCachePath,
    errorMsg,
    sourceGroupId,
    sourceSongId,
    derived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Song> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('title_norm')) {
      context.handle(
        _titleNormMeta,
        titleNorm.isAcceptableOrUnknown(data['title_norm']!, _titleNormMeta),
      );
    } else if (isInserting) {
      context.missing(_titleNormMeta);
    }
    if (data.containsKey('composer')) {
      context.handle(
        _composerMeta,
        composer.isAcceptableOrUnknown(data['composer']!, _composerMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('key_fifths')) {
      context.handle(
        _keyFifthsMeta,
        keyFifths.isAcceptableOrUnknown(data['key_fifths']!, _keyFifthsMeta),
      );
    }
    if (data.containsKey('time_beats')) {
      context.handle(
        _timeBeatsMeta,
        timeBeats.isAcceptableOrUnknown(data['time_beats']!, _timeBeatsMeta),
      );
    }
    if (data.containsKey('time_beat_type')) {
      context.handle(
        _timeBeatTypeMeta,
        timeBeatType.isAcceptableOrUnknown(
          data['time_beat_type']!,
          _timeBeatTypeMeta,
        ),
      );
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('score_path')) {
      context.handle(
        _scorePathMeta,
        scorePath.isAcceptableOrUnknown(data['score_path']!, _scorePathMeta),
      );
    }
    if (data.containsKey('musicxml_cache_path')) {
      context.handle(
        _musicxmlCachePathMeta,
        musicxmlCachePath.isAcceptableOrUnknown(
          data['musicxml_cache_path']!,
          _musicxmlCachePathMeta,
        ),
      );
    }
    if (data.containsKey('error_msg')) {
      context.handle(
        _errorMsgMeta,
        errorMsg.isAcceptableOrUnknown(data['error_msg']!, _errorMsgMeta),
      );
    }
    if (data.containsKey('source_group_id')) {
      context.handle(
        _sourceGroupIdMeta,
        sourceGroupId.isAcceptableOrUnknown(
          data['source_group_id']!,
          _sourceGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('source_song_id')) {
      context.handle(
        _sourceSongIdMeta,
        sourceSongId.isAcceptableOrUnknown(
          data['source_song_id']!,
          _sourceSongIdMeta,
        ),
      );
    }
    if (data.containsKey('derived')) {
      context.handle(
        _derivedMeta,
        derived.isAcceptableOrUnknown(data['derived']!, _derivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      titleNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_norm'],
      )!,
      composer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}composer'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      keyFifths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_fifths'],
      ),
      timeBeats: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_beats'],
      ),
      timeBeatType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_beat_type'],
      ),
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      scorePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_path'],
      ),
      musicxmlCachePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}musicxml_cache_path'],
      ),
      errorMsg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_msg'],
      ),
      sourceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_group_id'],
      ),
      sourceSongId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_song_id'],
      ),
      derived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}derived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final int id;
  final String title;
  final String titleNorm;
  final String? composer;
  final String kind;
  final int? keyFifths;
  final int? timeBeats;
  final int? timeBeatType;
  final int? bpm;
  final int pageCount;
  final String status;
  final String? scorePath;
  final String? musicxmlCachePath;
  final String? errorMsg;
  final int? sourceGroupId;
  final int? sourceSongId;
  final bool derived;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Song({
    required this.id,
    required this.title,
    required this.titleNorm,
    this.composer,
    required this.kind,
    this.keyFifths,
    this.timeBeats,
    this.timeBeatType,
    this.bpm,
    required this.pageCount,
    required this.status,
    this.scorePath,
    this.musicxmlCachePath,
    this.errorMsg,
    this.sourceGroupId,
    this.sourceSongId,
    required this.derived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['title_norm'] = Variable<String>(titleNorm);
    if (!nullToAbsent || composer != null) {
      map['composer'] = Variable<String>(composer);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || keyFifths != null) {
      map['key_fifths'] = Variable<int>(keyFifths);
    }
    if (!nullToAbsent || timeBeats != null) {
      map['time_beats'] = Variable<int>(timeBeats);
    }
    if (!nullToAbsent || timeBeatType != null) {
      map['time_beat_type'] = Variable<int>(timeBeatType);
    }
    if (!nullToAbsent || bpm != null) {
      map['bpm'] = Variable<int>(bpm);
    }
    map['page_count'] = Variable<int>(pageCount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || scorePath != null) {
      map['score_path'] = Variable<String>(scorePath);
    }
    if (!nullToAbsent || musicxmlCachePath != null) {
      map['musicxml_cache_path'] = Variable<String>(musicxmlCachePath);
    }
    if (!nullToAbsent || errorMsg != null) {
      map['error_msg'] = Variable<String>(errorMsg);
    }
    if (!nullToAbsent || sourceGroupId != null) {
      map['source_group_id'] = Variable<int>(sourceGroupId);
    }
    if (!nullToAbsent || sourceSongId != null) {
      map['source_song_id'] = Variable<int>(sourceSongId);
    }
    map['derived'] = Variable<bool>(derived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      titleNorm: Value(titleNorm),
      composer: composer == null && nullToAbsent
          ? const Value.absent()
          : Value(composer),
      kind: Value(kind),
      keyFifths: keyFifths == null && nullToAbsent
          ? const Value.absent()
          : Value(keyFifths),
      timeBeats: timeBeats == null && nullToAbsent
          ? const Value.absent()
          : Value(timeBeats),
      timeBeatType: timeBeatType == null && nullToAbsent
          ? const Value.absent()
          : Value(timeBeatType),
      bpm: bpm == null && nullToAbsent ? const Value.absent() : Value(bpm),
      pageCount: Value(pageCount),
      status: Value(status),
      scorePath: scorePath == null && nullToAbsent
          ? const Value.absent()
          : Value(scorePath),
      musicxmlCachePath: musicxmlCachePath == null && nullToAbsent
          ? const Value.absent()
          : Value(musicxmlCachePath),
      errorMsg: errorMsg == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMsg),
      sourceGroupId: sourceGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceGroupId),
      sourceSongId: sourceSongId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSongId),
      derived: Value(derived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Song.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      titleNorm: serializer.fromJson<String>(json['titleNorm']),
      composer: serializer.fromJson<String?>(json['composer']),
      kind: serializer.fromJson<String>(json['kind']),
      keyFifths: serializer.fromJson<int?>(json['keyFifths']),
      timeBeats: serializer.fromJson<int?>(json['timeBeats']),
      timeBeatType: serializer.fromJson<int?>(json['timeBeatType']),
      bpm: serializer.fromJson<int?>(json['bpm']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      status: serializer.fromJson<String>(json['status']),
      scorePath: serializer.fromJson<String?>(json['scorePath']),
      musicxmlCachePath: serializer.fromJson<String?>(
        json['musicxmlCachePath'],
      ),
      errorMsg: serializer.fromJson<String?>(json['errorMsg']),
      sourceGroupId: serializer.fromJson<int?>(json['sourceGroupId']),
      sourceSongId: serializer.fromJson<int?>(json['sourceSongId']),
      derived: serializer.fromJson<bool>(json['derived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'titleNorm': serializer.toJson<String>(titleNorm),
      'composer': serializer.toJson<String?>(composer),
      'kind': serializer.toJson<String>(kind),
      'keyFifths': serializer.toJson<int?>(keyFifths),
      'timeBeats': serializer.toJson<int?>(timeBeats),
      'timeBeatType': serializer.toJson<int?>(timeBeatType),
      'bpm': serializer.toJson<int?>(bpm),
      'pageCount': serializer.toJson<int>(pageCount),
      'status': serializer.toJson<String>(status),
      'scorePath': serializer.toJson<String?>(scorePath),
      'musicxmlCachePath': serializer.toJson<String?>(musicxmlCachePath),
      'errorMsg': serializer.toJson<String?>(errorMsg),
      'sourceGroupId': serializer.toJson<int?>(sourceGroupId),
      'sourceSongId': serializer.toJson<int?>(sourceSongId),
      'derived': serializer.toJson<bool>(derived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Song copyWith({
    int? id,
    String? title,
    String? titleNorm,
    Value<String?> composer = const Value.absent(),
    String? kind,
    Value<int?> keyFifths = const Value.absent(),
    Value<int?> timeBeats = const Value.absent(),
    Value<int?> timeBeatType = const Value.absent(),
    Value<int?> bpm = const Value.absent(),
    int? pageCount,
    String? status,
    Value<String?> scorePath = const Value.absent(),
    Value<String?> musicxmlCachePath = const Value.absent(),
    Value<String?> errorMsg = const Value.absent(),
    Value<int?> sourceGroupId = const Value.absent(),
    Value<int?> sourceSongId = const Value.absent(),
    bool? derived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Song(
    id: id ?? this.id,
    title: title ?? this.title,
    titleNorm: titleNorm ?? this.titleNorm,
    composer: composer.present ? composer.value : this.composer,
    kind: kind ?? this.kind,
    keyFifths: keyFifths.present ? keyFifths.value : this.keyFifths,
    timeBeats: timeBeats.present ? timeBeats.value : this.timeBeats,
    timeBeatType: timeBeatType.present ? timeBeatType.value : this.timeBeatType,
    bpm: bpm.present ? bpm.value : this.bpm,
    pageCount: pageCount ?? this.pageCount,
    status: status ?? this.status,
    scorePath: scorePath.present ? scorePath.value : this.scorePath,
    musicxmlCachePath: musicxmlCachePath.present
        ? musicxmlCachePath.value
        : this.musicxmlCachePath,
    errorMsg: errorMsg.present ? errorMsg.value : this.errorMsg,
    sourceGroupId: sourceGroupId.present
        ? sourceGroupId.value
        : this.sourceGroupId,
    sourceSongId: sourceSongId.present ? sourceSongId.value : this.sourceSongId,
    derived: derived ?? this.derived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      titleNorm: data.titleNorm.present ? data.titleNorm.value : this.titleNorm,
      composer: data.composer.present ? data.composer.value : this.composer,
      kind: data.kind.present ? data.kind.value : this.kind,
      keyFifths: data.keyFifths.present ? data.keyFifths.value : this.keyFifths,
      timeBeats: data.timeBeats.present ? data.timeBeats.value : this.timeBeats,
      timeBeatType: data.timeBeatType.present
          ? data.timeBeatType.value
          : this.timeBeatType,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      status: data.status.present ? data.status.value : this.status,
      scorePath: data.scorePath.present ? data.scorePath.value : this.scorePath,
      musicxmlCachePath: data.musicxmlCachePath.present
          ? data.musicxmlCachePath.value
          : this.musicxmlCachePath,
      errorMsg: data.errorMsg.present ? data.errorMsg.value : this.errorMsg,
      sourceGroupId: data.sourceGroupId.present
          ? data.sourceGroupId.value
          : this.sourceGroupId,
      sourceSongId: data.sourceSongId.present
          ? data.sourceSongId.value
          : this.sourceSongId,
      derived: data.derived.present ? data.derived.value : this.derived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('titleNorm: $titleNorm, ')
          ..write('composer: $composer, ')
          ..write('kind: $kind, ')
          ..write('keyFifths: $keyFifths, ')
          ..write('timeBeats: $timeBeats, ')
          ..write('timeBeatType: $timeBeatType, ')
          ..write('bpm: $bpm, ')
          ..write('pageCount: $pageCount, ')
          ..write('status: $status, ')
          ..write('scorePath: $scorePath, ')
          ..write('musicxmlCachePath: $musicxmlCachePath, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('sourceGroupId: $sourceGroupId, ')
          ..write('sourceSongId: $sourceSongId, ')
          ..write('derived: $derived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    titleNorm,
    composer,
    kind,
    keyFifths,
    timeBeats,
    timeBeatType,
    bpm,
    pageCount,
    status,
    scorePath,
    musicxmlCachePath,
    errorMsg,
    sourceGroupId,
    sourceSongId,
    derived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.title == this.title &&
          other.titleNorm == this.titleNorm &&
          other.composer == this.composer &&
          other.kind == this.kind &&
          other.keyFifths == this.keyFifths &&
          other.timeBeats == this.timeBeats &&
          other.timeBeatType == this.timeBeatType &&
          other.bpm == this.bpm &&
          other.pageCount == this.pageCount &&
          other.status == this.status &&
          other.scorePath == this.scorePath &&
          other.musicxmlCachePath == this.musicxmlCachePath &&
          other.errorMsg == this.errorMsg &&
          other.sourceGroupId == this.sourceGroupId &&
          other.sourceSongId == this.sourceSongId &&
          other.derived == this.derived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> titleNorm;
  final Value<String?> composer;
  final Value<String> kind;
  final Value<int?> keyFifths;
  final Value<int?> timeBeats;
  final Value<int?> timeBeatType;
  final Value<int?> bpm;
  final Value<int> pageCount;
  final Value<String> status;
  final Value<String?> scorePath;
  final Value<String?> musicxmlCachePath;
  final Value<String?> errorMsg;
  final Value<int?> sourceGroupId;
  final Value<int?> sourceSongId;
  final Value<bool> derived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.titleNorm = const Value.absent(),
    this.composer = const Value.absent(),
    this.kind = const Value.absent(),
    this.keyFifths = const Value.absent(),
    this.timeBeats = const Value.absent(),
    this.timeBeatType = const Value.absent(),
    this.bpm = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.status = const Value.absent(),
    this.scorePath = const Value.absent(),
    this.musicxmlCachePath = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.sourceGroupId = const Value.absent(),
    this.sourceSongId = const Value.absent(),
    this.derived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SongsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String titleNorm,
    this.composer = const Value.absent(),
    this.kind = const Value.absent(),
    this.keyFifths = const Value.absent(),
    this.timeBeats = const Value.absent(),
    this.timeBeatType = const Value.absent(),
    this.bpm = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.status = const Value.absent(),
    this.scorePath = const Value.absent(),
    this.musicxmlCachePath = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.sourceGroupId = const Value.absent(),
    this.sourceSongId = const Value.absent(),
    this.derived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title),
       titleNorm = Value(titleNorm);
  static Insertable<Song> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? titleNorm,
    Expression<String>? composer,
    Expression<String>? kind,
    Expression<int>? keyFifths,
    Expression<int>? timeBeats,
    Expression<int>? timeBeatType,
    Expression<int>? bpm,
    Expression<int>? pageCount,
    Expression<String>? status,
    Expression<String>? scorePath,
    Expression<String>? musicxmlCachePath,
    Expression<String>? errorMsg,
    Expression<int>? sourceGroupId,
    Expression<int>? sourceSongId,
    Expression<bool>? derived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (titleNorm != null) 'title_norm': titleNorm,
      if (composer != null) 'composer': composer,
      if (kind != null) 'kind': kind,
      if (keyFifths != null) 'key_fifths': keyFifths,
      if (timeBeats != null) 'time_beats': timeBeats,
      if (timeBeatType != null) 'time_beat_type': timeBeatType,
      if (bpm != null) 'bpm': bpm,
      if (pageCount != null) 'page_count': pageCount,
      if (status != null) 'status': status,
      if (scorePath != null) 'score_path': scorePath,
      if (musicxmlCachePath != null) 'musicxml_cache_path': musicxmlCachePath,
      if (errorMsg != null) 'error_msg': errorMsg,
      if (sourceGroupId != null) 'source_group_id': sourceGroupId,
      if (sourceSongId != null) 'source_song_id': sourceSongId,
      if (derived != null) 'derived': derived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SongsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? titleNorm,
    Value<String?>? composer,
    Value<String>? kind,
    Value<int?>? keyFifths,
    Value<int?>? timeBeats,
    Value<int?>? timeBeatType,
    Value<int?>? bpm,
    Value<int>? pageCount,
    Value<String>? status,
    Value<String?>? scorePath,
    Value<String?>? musicxmlCachePath,
    Value<String?>? errorMsg,
    Value<int?>? sourceGroupId,
    Value<int?>? sourceSongId,
    Value<bool>? derived,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      titleNorm: titleNorm ?? this.titleNorm,
      composer: composer ?? this.composer,
      kind: kind ?? this.kind,
      keyFifths: keyFifths ?? this.keyFifths,
      timeBeats: timeBeats ?? this.timeBeats,
      timeBeatType: timeBeatType ?? this.timeBeatType,
      bpm: bpm ?? this.bpm,
      pageCount: pageCount ?? this.pageCount,
      status: status ?? this.status,
      scorePath: scorePath ?? this.scorePath,
      musicxmlCachePath: musicxmlCachePath ?? this.musicxmlCachePath,
      errorMsg: errorMsg ?? this.errorMsg,
      sourceGroupId: sourceGroupId ?? this.sourceGroupId,
      sourceSongId: sourceSongId ?? this.sourceSongId,
      derived: derived ?? this.derived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (titleNorm.present) {
      map['title_norm'] = Variable<String>(titleNorm.value);
    }
    if (composer.present) {
      map['composer'] = Variable<String>(composer.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (keyFifths.present) {
      map['key_fifths'] = Variable<int>(keyFifths.value);
    }
    if (timeBeats.present) {
      map['time_beats'] = Variable<int>(timeBeats.value);
    }
    if (timeBeatType.present) {
      map['time_beat_type'] = Variable<int>(timeBeatType.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scorePath.present) {
      map['score_path'] = Variable<String>(scorePath.value);
    }
    if (musicxmlCachePath.present) {
      map['musicxml_cache_path'] = Variable<String>(musicxmlCachePath.value);
    }
    if (errorMsg.present) {
      map['error_msg'] = Variable<String>(errorMsg.value);
    }
    if (sourceGroupId.present) {
      map['source_group_id'] = Variable<int>(sourceGroupId.value);
    }
    if (sourceSongId.present) {
      map['source_song_id'] = Variable<int>(sourceSongId.value);
    }
    if (derived.present) {
      map['derived'] = Variable<bool>(derived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('titleNorm: $titleNorm, ')
          ..write('composer: $composer, ')
          ..write('kind: $kind, ')
          ..write('keyFifths: $keyFifths, ')
          ..write('timeBeats: $timeBeats, ')
          ..write('timeBeatType: $timeBeatType, ')
          ..write('bpm: $bpm, ')
          ..write('pageCount: $pageCount, ')
          ..write('status: $status, ')
          ..write('scorePath: $scorePath, ')
          ..write('musicxmlCachePath: $musicxmlCachePath, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('sourceGroupId: $sourceGroupId, ')
          ..write('sourceSongId: $sourceSongId, ')
          ..write('derived: $derived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SongPagesTable extends SongPages
    with TableInfo<$SongPagesTable, SongPage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<int> songId = GeneratedColumn<int>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id)',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceImageIdMeta = const VerificationMeta(
    'sourceImageId',
  );
  @override
  late final GeneratedColumn<int> sourceImageId = GeneratedColumn<int>(
    'source_image_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES source_images (id)',
    ),
  );
  static const VerificationMeta _phashMeta = const VerificationMeta('phash');
  @override
  late final GeneratedColumn<String> phash = GeneratedColumn<String>(
    'phash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _llmStatusMeta = const VerificationMeta(
    'llmStatus',
  );
  @override
  late final GeneratedColumn<String> llmStatus = GeneratedColumn<String>(
    'llm_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _llmErrorMeta = const VerificationMeta(
    'llmError',
  );
  @override
  late final GeneratedColumn<String> llmError = GeneratedColumn<String>(
    'llm_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    pageIndex,
    sourceImageId,
    phash,
    llmStatus,
    llmError,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongPage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('source_image_id')) {
      context.handle(
        _sourceImageIdMeta,
        sourceImageId.isAcceptableOrUnknown(
          data['source_image_id']!,
          _sourceImageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceImageIdMeta);
    }
    if (data.containsKey('phash')) {
      context.handle(
        _phashMeta,
        phash.isAcceptableOrUnknown(data['phash']!, _phashMeta),
      );
    }
    if (data.containsKey('llm_status')) {
      context.handle(
        _llmStatusMeta,
        llmStatus.isAcceptableOrUnknown(data['llm_status']!, _llmStatusMeta),
      );
    }
    if (data.containsKey('llm_error')) {
      context.handle(
        _llmErrorMeta,
        llmError.isAcceptableOrUnknown(data['llm_error']!, _llmErrorMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongPage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongPage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}song_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      sourceImageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_image_id'],
      )!,
      phash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phash'],
      ),
      llmStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}llm_status'],
      )!,
      llmError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}llm_error'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $SongPagesTable createAlias(String alias) {
    return $SongPagesTable(attachedDatabase, alias);
  }
}

class SongPage extends DataClass implements Insertable<SongPage> {
  final int id;
  final int songId;
  final int pageIndex;
  final int sourceImageId;
  final String? phash;
  final String llmStatus;
  final String? llmError;
  final int attempts;
  const SongPage({
    required this.id,
    required this.songId,
    required this.pageIndex,
    required this.sourceImageId,
    this.phash,
    required this.llmStatus,
    this.llmError,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<int>(songId);
    map['page_index'] = Variable<int>(pageIndex);
    map['source_image_id'] = Variable<int>(sourceImageId);
    if (!nullToAbsent || phash != null) {
      map['phash'] = Variable<String>(phash);
    }
    map['llm_status'] = Variable<String>(llmStatus);
    if (!nullToAbsent || llmError != null) {
      map['llm_error'] = Variable<String>(llmError);
    }
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  SongPagesCompanion toCompanion(bool nullToAbsent) {
    return SongPagesCompanion(
      id: Value(id),
      songId: Value(songId),
      pageIndex: Value(pageIndex),
      sourceImageId: Value(sourceImageId),
      phash: phash == null && nullToAbsent
          ? const Value.absent()
          : Value(phash),
      llmStatus: Value(llmStatus),
      llmError: llmError == null && nullToAbsent
          ? const Value.absent()
          : Value(llmError),
      attempts: Value(attempts),
    );
  }

  factory SongPage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongPage(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<int>(json['songId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      sourceImageId: serializer.fromJson<int>(json['sourceImageId']),
      phash: serializer.fromJson<String?>(json['phash']),
      llmStatus: serializer.fromJson<String>(json['llmStatus']),
      llmError: serializer.fromJson<String?>(json['llmError']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<int>(songId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'sourceImageId': serializer.toJson<int>(sourceImageId),
      'phash': serializer.toJson<String?>(phash),
      'llmStatus': serializer.toJson<String>(llmStatus),
      'llmError': serializer.toJson<String?>(llmError),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  SongPage copyWith({
    int? id,
    int? songId,
    int? pageIndex,
    int? sourceImageId,
    Value<String?> phash = const Value.absent(),
    String? llmStatus,
    Value<String?> llmError = const Value.absent(),
    int? attempts,
  }) => SongPage(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    pageIndex: pageIndex ?? this.pageIndex,
    sourceImageId: sourceImageId ?? this.sourceImageId,
    phash: phash.present ? phash.value : this.phash,
    llmStatus: llmStatus ?? this.llmStatus,
    llmError: llmError.present ? llmError.value : this.llmError,
    attempts: attempts ?? this.attempts,
  );
  SongPage copyWithCompanion(SongPagesCompanion data) {
    return SongPage(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      sourceImageId: data.sourceImageId.present
          ? data.sourceImageId.value
          : this.sourceImageId,
      phash: data.phash.present ? data.phash.value : this.phash,
      llmStatus: data.llmStatus.present ? data.llmStatus.value : this.llmStatus,
      llmError: data.llmError.present ? data.llmError.value : this.llmError,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongPage(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('sourceImageId: $sourceImageId, ')
          ..write('phash: $phash, ')
          ..write('llmStatus: $llmStatus, ')
          ..write('llmError: $llmError, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    songId,
    pageIndex,
    sourceImageId,
    phash,
    llmStatus,
    llmError,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongPage &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.pageIndex == this.pageIndex &&
          other.sourceImageId == this.sourceImageId &&
          other.phash == this.phash &&
          other.llmStatus == this.llmStatus &&
          other.llmError == this.llmError &&
          other.attempts == this.attempts);
}

class SongPagesCompanion extends UpdateCompanion<SongPage> {
  final Value<int> id;
  final Value<int> songId;
  final Value<int> pageIndex;
  final Value<int> sourceImageId;
  final Value<String?> phash;
  final Value<String> llmStatus;
  final Value<String?> llmError;
  final Value<int> attempts;
  const SongPagesCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.sourceImageId = const Value.absent(),
    this.phash = const Value.absent(),
    this.llmStatus = const Value.absent(),
    this.llmError = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  SongPagesCompanion.insert({
    this.id = const Value.absent(),
    required int songId,
    required int pageIndex,
    required int sourceImageId,
    this.phash = const Value.absent(),
    this.llmStatus = const Value.absent(),
    this.llmError = const Value.absent(),
    this.attempts = const Value.absent(),
  }) : songId = Value(songId),
       pageIndex = Value(pageIndex),
       sourceImageId = Value(sourceImageId);
  static Insertable<SongPage> custom({
    Expression<int>? id,
    Expression<int>? songId,
    Expression<int>? pageIndex,
    Expression<int>? sourceImageId,
    Expression<String>? phash,
    Expression<String>? llmStatus,
    Expression<String>? llmError,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (sourceImageId != null) 'source_image_id': sourceImageId,
      if (phash != null) 'phash': phash,
      if (llmStatus != null) 'llm_status': llmStatus,
      if (llmError != null) 'llm_error': llmError,
      if (attempts != null) 'attempts': attempts,
    });
  }

  SongPagesCompanion copyWith({
    Value<int>? id,
    Value<int>? songId,
    Value<int>? pageIndex,
    Value<int>? sourceImageId,
    Value<String?>? phash,
    Value<String>? llmStatus,
    Value<String?>? llmError,
    Value<int>? attempts,
  }) {
    return SongPagesCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      pageIndex: pageIndex ?? this.pageIndex,
      sourceImageId: sourceImageId ?? this.sourceImageId,
      phash: phash ?? this.phash,
      llmStatus: llmStatus ?? this.llmStatus,
      llmError: llmError ?? this.llmError,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<int>(songId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (sourceImageId.present) {
      map['source_image_id'] = Variable<int>(sourceImageId.value);
    }
    if (phash.present) {
      map['phash'] = Variable<String>(phash.value);
    }
    if (llmStatus.present) {
      map['llm_status'] = Variable<String>(llmStatus.value);
    }
    if (llmError.present) {
      map['llm_error'] = Variable<String>(llmError.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongPagesCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('sourceImageId: $sourceImageId, ')
          ..write('phash: $phash, ')
          ..write('llmStatus: $llmStatus, ')
          ..write('llmError: $llmError, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

class $LlmJobsTable extends LlmJobs with TableInfo<$LlmJobsTable, LlmJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES image_groups (id)',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    pageIndex,
    status,
    attempts,
    error,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LlmJobsTable createAlias(String alias) {
    return $LlmJobsTable(attachedDatabase, alias);
  }
}

class LlmJob extends DataClass implements Insertable<LlmJob> {
  final int id;
  final int groupId;
  final int pageIndex;
  final String status;
  final int attempts;
  final String? error;
  final DateTime updatedAt;
  const LlmJob({
    required this.id,
    required this.groupId,
    required this.pageIndex,
    required this.status,
    required this.attempts,
    this.error,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<int>(groupId);
    map['page_index'] = Variable<int>(pageIndex);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LlmJobsCompanion toCompanion(bool nullToAbsent) {
    return LlmJobsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      pageIndex: Value(pageIndex),
      status: Value(status),
      attempts: Value(attempts),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      updatedAt: Value(updatedAt),
    );
  }

  factory LlmJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmJob(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int>(json['groupId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      error: serializer.fromJson<String?>(json['error']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int>(groupId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'error': serializer.toJson<String?>(error),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LlmJob copyWith({
    int? id,
    int? groupId,
    int? pageIndex,
    String? status,
    int? attempts,
    Value<String?> error = const Value.absent(),
    DateTime? updatedAt,
  }) => LlmJob(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    pageIndex: pageIndex ?? this.pageIndex,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    error: error.present ? error.value : this.error,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LlmJob copyWithCompanion(LlmJobsCompanion data) {
    return LlmJob(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      error: data.error.present ? data.error.value : this.error,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmJob(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, pageIndex, status, attempts, error, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmJob &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.pageIndex == this.pageIndex &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.error == this.error &&
          other.updatedAt == this.updatedAt);
}

class LlmJobsCompanion extends UpdateCompanion<LlmJob> {
  final Value<int> id;
  final Value<int> groupId;
  final Value<int> pageIndex;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> error;
  final Value<DateTime> updatedAt;
  const LlmJobsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.error = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LlmJobsCompanion.insert({
    this.id = const Value.absent(),
    required int groupId,
    required int pageIndex,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.error = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : groupId = Value(groupId),
       pageIndex = Value(pageIndex);
  static Insertable<LlmJob> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<int>? pageIndex,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? error,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (error != null) 'error': error,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LlmJobsCompanion copyWith({
    Value<int>? id,
    Value<int>? groupId,
    Value<int>? pageIndex,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? error,
    Value<DateTime>? updatedAt,
  }) {
    return LlmJobsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      pageIndex: pageIndex ?? this.pageIndex,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      error: error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmJobsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ImageGroupsTable imageGroups = $ImageGroupsTable(this);
  late final $SourceImagesTable sourceImages = $SourceImagesTable(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $SongPagesTable songPages = $SongPagesTable(this);
  late final $LlmJobsTable llmJobs = $LlmJobsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index idxSongsTitleNorm = Index(
    'idx_songs_title_norm',
    'CREATE INDEX idx_songs_title_norm ON songs (title_norm)',
  );
  late final ImportDao importDao = ImportDao(this as AppDatabase);
  late final SongsDao songsDao = SongsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    imageGroups,
    sourceImages,
    songs,
    songPages,
    llmJobs,
    appSettings,
    idxSongsTitleNorm,
  ];
}

typedef $$ImageGroupsTableCreateCompanionBuilder =
    ImageGroupsCompanion Function({
      Value<int> id,
      required String dirPath,
      required String label,
      required int imageCount,
      Value<bool> closed,
      Value<DateTime> createdAt,
    });
typedef $$ImageGroupsTableUpdateCompanionBuilder =
    ImageGroupsCompanion Function({
      Value<int> id,
      Value<String> dirPath,
      Value<String> label,
      Value<int> imageCount,
      Value<bool> closed,
      Value<DateTime> createdAt,
    });

final class $$ImageGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $ImageGroupsTable, ImageGroup> {
  $$ImageGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SourceImagesTable, List<SourceImage>>
  _sourceImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sourceImages,
    aliasName: 'image_groups__id__source_images__group_id',
  );

  $$SourceImagesTableProcessedTableManager get sourceImagesRefs {
    final manager = $$SourceImagesTableTableManager(
      $_db,
      $_db.sourceImages,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SongsTable, List<Song>> _songsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.songs,
    aliasName: 'image_groups__id__songs__source_group_id',
  );

  $$SongsTableProcessedTableManager get songsRefs {
    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.sourceGroupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LlmJobsTable, List<LlmJob>> _llmJobsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.llmJobs,
    aliasName: 'image_groups__id__llm_jobs__group_id',
  );

  $$LlmJobsTableProcessedTableManager get llmJobsRefs {
    final manager = $$LlmJobsTableTableManager(
      $_db,
      $_db.llmJobs,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_llmJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImageGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ImageGroupsTable> {
  $$ImageGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dirPath => $composableBuilder(
    column: $table.dirPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageCount => $composableBuilder(
    column: $table.imageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get closed => $composableBuilder(
    column: $table.closed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sourceImagesRefs(
    Expression<bool> Function($$SourceImagesTableFilterComposer f) f,
  ) {
    final $$SourceImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceImages,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceImagesTableFilterComposer(
            $db: $db,
            $table: $db.sourceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> songsRefs(
    Expression<bool> Function($$SongsTableFilterComposer f) f,
  ) {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.sourceGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> llmJobsRefs(
    Expression<bool> Function($$LlmJobsTableFilterComposer f) f,
  ) {
    final $$LlmJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.llmJobs,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LlmJobsTableFilterComposer(
            $db: $db,
            $table: $db.llmJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImageGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageGroupsTable> {
  $$ImageGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dirPath => $composableBuilder(
    column: $table.dirPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageCount => $composableBuilder(
    column: $table.imageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get closed => $composableBuilder(
    column: $table.closed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImageGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageGroupsTable> {
  $$ImageGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dirPath =>
      $composableBuilder(column: $table.dirPath, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get imageCount => $composableBuilder(
    column: $table.imageCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get closed =>
      $composableBuilder(column: $table.closed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> sourceImagesRefs<T extends Object>(
    Expression<T> Function($$SourceImagesTableAnnotationComposer a) f,
  ) {
    final $$SourceImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceImages,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> songsRefs<T extends Object>(
    Expression<T> Function($$SongsTableAnnotationComposer a) f,
  ) {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.sourceGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> llmJobsRefs<T extends Object>(
    Expression<T> Function($$LlmJobsTableAnnotationComposer a) f,
  ) {
    final $$LlmJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.llmJobs,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LlmJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.llmJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImageGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageGroupsTable,
          ImageGroup,
          $$ImageGroupsTableFilterComposer,
          $$ImageGroupsTableOrderingComposer,
          $$ImageGroupsTableAnnotationComposer,
          $$ImageGroupsTableCreateCompanionBuilder,
          $$ImageGroupsTableUpdateCompanionBuilder,
          (ImageGroup, $$ImageGroupsTableReferences),
          ImageGroup,
          PrefetchHooks Function({
            bool sourceImagesRefs,
            bool songsRefs,
            bool llmJobsRefs,
          })
        > {
  $$ImageGroupsTableTableManager(_$AppDatabase db, $ImageGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dirPath = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> imageCount = const Value.absent(),
                Value<bool> closed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ImageGroupsCompanion(
                id: id,
                dirPath: dirPath,
                label: label,
                imageCount: imageCount,
                closed: closed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dirPath,
                required String label,
                required int imageCount,
                Value<bool> closed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ImageGroupsCompanion.insert(
                id: id,
                dirPath: dirPath,
                label: label,
                imageCount: imageCount,
                closed: closed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImageGroupsTable, ImageGroup>(table),
                  $$ImageGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceImagesRefs = false,
                songsRefs = false,
                llmJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sourceImagesRefs) db.sourceImages,
                    if (songsRefs) db.songs,
                    if (llmJobsRefs) db.llmJobs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sourceImagesRefs)
                        await $_getPrefetchedData<
                          ImageGroup,
                          $ImageGroupsTable,
                          SourceImage
                        >(
                          currentTable: table,
                          referencedTable: $$ImageGroupsTableReferences
                              ._sourceImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImageGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (songsRefs)
                        await $_getPrefetchedData<
                          ImageGroup,
                          $ImageGroupsTable,
                          Song
                        >(
                          currentTable: table,
                          referencedTable: $$ImageGroupsTableReferences
                              ._songsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImageGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).songsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (llmJobsRefs)
                        await $_getPrefetchedData<
                          ImageGroup,
                          $ImageGroupsTable,
                          LlmJob
                        >(
                          currentTable: table,
                          referencedTable: $$ImageGroupsTableReferences
                              ._llmJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImageGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).llmJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ImageGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageGroupsTable,
      ImageGroup,
      $$ImageGroupsTableFilterComposer,
      $$ImageGroupsTableOrderingComposer,
      $$ImageGroupsTableAnnotationComposer,
      $$ImageGroupsTableCreateCompanionBuilder,
      $$ImageGroupsTableUpdateCompanionBuilder,
      (ImageGroup, $$ImageGroupsTableReferences),
      ImageGroup,
      PrefetchHooks Function({
        bool sourceImagesRefs,
        bool songsRefs,
        bool llmJobsRefs,
      })
    >;
typedef $$SourceImagesTableCreateCompanionBuilder =
    SourceImagesCompanion Function({
      Value<int> id,
      required String absPath,
      required String fileName,
      Value<String?> phash,
      required int bytes,
      required int mtimeMs,
      required int groupId,
      required int pageIndexInGroup,
    });
typedef $$SourceImagesTableUpdateCompanionBuilder =
    SourceImagesCompanion Function({
      Value<int> id,
      Value<String> absPath,
      Value<String> fileName,
      Value<String?> phash,
      Value<int> bytes,
      Value<int> mtimeMs,
      Value<int> groupId,
      Value<int> pageIndexInGroup,
    });

final class $$SourceImagesTableReferences
    extends BaseReferences<_$AppDatabase, $SourceImagesTable, SourceImage> {
  $$SourceImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImageGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.imageGroups.createAlias('source_images__group_id__image_groups__id');

  $$ImageGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$ImageGroupsTableTableManager(
      $_db,
      $_db.imageGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SongPagesTable, List<SongPage>>
  _songPagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.songPages,
    aliasName: 'source_images__id__song_pages__source_image_id',
  );

  $$SongPagesTableProcessedTableManager get songPagesRefs {
    final manager = $$SongPagesTableTableManager(
      $_db,
      $_db.songPages,
    ).filter((f) => f.sourceImageId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songPagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourceImagesTableFilterComposer
    extends Composer<_$AppDatabase, $SourceImagesTable> {
  $$SourceImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get absPath => $composableBuilder(
    column: $table.absPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phash => $composableBuilder(
    column: $table.phash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndexInGroup => $composableBuilder(
    column: $table.pageIndexInGroup,
    builder: (column) => ColumnFilters(column),
  );

  $$ImageGroupsTableFilterComposer get groupId {
    final $$ImageGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableFilterComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> songPagesRefs(
    Expression<bool> Function($$SongPagesTableFilterComposer f) f,
  ) {
    final $$SongPagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songPages,
      getReferencedColumn: (t) => t.sourceImageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongPagesTableFilterComposer(
            $db: $db,
            $table: $db.songPages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourceImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceImagesTable> {
  $$SourceImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get absPath => $composableBuilder(
    column: $table.absPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phash => $composableBuilder(
    column: $table.phash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndexInGroup => $composableBuilder(
    column: $table.pageIndexInGroup,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImageGroupsTableOrderingComposer get groupId {
    final $$ImageGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourceImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceImagesTable> {
  $$SourceImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get absPath =>
      $composableBuilder(column: $table.absPath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get phash =>
      $composableBuilder(column: $table.phash, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<int> get pageIndexInGroup => $composableBuilder(
    column: $table.pageIndexInGroup,
    builder: (column) => column,
  );

  $$ImageGroupsTableAnnotationComposer get groupId {
    final $$ImageGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> songPagesRefs<T extends Object>(
    Expression<T> Function($$SongPagesTableAnnotationComposer a) f,
  ) {
    final $$SongPagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songPages,
      getReferencedColumn: (t) => t.sourceImageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongPagesTableAnnotationComposer(
            $db: $db,
            $table: $db.songPages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourceImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceImagesTable,
          SourceImage,
          $$SourceImagesTableFilterComposer,
          $$SourceImagesTableOrderingComposer,
          $$SourceImagesTableAnnotationComposer,
          $$SourceImagesTableCreateCompanionBuilder,
          $$SourceImagesTableUpdateCompanionBuilder,
          (SourceImage, $$SourceImagesTableReferences),
          SourceImage,
          PrefetchHooks Function({bool groupId, bool songPagesRefs})
        > {
  $$SourceImagesTableTableManager(_$AppDatabase db, $SourceImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> absPath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> phash = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<int> pageIndexInGroup = const Value.absent(),
              }) => SourceImagesCompanion(
                id: id,
                absPath: absPath,
                fileName: fileName,
                phash: phash,
                bytes: bytes,
                mtimeMs: mtimeMs,
                groupId: groupId,
                pageIndexInGroup: pageIndexInGroup,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String absPath,
                required String fileName,
                Value<String?> phash = const Value.absent(),
                required int bytes,
                required int mtimeMs,
                required int groupId,
                required int pageIndexInGroup,
              }) => SourceImagesCompanion.insert(
                id: id,
                absPath: absPath,
                fileName: fileName,
                phash: phash,
                bytes: bytes,
                mtimeMs: mtimeMs,
                groupId: groupId,
                pageIndexInGroup: pageIndexInGroup,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceImagesTable, SourceImage>(table),
                  $$SourceImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false, songPagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songPagesRefs) db.songPages],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$SourceImagesTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$SourceImagesTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songPagesRefs)
                    await $_getPrefetchedData<
                      SourceImage,
                      $SourceImagesTable,
                      SongPage
                    >(
                      currentTable: table,
                      referencedTable: $$SourceImagesTableReferences
                          ._songPagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SourceImagesTableReferences(
                            db,
                            table,
                            p0,
                          ).songPagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.sourceImageId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SourceImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceImagesTable,
      SourceImage,
      $$SourceImagesTableFilterComposer,
      $$SourceImagesTableOrderingComposer,
      $$SourceImagesTableAnnotationComposer,
      $$SourceImagesTableCreateCompanionBuilder,
      $$SourceImagesTableUpdateCompanionBuilder,
      (SourceImage, $$SourceImagesTableReferences),
      SourceImage,
      PrefetchHooks Function({bool groupId, bool songPagesRefs})
    >;
typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  required String title,
  required String titleNorm,
  Value<String?> composer,
  Value<String> kind,
  Value<int?> keyFifths,
  Value<int?> timeBeats,
  Value<int?> timeBeatType,
  Value<int?> bpm,
  Value<int> pageCount,
  Value<String> status,
  Value<String?> scorePath,
  Value<String?> musicxmlCachePath,
  Value<String?> errorMsg,
  Value<int?> sourceGroupId,
  Value<int?> sourceSongId,
  Value<bool> derived,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> titleNorm,
  Value<String?> composer,
  Value<String> kind,
  Value<int?> keyFifths,
  Value<int?> timeBeats,
  Value<int?> timeBeatType,
  Value<int?> bpm,
  Value<int> pageCount,
  Value<String> status,
  Value<String?> scorePath,
  Value<String?> musicxmlCachePath,
  Value<String?> errorMsg,
  Value<int?> sourceGroupId,
  Value<int?> sourceSongId,
  Value<bool> derived,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$SongsTableReferences
    extends BaseReferences<_$AppDatabase, $SongsTable, Song> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImageGroupsTable _sourceGroupIdTable(_$AppDatabase db) =>
      db.imageGroups.createAlias('songs__source_group_id__image_groups__id');

  $$ImageGroupsTableProcessedTableManager? get sourceGroupId {
    final $_column = $_itemColumn<int>('source_group_id');
    if ($_column == null) return null;
    final manager = $$ImageGroupsTableTableManager(
      $_db,
      $_db.imageGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SongsTable _sourceSongIdTable(_$AppDatabase db) =>
      db.songs.createAlias('songs__source_song_id__songs__id');

  $$SongsTableProcessedTableManager? get sourceSongId {
    final $_column = $_itemColumn<int>('source_song_id');
    if ($_column == null) return null;
    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceSongIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SongPagesTable, List<SongPage>>
  _songPagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.songPages,
    aliasName: 'songs__id__song_pages__song_id',
  );

  $$SongPagesTableProcessedTableManager get songPagesRefs {
    final manager = $$SongPagesTableTableManager(
      $_db,
      $_db.songPages,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songPagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get composer => $composableBuilder(
    column: $table.composer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keyFifths => $composableBuilder(
    column: $table.keyFifths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeBeats => $composableBuilder(
    column: $table.timeBeats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeBeatType => $composableBuilder(
    column: $table.timeBeatType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scorePath => $composableBuilder(
    column: $table.scorePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musicxmlCachePath => $composableBuilder(
    column: $table.musicxmlCachePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get derived => $composableBuilder(
    column: $table.derived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ImageGroupsTableFilterComposer get sourceGroupId {
    final $$ImageGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceGroupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableFilterComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableFilterComposer get sourceSongId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceSongId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> songPagesRefs(
    Expression<bool> Function($$SongPagesTableFilterComposer f) f,
  ) {
    final $$SongPagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songPages,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongPagesTableFilterComposer(
            $db: $db,
            $table: $db.songPages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get composer => $composableBuilder(
    column: $table.composer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keyFifths => $composableBuilder(
    column: $table.keyFifths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeBeats => $composableBuilder(
    column: $table.timeBeats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeBeatType => $composableBuilder(
    column: $table.timeBeatType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scorePath => $composableBuilder(
    column: $table.scorePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicxmlCachePath => $composableBuilder(
    column: $table.musicxmlCachePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get derived => $composableBuilder(
    column: $table.derived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImageGroupsTableOrderingComposer get sourceGroupId {
    final $$ImageGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceGroupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableOrderingComposer get sourceSongId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceSongId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get titleNorm =>
      $composableBuilder(column: $table.titleNorm, builder: (column) => column);

  GeneratedColumn<String> get composer =>
      $composableBuilder(column: $table.composer, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get keyFifths =>
      $composableBuilder(column: $table.keyFifths, builder: (column) => column);

  GeneratedColumn<int> get timeBeats =>
      $composableBuilder(column: $table.timeBeats, builder: (column) => column);

  GeneratedColumn<int> get timeBeatType => $composableBuilder(
    column: $table.timeBeatType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get scorePath =>
      $composableBuilder(column: $table.scorePath, builder: (column) => column);

  GeneratedColumn<String> get musicxmlCachePath => $composableBuilder(
    column: $table.musicxmlCachePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMsg =>
      $composableBuilder(column: $table.errorMsg, builder: (column) => column);

  GeneratedColumn<bool> get derived =>
      $composableBuilder(column: $table.derived, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ImageGroupsTableAnnotationComposer get sourceGroupId {
    final $$ImageGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceGroupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableAnnotationComposer get sourceSongId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceSongId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> songPagesRefs<T extends Object>(
    Expression<T> Function($$SongPagesTableAnnotationComposer a) f,
  ) {
    final $$SongPagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songPages,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongPagesTableAnnotationComposer(
            $db: $db,
            $table: $db.songPages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongsTable,
          Song,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (Song, $$SongsTableReferences),
          Song,
          PrefetchHooks Function({
            bool sourceGroupId,
            bool sourceSongId,
            bool songPagesRefs,
          })
        > {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> titleNorm = const Value.absent(),
                Value<String?> composer = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> keyFifths = const Value.absent(),
                Value<int?> timeBeats = const Value.absent(),
                Value<int?> timeBeatType = const Value.absent(),
                Value<int?> bpm = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> scorePath = const Value.absent(),
                Value<String?> musicxmlCachePath = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int?> sourceGroupId = const Value.absent(),
                Value<int?> sourceSongId = const Value.absent(),
                Value<bool> derived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SongsCompanion(
                id: id,
                title: title,
                titleNorm: titleNorm,
                composer: composer,
                kind: kind,
                keyFifths: keyFifths,
                timeBeats: timeBeats,
                timeBeatType: timeBeatType,
                bpm: bpm,
                pageCount: pageCount,
                status: status,
                scorePath: scorePath,
                musicxmlCachePath: musicxmlCachePath,
                errorMsg: errorMsg,
                sourceGroupId: sourceGroupId,
                sourceSongId: sourceSongId,
                derived: derived,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String titleNorm,
                Value<String?> composer = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> keyFifths = const Value.absent(),
                Value<int?> timeBeats = const Value.absent(),
                Value<int?> timeBeatType = const Value.absent(),
                Value<int?> bpm = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> scorePath = const Value.absent(),
                Value<String?> musicxmlCachePath = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int?> sourceGroupId = const Value.absent(),
                Value<int?> sourceSongId = const Value.absent(),
                Value<bool> derived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SongsCompanion.insert(
                id: id,
                title: title,
                titleNorm: titleNorm,
                composer: composer,
                kind: kind,
                keyFifths: keyFifths,
                timeBeats: timeBeats,
                timeBeatType: timeBeatType,
                bpm: bpm,
                pageCount: pageCount,
                status: status,
                scorePath: scorePath,
                musicxmlCachePath: musicxmlCachePath,
                errorMsg: errorMsg,
                sourceGroupId: sourceGroupId,
                sourceSongId: sourceSongId,
                derived: derived,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SongsTable, Song>(table),
                  $$SongsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceGroupId = false,
                sourceSongId = false,
                songPagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (songPagesRefs) db.songPages],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceGroupId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceGroupId,
                            referencedTable: $$SongsTableReferences
                                ._sourceGroupIdTable(db),
                            referencedColumn: $$SongsTableReferences
                                ._sourceGroupIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (sourceSongId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceSongId,
                            referencedTable: $$SongsTableReferences
                                ._sourceSongIdTable(db),
                            referencedColumn: $$SongsTableReferences
                                ._sourceSongIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (songPagesRefs)
                        await $_getPrefetchedData<Song, $SongsTable, SongPage>(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._songPagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).songPagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongsTable,
      Song,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (Song, $$SongsTableReferences),
      Song,
      PrefetchHooks Function({
        bool sourceGroupId,
        bool sourceSongId,
        bool songPagesRefs,
      })
    >;
typedef $$SongPagesTableCreateCompanionBuilder = SongPagesCompanion Function({
  Value<int> id,
  required int songId,
  required int pageIndex,
  required int sourceImageId,
  Value<String?> phash,
  Value<String> llmStatus,
  Value<String?> llmError,
  Value<int> attempts,
});
typedef $$SongPagesTableUpdateCompanionBuilder = SongPagesCompanion Function({
  Value<int> id,
  Value<int> songId,
  Value<int> pageIndex,
  Value<int> sourceImageId,
  Value<String?> phash,
  Value<String> llmStatus,
  Value<String?> llmError,
  Value<int> attempts,
});

final class $$SongPagesTableReferences
    extends BaseReferences<_$AppDatabase, $SongPagesTable, SongPage> {
  $$SongPagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias('song_pages__song_id__songs__id');

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<int>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourceImagesTable _sourceImageIdTable(_$AppDatabase db) => db
      .sourceImages
      .createAlias('song_pages__source_image_id__source_images__id');

  $$SourceImagesTableProcessedTableManager get sourceImageId {
    final $_column = $_itemColumn<int>('source_image_id')!;

    final manager = $$SourceImagesTableTableManager(
      $_db,
      $_db.sourceImages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceImageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SongPagesTableFilterComposer
    extends Composer<_$AppDatabase, $SongPagesTable> {
  $$SongPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phash => $composableBuilder(
    column: $table.phash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get llmStatus => $composableBuilder(
    column: $table.llmStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get llmError => $composableBuilder(
    column: $table.llmError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceImagesTableFilterComposer get sourceImageId {
    final $$SourceImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceImageId,
      referencedTable: $db.sourceImages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceImagesTableFilterComposer(
            $db: $db,
            $table: $db.sourceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongPagesTableOrderingComposer
    extends Composer<_$AppDatabase, $SongPagesTable> {
  $$SongPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phash => $composableBuilder(
    column: $table.phash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get llmStatus => $composableBuilder(
    column: $table.llmStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get llmError => $composableBuilder(
    column: $table.llmError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceImagesTableOrderingComposer get sourceImageId {
    final $$SourceImagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceImageId,
      referencedTable: $db.sourceImages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceImagesTableOrderingComposer(
            $db: $db,
            $table: $db.sourceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongPagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongPagesTable> {
  $$SongPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get phash =>
      $composableBuilder(column: $table.phash, builder: (column) => column);

  GeneratedColumn<String> get llmStatus =>
      $composableBuilder(column: $table.llmStatus, builder: (column) => column);

  GeneratedColumn<String> get llmError =>
      $composableBuilder(column: $table.llmError, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceImagesTableAnnotationComposer get sourceImageId {
    final $$SourceImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceImageId,
      referencedTable: $db.sourceImages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongPagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongPagesTable,
          SongPage,
          $$SongPagesTableFilterComposer,
          $$SongPagesTableOrderingComposer,
          $$SongPagesTableAnnotationComposer,
          $$SongPagesTableCreateCompanionBuilder,
          $$SongPagesTableUpdateCompanionBuilder,
          (SongPage, $$SongPagesTableReferences),
          SongPage,
          PrefetchHooks Function({bool songId, bool sourceImageId})
        > {
  $$SongPagesTableTableManager(_$AppDatabase db, $SongPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> songId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<int> sourceImageId = const Value.absent(),
                Value<String?> phash = const Value.absent(),
                Value<String> llmStatus = const Value.absent(),
                Value<String?> llmError = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => SongPagesCompanion(
                id: id,
                songId: songId,
                pageIndex: pageIndex,
                sourceImageId: sourceImageId,
                phash: phash,
                llmStatus: llmStatus,
                llmError: llmError,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int songId,
                required int pageIndex,
                required int sourceImageId,
                Value<String?> phash = const Value.absent(),
                Value<String> llmStatus = const Value.absent(),
                Value<String?> llmError = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => SongPagesCompanion.insert(
                id: id,
                songId: songId,
                pageIndex: pageIndex,
                sourceImageId: sourceImageId,
                phash: phash,
                llmStatus: llmStatus,
                llmError: llmError,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SongPagesTable, SongPage>(table),
                  $$SongPagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false, sourceImageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.songId,
                        referencedTable: $$SongPagesTableReferences
                            ._songIdTable(db),
                        referencedColumn: $$SongPagesTableReferences
                            ._songIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (sourceImageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceImageId,
                        referencedTable: $$SongPagesTableReferences
                            ._sourceImageIdTable(db),
                        referencedColumn: $$SongPagesTableReferences
                            ._sourceImageIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SongPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongPagesTable,
      SongPage,
      $$SongPagesTableFilterComposer,
      $$SongPagesTableOrderingComposer,
      $$SongPagesTableAnnotationComposer,
      $$SongPagesTableCreateCompanionBuilder,
      $$SongPagesTableUpdateCompanionBuilder,
      (SongPage, $$SongPagesTableReferences),
      SongPage,
      PrefetchHooks Function({bool songId, bool sourceImageId})
    >;
typedef $$LlmJobsTableCreateCompanionBuilder = LlmJobsCompanion Function({
  Value<int> id,
  required int groupId,
  required int pageIndex,
  Value<String> status,
  Value<int> attempts,
  Value<String?> error,
  Value<DateTime> updatedAt,
});
typedef $$LlmJobsTableUpdateCompanionBuilder = LlmJobsCompanion Function({
  Value<int> id,
  Value<int> groupId,
  Value<int> pageIndex,
  Value<String> status,
  Value<int> attempts,
  Value<String?> error,
  Value<DateTime> updatedAt,
});

final class $$LlmJobsTableReferences
    extends BaseReferences<_$AppDatabase, $LlmJobsTable, LlmJob> {
  $$LlmJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImageGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.imageGroups.createAlias('llm_jobs__group_id__image_groups__id');

  $$ImageGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$ImageGroupsTableTableManager(
      $_db,
      $_db.imageGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LlmJobsTableFilterComposer
    extends Composer<_$AppDatabase, $LlmJobsTable> {
  $$LlmJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ImageGroupsTableFilterComposer get groupId {
    final $$ImageGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableFilterComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LlmJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $LlmJobsTable> {
  $$LlmJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImageGroupsTableOrderingComposer get groupId {
    final $$ImageGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LlmJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LlmJobsTable> {
  $$LlmJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ImageGroupsTableAnnotationComposer get groupId {
    final $$ImageGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.imageGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.imageGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LlmJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LlmJobsTable,
          LlmJob,
          $$LlmJobsTableFilterComposer,
          $$LlmJobsTableOrderingComposer,
          $$LlmJobsTableAnnotationComposer,
          $$LlmJobsTableCreateCompanionBuilder,
          $$LlmJobsTableUpdateCompanionBuilder,
          (LlmJob, $$LlmJobsTableReferences),
          LlmJob,
          PrefetchHooks Function({bool groupId})
        > {
  $$LlmJobsTableTableManager(_$AppDatabase db, $LlmJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LlmJobsCompanion(
                id: id,
                groupId: groupId,
                pageIndex: pageIndex,
                status: status,
                attempts: attempts,
                error: error,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int groupId,
                required int pageIndex,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LlmJobsCompanion.insert(
                id: id,
                groupId: groupId,
                pageIndex: pageIndex,
                status: status,
                attempts: attempts,
                error: error,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LlmJobsTable, LlmJob>(table),
                  $$LlmJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$LlmJobsTableReferences._groupIdTable(
                          db,
                        ),
                        referencedColumn: $$LlmJobsTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LlmJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LlmJobsTable,
      LlmJob,
      $$LlmJobsTableFilterComposer,
      $$LlmJobsTableOrderingComposer,
      $$LlmJobsTableAnnotationComposer,
      $$LlmJobsTableCreateCompanionBuilder,
      $$LlmJobsTableUpdateCompanionBuilder,
      (LlmJob, $$LlmJobsTableReferences),
      LlmJob,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ImageGroupsTableTableManager get imageGroups =>
      $$ImageGroupsTableTableManager(_db, _db.imageGroups);
  $$SourceImagesTableTableManager get sourceImages =>
      $$SourceImagesTableTableManager(_db, _db.sourceImages);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$SongPagesTableTableManager get songPages =>
      $$SongPagesTableTableManager(_db, _db.songPages);
  $$LlmJobsTableTableManager get llmJobs =>
      $$LlmJobsTableTableManager(_db, _db.llmJobs);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
