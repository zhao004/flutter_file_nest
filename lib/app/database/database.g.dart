// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _rootUriMeta = const VerificationMeta(
    'rootUri',
  );
  @override
  late final GeneratedColumn<String> rootUri = GeneratedColumn<String>(
    'root_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioEnabledMeta = const VerificationMeta(
    'audioEnabled',
  );
  @override
  late final GeneratedColumn<bool> audioEnabled = GeneratedColumn<bool>(
    'audio_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("audio_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortFieldMeta = const VerificationMeta(
    'sortField',
  );
  @override
  late final GeneratedColumn<String> sortField = GeneratedColumn<String>(
    'sort_field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('modified'),
  );
  static const VerificationMeta _sortDescendingMeta = const VerificationMeta(
    'sortDescending',
  );
  @override
  late final GeneratedColumn<bool> sortDescending = GeneratedColumn<bool>(
    'sort_descending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sort_descending" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rootUri,
    audioEnabled,
    sortField,
    sortDescending,
    updatedAt,
  ];
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
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('root_uri')) {
      context.handle(
        _rootUriMeta,
        rootUri.isAcceptableOrUnknown(data['root_uri']!, _rootUriMeta),
      );
    }
    if (data.containsKey('audio_enabled')) {
      context.handle(
        _audioEnabledMeta,
        audioEnabled.isAcceptableOrUnknown(
          data['audio_enabled']!,
          _audioEnabledMeta,
        ),
      );
    }
    if (data.containsKey('sort_field')) {
      context.handle(
        _sortFieldMeta,
        sortField.isAcceptableOrUnknown(data['sort_field']!, _sortFieldMeta),
      );
    }
    if (data.containsKey('sort_descending')) {
      context.handle(
        _sortDescendingMeta,
        sortDescending.isAcceptableOrUnknown(
          data['sort_descending']!,
          _sortDescendingMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rootUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_uri'],
      ),
      audioEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}audio_enabled'],
      )!,
      sortField: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_field'],
      )!,
      sortDescending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sort_descending'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String? rootUri;
  final bool audioEnabled;
  final String sortField;
  final bool sortDescending;
  final DateTime updatedAt;
  const AppSetting({
    required this.id,
    this.rootUri,
    required this.audioEnabled,
    required this.sortField,
    required this.sortDescending,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || rootUri != null) {
      map['root_uri'] = Variable<String>(rootUri);
    }
    map['audio_enabled'] = Variable<bool>(audioEnabled);
    map['sort_field'] = Variable<String>(sortField);
    map['sort_descending'] = Variable<bool>(sortDescending);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      rootUri: rootUri == null && nullToAbsent
          ? const Value.absent()
          : Value(rootUri),
      audioEnabled: Value(audioEnabled),
      sortField: Value(sortField),
      sortDescending: Value(sortDescending),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      rootUri: serializer.fromJson<String?>(json['rootUri']),
      audioEnabled: serializer.fromJson<bool>(json['audioEnabled']),
      sortField: serializer.fromJson<String>(json['sortField']),
      sortDescending: serializer.fromJson<bool>(json['sortDescending']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rootUri': serializer.toJson<String?>(rootUri),
      'audioEnabled': serializer.toJson<bool>(audioEnabled),
      'sortField': serializer.toJson<String>(sortField),
      'sortDescending': serializer.toJson<bool>(sortDescending),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({
    int? id,
    Value<String?> rootUri = const Value.absent(),
    bool? audioEnabled,
    String? sortField,
    bool? sortDescending,
    DateTime? updatedAt,
  }) => AppSetting(
    id: id ?? this.id,
    rootUri: rootUri.present ? rootUri.value : this.rootUri,
    audioEnabled: audioEnabled ?? this.audioEnabled,
    sortField: sortField ?? this.sortField,
    sortDescending: sortDescending ?? this.sortDescending,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      rootUri: data.rootUri.present ? data.rootUri.value : this.rootUri,
      audioEnabled: data.audioEnabled.present
          ? data.audioEnabled.value
          : this.audioEnabled,
      sortField: data.sortField.present ? data.sortField.value : this.sortField,
      sortDescending: data.sortDescending.present
          ? data.sortDescending.value
          : this.sortDescending,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('rootUri: $rootUri, ')
          ..write('audioEnabled: $audioEnabled, ')
          ..write('sortField: $sortField, ')
          ..write('sortDescending: $sortDescending, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rootUri,
    audioEnabled,
    sortField,
    sortDescending,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.rootUri == this.rootUri &&
          other.audioEnabled == this.audioEnabled &&
          other.sortField == this.sortField &&
          other.sortDescending == this.sortDescending &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String?> rootUri;
  final Value<bool> audioEnabled;
  final Value<String> sortField;
  final Value<bool> sortDescending;
  final Value<DateTime> updatedAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.audioEnabled = const Value.absent(),
    this.sortField = const Value.absent(),
    this.sortDescending = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.audioEnabled = const Value.absent(),
    this.sortField = const Value.absent(),
    this.sortDescending = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? rootUri,
    Expression<bool>? audioEnabled,
    Expression<String>? sortField,
    Expression<bool>? sortDescending,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootUri != null) 'root_uri': rootUri,
      if (audioEnabled != null) 'audio_enabled': audioEnabled,
      if (sortField != null) 'sort_field': sortField,
      if (sortDescending != null) 'sort_descending': sortDescending,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? rootUri,
    Value<bool>? audioEnabled,
    Value<String>? sortField,
    Value<bool>? sortDescending,
    Value<DateTime>? updatedAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      rootUri: rootUri ?? this.rootUri,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rootUri.present) {
      map['root_uri'] = Variable<String>(rootUri.value);
    }
    if (audioEnabled.present) {
      map['audio_enabled'] = Variable<bool>(audioEnabled.value);
    }
    if (sortField.present) {
      map['sort_field'] = Variable<String>(sortField.value);
    }
    if (sortDescending.present) {
      map['sort_descending'] = Variable<bool>(sortDescending.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('rootUri: $rootUri, ')
          ..write('audioEnabled: $audioEnabled, ')
          ..write('sortField: $sortField, ')
          ..write('sortDescending: $sortDescending, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EntryMetadataTable extends EntryMetadata
    with TableInfo<$EntryMetadataTable, EntryMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [uri, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  EntryMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryMetadataData(
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EntryMetadataTable createAlias(String alias) {
    return $EntryMetadataTable(attachedDatabase, alias);
  }
}

class EntryMetadataData extends DataClass
    implements Insertable<EntryMetadataData> {
  final String uri;
  final DateTime createdAt;
  const EntryMetadataData({required this.uri, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EntryMetadataCompanion toCompanion(bool nullToAbsent) {
    return EntryMetadataCompanion(uri: Value(uri), createdAt: Value(createdAt));
  }

  factory EntryMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryMetadataData(
      uri: serializer.fromJson<String>(json['uri']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EntryMetadataData copyWith({String? uri, DateTime? createdAt}) =>
      EntryMetadataData(
        uri: uri ?? this.uri,
        createdAt: createdAt ?? this.createdAt,
      );
  EntryMetadataData copyWithCompanion(EntryMetadataCompanion data) {
    return EntryMetadataData(
      uri: data.uri.present ? data.uri.value : this.uri,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryMetadataData(')
          ..write('uri: $uri, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uri, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryMetadataData &&
          other.uri == this.uri &&
          other.createdAt == this.createdAt);
}

class EntryMetadataCompanion extends UpdateCompanion<EntryMetadataData> {
  final Value<String> uri;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EntryMetadataCompanion({
    this.uri = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryMetadataCompanion.insert({
    required String uri,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       createdAt = Value(createdAt);
  static Insertable<EntryMetadataData> custom({
    Expression<String>? uri,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryMetadataCompanion copyWith({
    Value<String>? uri,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EntryMetadataCompanion(
      uri: uri ?? this.uri,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryMetadataCompanion(')
          ..write('uri: $uri, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingRecordingsTable extends PendingRecordings
    with TableInfo<$PendingRecordingsTable, PendingRecording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingRecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temporaryPathMeta = const VerificationMeta(
    'temporaryPath',
  );
  @override
  late final GeneratedColumn<String> temporaryPath = GeneratedColumn<String>(
    'temporary_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootUriMeta = const VerificationMeta(
    'rootUri',
  );
  @override
  late final GeneratedColumn<String> rootUri = GeneratedColumn<String>(
    'root_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentDocumentIdMeta = const VerificationMeta(
    'parentDocumentId',
  );
  @override
  late final GeneratedColumn<String> parentDocumentId = GeneratedColumn<String>(
    'parent_document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    sourcePath,
    temporaryPath,
    rootUri,
    parentDocumentId,
    fileName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingRecording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('temporary_path')) {
      context.handle(
        _temporaryPathMeta,
        temporaryPath.isAcceptableOrUnknown(
          data['temporary_path']!,
          _temporaryPathMeta,
        ),
      );
    }
    if (data.containsKey('root_uri')) {
      context.handle(
        _rootUriMeta,
        rootUri.isAcceptableOrUnknown(data['root_uri']!, _rootUriMeta),
      );
    } else if (isInserting) {
      context.missing(_rootUriMeta);
    }
    if (data.containsKey('parent_document_id')) {
      context.handle(
        _parentDocumentIdMeta,
        parentDocumentId.isAcceptableOrUnknown(
          data['parent_document_id']!,
          _parentDocumentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parentDocumentIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  PendingRecording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingRecording(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      temporaryPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporary_path'],
      ),
      rootUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_uri'],
      )!,
      parentDocumentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_document_id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingRecordingsTable createAlias(String alias) {
    return $PendingRecordingsTable(attachedDatabase, alias);
  }
}

class PendingRecording extends DataClass
    implements Insertable<PendingRecording> {
  final String operationId;
  final String sourcePath;
  final String? temporaryPath;
  final String rootUri;
  final String parentDocumentId;
  final String fileName;
  final DateTime createdAt;
  const PendingRecording({
    required this.operationId,
    required this.sourcePath,
    this.temporaryPath,
    required this.rootUri,
    required this.parentDocumentId,
    required this.fileName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['source_path'] = Variable<String>(sourcePath);
    if (!nullToAbsent || temporaryPath != null) {
      map['temporary_path'] = Variable<String>(temporaryPath);
    }
    map['root_uri'] = Variable<String>(rootUri);
    map['parent_document_id'] = Variable<String>(parentDocumentId);
    map['file_name'] = Variable<String>(fileName);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingRecordingsCompanion toCompanion(bool nullToAbsent) {
    return PendingRecordingsCompanion(
      operationId: Value(operationId),
      sourcePath: Value(sourcePath),
      temporaryPath: temporaryPath == null && nullToAbsent
          ? const Value.absent()
          : Value(temporaryPath),
      rootUri: Value(rootUri),
      parentDocumentId: Value(parentDocumentId),
      fileName: Value(fileName),
      createdAt: Value(createdAt),
    );
  }

  factory PendingRecording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingRecording(
      operationId: serializer.fromJson<String>(json['operationId']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      temporaryPath: serializer.fromJson<String?>(json['temporaryPath']),
      rootUri: serializer.fromJson<String>(json['rootUri']),
      parentDocumentId: serializer.fromJson<String>(json['parentDocumentId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'temporaryPath': serializer.toJson<String?>(temporaryPath),
      'rootUri': serializer.toJson<String>(rootUri),
      'parentDocumentId': serializer.toJson<String>(parentDocumentId),
      'fileName': serializer.toJson<String>(fileName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingRecording copyWith({
    String? operationId,
    String? sourcePath,
    Value<String?> temporaryPath = const Value.absent(),
    String? rootUri,
    String? parentDocumentId,
    String? fileName,
    DateTime? createdAt,
  }) => PendingRecording(
    operationId: operationId ?? this.operationId,
    sourcePath: sourcePath ?? this.sourcePath,
    temporaryPath: temporaryPath.present
        ? temporaryPath.value
        : this.temporaryPath,
    rootUri: rootUri ?? this.rootUri,
    parentDocumentId: parentDocumentId ?? this.parentDocumentId,
    fileName: fileName ?? this.fileName,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingRecording copyWithCompanion(PendingRecordingsCompanion data) {
    return PendingRecording(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      temporaryPath: data.temporaryPath.present
          ? data.temporaryPath.value
          : this.temporaryPath,
      rootUri: data.rootUri.present ? data.rootUri.value : this.rootUri,
      parentDocumentId: data.parentDocumentId.present
          ? data.parentDocumentId.value
          : this.parentDocumentId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingRecording(')
          ..write('operationId: $operationId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('temporaryPath: $temporaryPath, ')
          ..write('rootUri: $rootUri, ')
          ..write('parentDocumentId: $parentDocumentId, ')
          ..write('fileName: $fileName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    sourcePath,
    temporaryPath,
    rootUri,
    parentDocumentId,
    fileName,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingRecording &&
          other.operationId == this.operationId &&
          other.sourcePath == this.sourcePath &&
          other.temporaryPath == this.temporaryPath &&
          other.rootUri == this.rootUri &&
          other.parentDocumentId == this.parentDocumentId &&
          other.fileName == this.fileName &&
          other.createdAt == this.createdAt);
}

class PendingRecordingsCompanion extends UpdateCompanion<PendingRecording> {
  final Value<String> operationId;
  final Value<String> sourcePath;
  final Value<String?> temporaryPath;
  final Value<String> rootUri;
  final Value<String> parentDocumentId;
  final Value<String> fileName;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingRecordingsCompanion({
    this.operationId = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.temporaryPath = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.parentDocumentId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingRecordingsCompanion.insert({
    required String operationId,
    required String sourcePath,
    this.temporaryPath = const Value.absent(),
    required String rootUri,
    required String parentDocumentId,
    required String fileName,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       sourcePath = Value(sourcePath),
       rootUri = Value(rootUri),
       parentDocumentId = Value(parentDocumentId),
       fileName = Value(fileName),
       createdAt = Value(createdAt);
  static Insertable<PendingRecording> custom({
    Expression<String>? operationId,
    Expression<String>? sourcePath,
    Expression<String>? temporaryPath,
    Expression<String>? rootUri,
    Expression<String>? parentDocumentId,
    Expression<String>? fileName,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (sourcePath != null) 'source_path': sourcePath,
      if (temporaryPath != null) 'temporary_path': temporaryPath,
      if (rootUri != null) 'root_uri': rootUri,
      if (parentDocumentId != null) 'parent_document_id': parentDocumentId,
      if (fileName != null) 'file_name': fileName,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingRecordingsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? sourcePath,
    Value<String?>? temporaryPath,
    Value<String>? rootUri,
    Value<String>? parentDocumentId,
    Value<String>? fileName,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingRecordingsCompanion(
      operationId: operationId ?? this.operationId,
      sourcePath: sourcePath ?? this.sourcePath,
      temporaryPath: temporaryPath ?? this.temporaryPath,
      rootUri: rootUri ?? this.rootUri,
      parentDocumentId: parentDocumentId ?? this.parentDocumentId,
      fileName: fileName ?? this.fileName,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (temporaryPath.present) {
      map['temporary_path'] = Variable<String>(temporaryPath.value);
    }
    if (rootUri.present) {
      map['root_uri'] = Variable<String>(rootUri.value);
    }
    if (parentDocumentId.present) {
      map['parent_document_id'] = Variable<String>(parentDocumentId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingRecordingsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('temporaryPath: $temporaryPath, ')
          ..write('rootUri: $rootUri, ')
          ..write('parentDocumentId: $parentDocumentId, ')
          ..write('fileName: $fileName, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $EntryMetadataTable entryMetadata = $EntryMetadataTable(this);
  late final $PendingRecordingsTable pendingRecordings =
      $PendingRecordingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    entryMetadata,
    pendingRecordings,
  ];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String?> rootUri,
      Value<bool> audioEnabled,
      Value<String> sortField,
      Value<bool> sortDescending,
      required DateTime updatedAt,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String?> rootUri,
      Value<bool> audioEnabled,
      Value<String> sortField,
      Value<bool> sortDescending,
      Value<DateTime> updatedAt,
    });

class $$AppSettingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
    column: $state.table.id,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get rootUri => $state.composableBuilder(
    column: $state.table.rootUri,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<bool> get audioEnabled => $state.composableBuilder(
    column: $state.table.audioEnabled,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get sortField => $state.composableBuilder(
    column: $state.table.sortField,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<bool> get sortDescending => $state.composableBuilder(
    column: $state.table.sortDescending,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
    column: $state.table.updatedAt,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );
}

class $$AppSettingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
    column: $state.table.id,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get rootUri => $state.composableBuilder(
    column: $state.table.rootUri,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<bool> get audioEnabled => $state.composableBuilder(
    column: $state.table.audioEnabled,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get sortField => $state.composableBuilder(
    column: $state.table.sortField,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<bool> get sortDescending => $state.composableBuilder(
    column: $state.table.sortDescending,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
    column: $state.table.updatedAt,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
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
          filteringComposer: $$AppSettingsTableFilterComposer(
            ComposerState(db, table),
          ),
          orderingComposer: $$AppSettingsTableOrderingComposer(
            ComposerState(db, table),
          ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> rootUri = const Value.absent(),
                Value<bool> audioEnabled = const Value.absent(),
                Value<String> sortField = const Value.absent(),
                Value<bool> sortDescending = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                rootUri: rootUri,
                audioEnabled: audioEnabled,
                sortField: sortField,
                sortDescending: sortDescending,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> rootUri = const Value.absent(),
                Value<bool> audioEnabled = const Value.absent(),
                Value<String> sortField = const Value.absent(),
                Value<bool> sortDescending = const Value.absent(),
                required DateTime updatedAt,
              }) => AppSettingsCompanion.insert(
                id: id,
                rootUri: rootUri,
                audioEnabled: audioEnabled,
                sortField: sortField,
                sortDescending: sortDescending,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$EntryMetadataTableCreateCompanionBuilder =
    EntryMetadataCompanion Function({
      required String uri,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$EntryMetadataTableUpdateCompanionBuilder =
    EntryMetadataCompanion Function({
      Value<String> uri,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$EntryMetadataTableFilterComposer
    extends FilterComposer<_$AppDatabase, $EntryMetadataTable> {
  $$EntryMetadataTableFilterComposer(super.$state);
  ColumnFilters<String> get uri => $state.composableBuilder(
    column: $state.table.uri,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
    column: $state.table.createdAt,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );
}

class $$EntryMetadataTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $EntryMetadataTable> {
  $$EntryMetadataTableOrderingComposer(super.$state);
  ColumnOrderings<String> get uri => $state.composableBuilder(
    column: $state.table.uri,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
    column: $state.table.createdAt,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );
}

class $$EntryMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntryMetadataTable,
          EntryMetadataData,
          $$EntryMetadataTableFilterComposer,
          $$EntryMetadataTableOrderingComposer,
          $$EntryMetadataTableCreateCompanionBuilder,
          $$EntryMetadataTableUpdateCompanionBuilder,
          (
            EntryMetadataData,
            BaseReferences<
              _$AppDatabase,
              $EntryMetadataTable,
              EntryMetadataData
            >,
          ),
          EntryMetadataData,
          PrefetchHooks Function()
        > {
  $$EntryMetadataTableTableManager(_$AppDatabase db, $EntryMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$EntryMetadataTableFilterComposer(
            ComposerState(db, table),
          ),
          orderingComposer: $$EntryMetadataTableOrderingComposer(
            ComposerState(db, table),
          ),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryMetadataCompanion(
                uri: uri,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EntryMetadataCompanion.insert(
                uri: uri,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntryMetadataTable,
      EntryMetadataData,
      $$EntryMetadataTableFilterComposer,
      $$EntryMetadataTableOrderingComposer,
      $$EntryMetadataTableCreateCompanionBuilder,
      $$EntryMetadataTableUpdateCompanionBuilder,
      (
        EntryMetadataData,
        BaseReferences<_$AppDatabase, $EntryMetadataTable, EntryMetadataData>,
      ),
      EntryMetadataData,
      PrefetchHooks Function()
    >;
typedef $$PendingRecordingsTableCreateCompanionBuilder =
    PendingRecordingsCompanion Function({
      required String operationId,
      required String sourcePath,
      Value<String?> temporaryPath,
      required String rootUri,
      required String parentDocumentId,
      required String fileName,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingRecordingsTableUpdateCompanionBuilder =
    PendingRecordingsCompanion Function({
      Value<String> operationId,
      Value<String> sourcePath,
      Value<String?> temporaryPath,
      Value<String> rootUri,
      Value<String> parentDocumentId,
      Value<String> fileName,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingRecordingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $PendingRecordingsTable> {
  $$PendingRecordingsTableFilterComposer(super.$state);
  ColumnFilters<String> get operationId => $state.composableBuilder(
    column: $state.table.operationId,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get sourcePath => $state.composableBuilder(
    column: $state.table.sourcePath,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get temporaryPath => $state.composableBuilder(
    column: $state.table.temporaryPath,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get rootUri => $state.composableBuilder(
    column: $state.table.rootUri,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get parentDocumentId => $state.composableBuilder(
    column: $state.table.parentDocumentId,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get fileName => $state.composableBuilder(
    column: $state.table.fileName,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
    column: $state.table.createdAt,
    builder: (column, joinBuilders) =>
        ColumnFilters(column, joinBuilders: joinBuilders),
  );
}

class $$PendingRecordingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $PendingRecordingsTable> {
  $$PendingRecordingsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get operationId => $state.composableBuilder(
    column: $state.table.operationId,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get sourcePath => $state.composableBuilder(
    column: $state.table.sourcePath,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get temporaryPath => $state.composableBuilder(
    column: $state.table.temporaryPath,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get rootUri => $state.composableBuilder(
    column: $state.table.rootUri,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get parentDocumentId => $state.composableBuilder(
    column: $state.table.parentDocumentId,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get fileName => $state.composableBuilder(
    column: $state.table.fileName,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
    column: $state.table.createdAt,
    builder: (column, joinBuilders) =>
        ColumnOrderings(column, joinBuilders: joinBuilders),
  );
}

class $$PendingRecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingRecordingsTable,
          PendingRecording,
          $$PendingRecordingsTableFilterComposer,
          $$PendingRecordingsTableOrderingComposer,
          $$PendingRecordingsTableCreateCompanionBuilder,
          $$PendingRecordingsTableUpdateCompanionBuilder,
          (
            PendingRecording,
            BaseReferences<
              _$AppDatabase,
              $PendingRecordingsTable,
              PendingRecording
            >,
          ),
          PendingRecording,
          PrefetchHooks Function()
        > {
  $$PendingRecordingsTableTableManager(
    _$AppDatabase db,
    $PendingRecordingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$PendingRecordingsTableFilterComposer(
            ComposerState(db, table),
          ),
          orderingComposer: $$PendingRecordingsTableOrderingComposer(
            ComposerState(db, table),
          ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String?> temporaryPath = const Value.absent(),
                Value<String> rootUri = const Value.absent(),
                Value<String> parentDocumentId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingRecordingsCompanion(
                operationId: operationId,
                sourcePath: sourcePath,
                temporaryPath: temporaryPath,
                rootUri: rootUri,
                parentDocumentId: parentDocumentId,
                fileName: fileName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String sourcePath,
                Value<String?> temporaryPath = const Value.absent(),
                required String rootUri,
                required String parentDocumentId,
                required String fileName,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingRecordingsCompanion.insert(
                operationId: operationId,
                sourcePath: sourcePath,
                temporaryPath: temporaryPath,
                rootUri: rootUri,
                parentDocumentId: parentDocumentId,
                fileName: fileName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingRecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingRecordingsTable,
      PendingRecording,
      $$PendingRecordingsTableFilterComposer,
      $$PendingRecordingsTableOrderingComposer,
      $$PendingRecordingsTableCreateCompanionBuilder,
      $$PendingRecordingsTableUpdateCompanionBuilder,
      (
        PendingRecording,
        BaseReferences<
          _$AppDatabase,
          $PendingRecordingsTable,
          PendingRecording
        >,
      ),
      PendingRecording,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$EntryMetadataTableTableManager get entryMetadata =>
      $$EntryMetadataTableTableManager(_db, _db.entryMetadata);
  $$PendingRecordingsTableTableManager get pendingRecordings =>
      $$PendingRecordingsTableTableManager(_db, _db.pendingRecordings);
}
