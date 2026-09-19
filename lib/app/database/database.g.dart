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
  static const VerificationMeta _themeSchemeMeta = const VerificationMeta(
    'themeScheme',
  );
  @override
  late final GeneratedColumn<String> themeScheme = GeneratedColumn<String>(
    'theme_scheme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultThemeSchemeName),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultThemeModeName),
  );
  static const VerificationMeta _textFontSizeMeta = const VerificationMeta(
    'textFontSize',
  );
  @override
  late final GeneratedColumn<double> textFontSize = GeneratedColumn<double>(
    'text_font_size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultTextFontSize),
  );
  static const VerificationMeta _textWrapMeta = const VerificationMeta(
    'textWrap',
  );
  @override
  late final GeneratedColumn<bool> textWrap = GeneratedColumn<bool>(
    'text_wrap',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("text_wrap" IN (0, 1))',
    ),
    defaultValue: const Constant(kDefaultTextWrap),
  );
  static const VerificationMeta _markdownModeMeta = const VerificationMeta(
    'markdownMode',
  );
  @override
  late final GeneratedColumn<String> markdownMode = GeneratedColumn<String>(
    'markdown_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultMarkdownMode),
  );
  static const VerificationMeta _showLineNumbersMeta = const VerificationMeta(
    'showLineNumbers',
  );
  @override
  late final GeneratedColumn<bool> showLineNumbers = GeneratedColumn<bool>(
    'show_line_numbers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_line_numbers" IN (0, 1))',
    ),
    defaultValue: const Constant(kDefaultShowLineNumbers),
  );
  static const VerificationMeta _editorTabWidthMeta = const VerificationMeta(
    'editorTabWidth',
  );
  @override
  late final GeneratedColumn<int> editorTabWidth = GeneratedColumn<int>(
    'editor_tab_width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultEditorTabWidth),
  );
  static const VerificationMeta _editorAutoIndentMeta = const VerificationMeta(
    'editorAutoIndent',
  );
  @override
  late final GeneratedColumn<bool> editorAutoIndent = GeneratedColumn<bool>(
    'editor_auto_indent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("editor_auto_indent" IN (0, 1))',
    ),
    defaultValue: const Constant(kDefaultEditorAutoIndent),
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
    themeScheme,
    themeMode,
    textFontSize,
    textWrap,
    markdownMode,
    showLineNumbers,
    editorTabWidth,
    editorAutoIndent,
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
    if (data.containsKey('theme_scheme')) {
      context.handle(
        _themeSchemeMeta,
        themeScheme.isAcceptableOrUnknown(
          data['theme_scheme']!,
          _themeSchemeMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('text_font_size')) {
      context.handle(
        _textFontSizeMeta,
        textFontSize.isAcceptableOrUnknown(
          data['text_font_size']!,
          _textFontSizeMeta,
        ),
      );
    }
    if (data.containsKey('text_wrap')) {
      context.handle(
        _textWrapMeta,
        textWrap.isAcceptableOrUnknown(data['text_wrap']!, _textWrapMeta),
      );
    }
    if (data.containsKey('markdown_mode')) {
      context.handle(
        _markdownModeMeta,
        markdownMode.isAcceptableOrUnknown(
          data['markdown_mode']!,
          _markdownModeMeta,
        ),
      );
    }
    if (data.containsKey('show_line_numbers')) {
      context.handle(
        _showLineNumbersMeta,
        showLineNumbers.isAcceptableOrUnknown(
          data['show_line_numbers']!,
          _showLineNumbersMeta,
        ),
      );
    }
    if (data.containsKey('editor_tab_width')) {
      context.handle(
        _editorTabWidthMeta,
        editorTabWidth.isAcceptableOrUnknown(
          data['editor_tab_width']!,
          _editorTabWidthMeta,
        ),
      );
    }
    if (data.containsKey('editor_auto_indent')) {
      context.handle(
        _editorAutoIndentMeta,
        editorAutoIndent.isAcceptableOrUnknown(
          data['editor_auto_indent']!,
          _editorAutoIndentMeta,
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
      themeScheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_scheme'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      textFontSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}text_font_size'],
      )!,
      textWrap: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}text_wrap'],
      )!,
      markdownMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown_mode'],
      )!,
      showLineNumbers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_line_numbers'],
      )!,
      editorTabWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}editor_tab_width'],
      )!,
      editorAutoIndent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}editor_auto_indent'],
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

  /// 当前配色方案名称；对应 FlexScheme 枚举的 name。
  final String themeScheme;

  /// 当前外观模式名称；system / light / dark。
  final String themeMode;

  /// 文本/代码预览字号（逻辑像素）。
  final double textFontSize;

  /// 文本预览是否自动换行；关闭时改为横向滚动。
  final bool textWrap;

  /// Markdown 展示模式；read（阅读）或 source（源码）。
  final String markdownMode;

  /// 代码预览与编辑器是否显示行号。
  final bool showLineNumbers;

  /// 编辑器 Tab 缩进宽度（空格数）。
  final int editorTabWidth;

  /// 编辑器是否启用自动缩进。
  final bool editorAutoIndent;
  final DateTime updatedAt;
  const AppSetting({
    required this.id,
    this.rootUri,
    required this.sortField,
    required this.sortDescending,
    required this.themeScheme,
    required this.themeMode,
    required this.textFontSize,
    required this.textWrap,
    required this.markdownMode,
    required this.showLineNumbers,
    required this.editorTabWidth,
    required this.editorAutoIndent,
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
    map['theme_scheme'] = Variable<String>(themeScheme);
    map['theme_mode'] = Variable<String>(themeMode);
    map['text_font_size'] = Variable<double>(textFontSize);
    map['text_wrap'] = Variable<bool>(textWrap);
    map['markdown_mode'] = Variable<String>(markdownMode);
    map['show_line_numbers'] = Variable<bool>(showLineNumbers);
    map['editor_tab_width'] = Variable<int>(editorTabWidth);
    map['editor_auto_indent'] = Variable<bool>(editorAutoIndent);
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
      themeScheme: Value(themeScheme),
      themeMode: Value(themeMode),
      textFontSize: Value(textFontSize),
      textWrap: Value(textWrap),
      markdownMode: Value(markdownMode),
      showLineNumbers: Value(showLineNumbers),
      editorTabWidth: Value(editorTabWidth),
      editorAutoIndent: Value(editorAutoIndent),
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
      themeScheme: serializer.fromJson<String>(json['themeScheme']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      textFontSize: serializer.fromJson<double>(json['textFontSize']),
      textWrap: serializer.fromJson<bool>(json['textWrap']),
      markdownMode: serializer.fromJson<String>(json['markdownMode']),
      showLineNumbers: serializer.fromJson<bool>(json['showLineNumbers']),
      editorTabWidth: serializer.fromJson<int>(json['editorTabWidth']),
      editorAutoIndent: serializer.fromJson<bool>(json['editorAutoIndent']),
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
      'themeScheme': serializer.toJson<String>(themeScheme),
      'themeMode': serializer.toJson<String>(themeMode),
      'textFontSize': serializer.toJson<double>(textFontSize),
      'textWrap': serializer.toJson<bool>(textWrap),
      'markdownMode': serializer.toJson<String>(markdownMode),
      'showLineNumbers': serializer.toJson<bool>(showLineNumbers),
      'editorTabWidth': serializer.toJson<int>(editorTabWidth),
      'editorAutoIndent': serializer.toJson<bool>(editorAutoIndent),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({
    int? id,
    Value<String?> rootUri = const Value.absent(),
    String? sortField,
    bool? sortDescending,
    String? themeScheme,
    String? themeMode,
    double? textFontSize,
    bool? textWrap,
    String? markdownMode,
    bool? showLineNumbers,
    int? editorTabWidth,
    bool? editorAutoIndent,
    DateTime? updatedAt,
  }) => AppSetting(
    id: id ?? this.id,
    rootUri: rootUri.present ? rootUri.value : this.rootUri,
    sortField: sortField ?? this.sortField,
    sortDescending: sortDescending ?? this.sortDescending,
    themeScheme: themeScheme ?? this.themeScheme,
    themeMode: themeMode ?? this.themeMode,
    textFontSize: textFontSize ?? this.textFontSize,
    textWrap: textWrap ?? this.textWrap,
    markdownMode: markdownMode ?? this.markdownMode,
    showLineNumbers: showLineNumbers ?? this.showLineNumbers,
    editorTabWidth: editorTabWidth ?? this.editorTabWidth,
    editorAutoIndent: editorAutoIndent ?? this.editorAutoIndent,
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
      themeScheme: data.themeScheme.present
          ? data.themeScheme.value
          : this.themeScheme,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      textFontSize: data.textFontSize.present
          ? data.textFontSize.value
          : this.textFontSize,
      textWrap: data.textWrap.present ? data.textWrap.value : this.textWrap,
      markdownMode: data.markdownMode.present
          ? data.markdownMode.value
          : this.markdownMode,
      showLineNumbers: data.showLineNumbers.present
          ? data.showLineNumbers.value
          : this.showLineNumbers,
      editorTabWidth: data.editorTabWidth.present
          ? data.editorTabWidth.value
          : this.editorTabWidth,
      editorAutoIndent: data.editorAutoIndent.present
          ? data.editorAutoIndent.value
          : this.editorAutoIndent,
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
          ..write('themeScheme: $themeScheme, ')
          ..write('themeMode: $themeMode, ')
          ..write('textFontSize: $textFontSize, ')
          ..write('textWrap: $textWrap, ')
          ..write('markdownMode: $markdownMode, ')
          ..write('showLineNumbers: $showLineNumbers, ')
          ..write('editorTabWidth: $editorTabWidth, ')
          ..write('editorAutoIndent: $editorAutoIndent, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rootUri,
    sortField,
    sortDescending,
    themeScheme,
    themeMode,
    textFontSize,
    textWrap,
    markdownMode,
    showLineNumbers,
    editorTabWidth,
    editorAutoIndent,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.rootUri == this.rootUri &&
          other.sortField == this.sortField &&
          other.sortDescending == this.sortDescending &&
          other.themeScheme == this.themeScheme &&
          other.themeMode == this.themeMode &&
          other.textFontSize == this.textFontSize &&
          other.textWrap == this.textWrap &&
          other.markdownMode == this.markdownMode &&
          other.showLineNumbers == this.showLineNumbers &&
          other.editorTabWidth == this.editorTabWidth &&
          other.editorAutoIndent == this.editorAutoIndent &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String?> rootUri;
  final Value<String> sortField;
  final Value<bool> sortDescending;
  final Value<String> themeScheme;
  final Value<String> themeMode;
  final Value<double> textFontSize;
  final Value<bool> textWrap;
  final Value<String> markdownMode;
  final Value<bool> showLineNumbers;
  final Value<int> editorTabWidth;
  final Value<bool> editorAutoIndent;
  final Value<DateTime> updatedAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.sortField = const Value.absent(),
    this.sortDescending = const Value.absent(),
    this.themeScheme = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.textFontSize = const Value.absent(),
    this.textWrap = const Value.absent(),
    this.markdownMode = const Value.absent(),
    this.showLineNumbers = const Value.absent(),
    this.editorTabWidth = const Value.absent(),
    this.editorAutoIndent = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.rootUri = const Value.absent(),
    this.sortField = const Value.absent(),
    this.sortDescending = const Value.absent(),
    this.themeScheme = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.textFontSize = const Value.absent(),
    this.textWrap = const Value.absent(),
    this.markdownMode = const Value.absent(),
    this.showLineNumbers = const Value.absent(),
    this.editorTabWidth = const Value.absent(),
    this.editorAutoIndent = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? rootUri,
    Expression<String>? sortField,
    Expression<bool>? sortDescending,
    Expression<String>? themeScheme,
    Expression<String>? themeMode,
    Expression<double>? textFontSize,
    Expression<bool>? textWrap,
    Expression<String>? markdownMode,
    Expression<bool>? showLineNumbers,
    Expression<int>? editorTabWidth,
    Expression<bool>? editorAutoIndent,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootUri != null) 'root_uri': rootUri,
      if (sortField != null) 'sort_field': sortField,
      if (sortDescending != null) 'sort_descending': sortDescending,
      if (themeScheme != null) 'theme_scheme': themeScheme,
      if (themeMode != null) 'theme_mode': themeMode,
      if (textFontSize != null) 'text_font_size': textFontSize,
      if (textWrap != null) 'text_wrap': textWrap,
      if (markdownMode != null) 'markdown_mode': markdownMode,
      if (showLineNumbers != null) 'show_line_numbers': showLineNumbers,
      if (editorTabWidth != null) 'editor_tab_width': editorTabWidth,
      if (editorAutoIndent != null) 'editor_auto_indent': editorAutoIndent,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? rootUri,
    Value<String>? sortField,
    Value<bool>? sortDescending,
    Value<String>? themeScheme,
    Value<String>? themeMode,
    Value<double>? textFontSize,
    Value<bool>? textWrap,
    Value<String>? markdownMode,
    Value<bool>? showLineNumbers,
    Value<int>? editorTabWidth,
    Value<bool>? editorAutoIndent,
    Value<DateTime>? updatedAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      rootUri: rootUri ?? this.rootUri,
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
      themeScheme: themeScheme ?? this.themeScheme,
      themeMode: themeMode ?? this.themeMode,
      textFontSize: textFontSize ?? this.textFontSize,
      textWrap: textWrap ?? this.textWrap,
      markdownMode: markdownMode ?? this.markdownMode,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      editorTabWidth: editorTabWidth ?? this.editorTabWidth,
      editorAutoIndent: editorAutoIndent ?? this.editorAutoIndent,
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
    if (themeScheme.present) {
      map['theme_scheme'] = Variable<String>(themeScheme.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (textFontSize.present) {
      map['text_font_size'] = Variable<double>(textFontSize.value);
    }
    if (textWrap.present) {
      map['text_wrap'] = Variable<bool>(textWrap.value);
    }
    if (markdownMode.present) {
      map['markdown_mode'] = Variable<String>(markdownMode.value);
    }
    if (showLineNumbers.present) {
      map['show_line_numbers'] = Variable<bool>(showLineNumbers.value);
    }
    if (editorTabWidth.present) {
      map['editor_tab_width'] = Variable<int>(editorTabWidth.value);
    }
    if (editorAutoIndent.present) {
      map['editor_auto_indent'] = Variable<bool>(editorAutoIndent.value);
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
          ..write('themeScheme: $themeScheme, ')
          ..write('themeMode: $themeMode, ')
          ..write('textFontSize: $textFontSize, ')
          ..write('textWrap: $textWrap, ')
          ..write('markdownMode: $markdownMode, ')
          ..write('showLineNumbers: $showLineNumbers, ')
          ..write('editorTabWidth: $editorTabWidth, ')
          ..write('editorAutoIndent: $editorAutoIndent, ')
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

class $PlaybackProgressTable extends PlaybackProgress
    with TableInfo<$PlaybackProgressTable, PlaybackProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    uri,
    positionMs,
    durationMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackProgressData> instance, {
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
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
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
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  PlaybackProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackProgressData(
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackProgressTable createAlias(String alias) {
    return $PlaybackProgressTable(attachedDatabase, alias);
  }
}

class PlaybackProgressData extends DataClass
    implements Insertable<PlaybackProgressData> {
  final String uri;

  /// 已播放位置（毫秒）。
  final int positionMs;

  /// 内容总时长（毫秒）；未知时为 0。
  final int durationMs;
  final DateTime updatedAt;
  const PlaybackProgressData({
    required this.uri,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackProgressCompanion toCompanion(bool nullToAbsent) {
    return PlaybackProgressCompanion(
      uri: Value(uri),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackProgressData(
      uri: serializer.fromJson<String>(json['uri']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackProgressData copyWith({
    String? uri,
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
  }) => PlaybackProgressData(
    uri: uri ?? this.uri,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackProgressData copyWithCompanion(PlaybackProgressCompanion data) {
    return PlaybackProgressData(
      uri: data.uri.present ? data.uri.value : this.uri,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressData(')
          ..write('uri: $uri, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uri, positionMs, durationMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackProgressData &&
          other.uri == this.uri &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.updatedAt == this.updatedAt);
}

class PlaybackProgressCompanion extends UpdateCompanion<PlaybackProgressData> {
  final Value<String> uri;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackProgressCompanion({
    this.uri = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackProgressCompanion.insert({
    required String uri,
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       updatedAt = Value(updatedAt);
  static Insertable<PlaybackProgressData> custom({
    Expression<String>? uri,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackProgressCompanion copyWith({
    Value<String>? uri,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaybackProgressCompanion(
      uri: uri ?? this.uri,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressCompanion(')
          ..write('uri: $uri, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $PlaybackProgressTable playbackProgress = $PlaybackProgressTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    entryMetadata,
    playbackProgress,
  ];
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String?> rootUri,
      Value<String> sortField,
      Value<bool> sortDescending,
      Value<String> themeScheme,
      Value<String> themeMode,
      Value<double> textFontSize,
      Value<bool> textWrap,
      Value<String> markdownMode,
      Value<bool> showLineNumbers,
      Value<int> editorTabWidth,
      Value<bool> editorAutoIndent,
      required DateTime updatedAt,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String?> rootUri,
      Value<String> sortField,
      Value<bool> sortDescending,
      Value<String> themeScheme,
      Value<String> themeMode,
      Value<double> textFontSize,
      Value<bool> textWrap,
      Value<String> markdownMode,
      Value<bool> showLineNumbers,
      Value<int> editorTabWidth,
      Value<bool> editorAutoIndent,
      Value<DateTime> updatedAt,
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootUri => $composableBuilder(
    column: $table.rootUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortField => $composableBuilder(
    column: $table.sortField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sortDescending => $composableBuilder(
    column: $table.sortDescending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeScheme => $composableBuilder(
    column: $table.themeScheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get textFontSize => $composableBuilder(
    column: $table.textFontSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get textWrap => $composableBuilder(
    column: $table.textWrap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markdownMode => $composableBuilder(
    column: $table.markdownMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showLineNumbers => $composableBuilder(
    column: $table.showLineNumbers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editorTabWidth => $composableBuilder(
    column: $table.editorTabWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get editorAutoIndent => $composableBuilder(
    column: $table.editorAutoIndent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootUri => $composableBuilder(
    column: $table.rootUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortField => $composableBuilder(
    column: $table.sortField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sortDescending => $composableBuilder(
    column: $table.sortDescending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeScheme => $composableBuilder(
    column: $table.themeScheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get textFontSize => $composableBuilder(
    column: $table.textFontSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get textWrap => $composableBuilder(
    column: $table.textWrap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markdownMode => $composableBuilder(
    column: $table.markdownMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showLineNumbers => $composableBuilder(
    column: $table.showLineNumbers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editorTabWidth => $composableBuilder(
    column: $table.editorTabWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get editorAutoIndent => $composableBuilder(
    column: $table.editorAutoIndent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rootUri =>
      $composableBuilder(column: $table.rootUri, builder: (column) => column);

  GeneratedColumn<String> get sortField =>
      $composableBuilder(column: $table.sortField, builder: (column) => column);

  GeneratedColumn<bool> get sortDescending => $composableBuilder(
    column: $table.sortDescending,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeScheme => $composableBuilder(
    column: $table.themeScheme,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<double> get textFontSize => $composableBuilder(
    column: $table.textFontSize,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get textWrap =>
      $composableBuilder(column: $table.textWrap, builder: (column) => column);

  GeneratedColumn<String> get markdownMode => $composableBuilder(
    column: $table.markdownMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showLineNumbers => $composableBuilder(
    column: $table.showLineNumbers,
    builder: (column) => column,
  );

  GeneratedColumn<int> get editorTabWidth => $composableBuilder(
    column: $table.editorTabWidth,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get editorAutoIndent => $composableBuilder(
    column: $table.editorAutoIndent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
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
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> rootUri = const Value.absent(),
                Value<String> sortField = const Value.absent(),
                Value<bool> sortDescending = const Value.absent(),
                Value<String> themeScheme = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<double> textFontSize = const Value.absent(),
                Value<bool> textWrap = const Value.absent(),
                Value<String> markdownMode = const Value.absent(),
                Value<bool> showLineNumbers = const Value.absent(),
                Value<int> editorTabWidth = const Value.absent(),
                Value<bool> editorAutoIndent = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                rootUri: rootUri,
                sortField: sortField,
                sortDescending: sortDescending,
                themeScheme: themeScheme,
                themeMode: themeMode,
                textFontSize: textFontSize,
                textWrap: textWrap,
                markdownMode: markdownMode,
                showLineNumbers: showLineNumbers,
                editorTabWidth: editorTabWidth,
                editorAutoIndent: editorAutoIndent,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> rootUri = const Value.absent(),
                Value<String> sortField = const Value.absent(),
                Value<bool> sortDescending = const Value.absent(),
                Value<String> themeScheme = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<double> textFontSize = const Value.absent(),
                Value<bool> textWrap = const Value.absent(),
                Value<String> markdownMode = const Value.absent(),
                Value<bool> showLineNumbers = const Value.absent(),
                Value<int> editorTabWidth = const Value.absent(),
                Value<bool> editorAutoIndent = const Value.absent(),
                required DateTime updatedAt,
              }) => AppSettingsCompanion.insert(
                id: id,
                rootUri: rootUri,
                sortField: sortField,
                sortDescending: sortDescending,
                themeScheme: themeScheme,
                themeMode: themeMode,
                textFontSize: textFontSize,
                textWrap: textWrap,
                markdownMode: markdownMode,
                showLineNumbers: showLineNumbers,
                editorTabWidth: editorTabWidth,
                editorAutoIndent: editorAutoIndent,
                updatedAt: updatedAt,
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
    extends Composer<_$AppDatabase, $EntryMetadataTable> {
  $$EntryMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $EntryMetadataTable> {
  $$EntryMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntryMetadataTable> {
  $$EntryMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EntryMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntryMetadataTable,
          EntryMetadataData,
          $$EntryMetadataTableFilterComposer,
          $$EntryMetadataTableOrderingComposer,
          $$EntryMetadataTableAnnotationComposer,
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
          createFilteringComposer: () =>
              $$EntryMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryMetadataTableAnnotationComposer($db: db, $table: table),
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
              .map(
                (e) => (
                  e.readTable<$EntryMetadataTable, EntryMetadataData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EntryMetadataTable,
                    EntryMetadataData
                  >(db, table, e),
                ),
              )
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
      $$EntryMetadataTableAnnotationComposer,
      $$EntryMetadataTableCreateCompanionBuilder,
      $$EntryMetadataTableUpdateCompanionBuilder,
      (
        EntryMetadataData,
        BaseReferences<_$AppDatabase, $EntryMetadataTable, EntryMetadataData>,
      ),
      EntryMetadataData,
      PrefetchHooks Function()
    >;
typedef $$PlaybackProgressTableCreateCompanionBuilder =
    PlaybackProgressCompanion Function({
      required String uri,
      Value<int> positionMs,
      Value<int> durationMs,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlaybackProgressTableUpdateCompanionBuilder =
    PlaybackProgressCompanion Function({
      Value<String> uri,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PlaybackProgressTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackProgressTable,
          PlaybackProgressData,
          $$PlaybackProgressTableFilterComposer,
          $$PlaybackProgressTableOrderingComposer,
          $$PlaybackProgressTableAnnotationComposer,
          $$PlaybackProgressTableCreateCompanionBuilder,
          $$PlaybackProgressTableUpdateCompanionBuilder,
          (
            PlaybackProgressData,
            BaseReferences<
              _$AppDatabase,
              $PlaybackProgressTable,
              PlaybackProgressData
            >,
          ),
          PlaybackProgressData,
          PrefetchHooks Function()
        > {
  $$PlaybackProgressTableTableManager(
    _$AppDatabase db,
    $PlaybackProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressCompanion(
                uri: uri,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressCompanion.insert(
                uri: uri,
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackProgressTable, PlaybackProgressData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PlaybackProgressTable,
                    PlaybackProgressData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackProgressTable,
      PlaybackProgressData,
      $$PlaybackProgressTableFilterComposer,
      $$PlaybackProgressTableOrderingComposer,
      $$PlaybackProgressTableAnnotationComposer,
      $$PlaybackProgressTableCreateCompanionBuilder,
      $$PlaybackProgressTableUpdateCompanionBuilder,
      (
        PlaybackProgressData,
        BaseReferences<
          _$AppDatabase,
          $PlaybackProgressTable,
          PlaybackProgressData
        >,
      ),
      PlaybackProgressData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$EntryMetadataTableTableManager get entryMetadata =>
      $$EntryMetadataTableTableManager(_db, _db.entryMetadata);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(_db, _db.playbackProgress);
}
