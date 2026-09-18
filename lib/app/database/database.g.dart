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
  final String sortField;
  final bool sortDescending;
  final DateTime updatedAt;
  const AppSetting({
    required this.id,
    this.rootUri,
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
      'sortField': serializer.toJson<String>(sortField),
      'sortDescending': serializer.toJson<bool>(sortDescending),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({
    int? id,
    Value<String?> rootUri = const Value.absent(),
    String? sortField,
    bool? sortDescending,
    DateTime? updatedAt,
  }) => AppSetting(
    id: id ?? this.id,
    rootUri: rootUri.present ? rootUri.value : this.rootUri,
    sortField: sortField ?? this.sortField,
    sortDescending: sortDescending ?? this.sortDescending,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      rootUri: data.rootUri.present ? data.rootUri.value : this.rootUri,
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
          ..write('sortField: $sortField, ')
          ..write('sortDescending: $sortDescending, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, rootUri, sortField, sortDescending, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.rootUri == this.rootUri &&
          other.sortField == this.sortField &&
          other.sortDescending == this.sortDescending &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String?> rootUri;
  final Value<String> sortField;
  final Value<bool> sortDescending;
  final Value<DateTime> updatedAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.sortField = const Value.absent(),
    this.sortDescending = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.sortField = const Value.absent(),
    this.sortDescending = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? rootUri,
    Expression<String>? sortField,
    Expression<bool>? sortDescending,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootUri != null) 'root_uri': rootUri,
      if (sortField != null) 'sort_field': sortField,
      if (sortDescending != null) 'sort_descending': sortDescending,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? rootUri,
    Value<String>? sortField,
    Value<bool>? sortDescending,
    Value<DateTime>? updatedAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      rootUri: rootUri ?? this.rootUri,
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $EntryMetadataTable entryMetadata = $EntryMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    entryMetadata,
  ];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String?> rootUri,
      Value<String> sortField,
      Value<bool> sortDescending,
      required DateTime updatedAt,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String?> rootUri,
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
                Value<String> sortField = const Value.absent(),
                Value<bool> sortDescending = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                rootUri: rootUri,
                sortField: sortField,
                sortDescending: sortDescending,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> rootUri = const Value.absent(),
                Value<String> sortField = const Value.absent(),
                Value<bool> sortDescending = const Value.absent(),
                required DateTime updatedAt,
              }) => AppSettingsCompanion.insert(
                id: id,
                rootUri: rootUri,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$EntryMetadataTableTableManager get entryMetadata =>
      $$EntryMetadataTableTableManager(_db, _db.entryMetadata);
}
