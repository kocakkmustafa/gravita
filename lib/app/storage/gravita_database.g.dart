// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gravita_database.dart';

// ignore_for_file: type=lint
class $SessionIndexEntriesTable extends SessionIndexEntries
    with TableInfo<$SessionIndexEntriesTable, SessionIndexEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionIndexEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workedSecondsMeta = const VerificationMeta(
    'workedSeconds',
  );
  @override
  late final GeneratedColumn<int> workedSeconds = GeneratedColumn<int>(
    'worked_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitsCompletedMeta = const VerificationMeta(
    'unitsCompleted',
  );
  @override
  late final GeneratedColumn<int> unitsCompleted = GeneratedColumn<int>(
    'units_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedUnitsMeta = const VerificationMeta(
    'plannedUnits',
  );
  @override
  late final GeneratedColumn<int> plannedUnits = GeneratedColumn<int>(
    'planned_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitLabelMeta = const VerificationMeta(
    'unitLabel',
  );
  @override
  late final GeneratedColumn<String> unitLabel = GeneratedColumn<String>(
    'unit_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonClassMeta = const VerificationMeta(
    'lessonClass',
  );
  @override
  late final GeneratedColumn<String> lessonClass = GeneratedColumn<String>(
    'lesson_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unmeasuredUnitsMeta = const VerificationMeta(
    'unmeasuredUnits',
  );
  @override
  late final GeneratedColumn<int> unmeasuredUnits = GeneratedColumn<int>(
    'unmeasured_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unmeasuredReasonMeta = const VerificationMeta(
    'unmeasuredReason',
  );
  @override
  late final GeneratedColumn<String> unmeasuredReason = GeneratedColumn<String>(
    'unmeasured_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    completedAt,
    workedSeconds,
    unitsCompleted,
    plannedUnits,
    unitLabel,
    lessonClass,
    unmeasuredUnits,
    unmeasuredReason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_index_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionIndexEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('worked_seconds')) {
      context.handle(
        _workedSecondsMeta,
        workedSeconds.isAcceptableOrUnknown(
          data['worked_seconds']!,
          _workedSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workedSecondsMeta);
    }
    if (data.containsKey('units_completed')) {
      context.handle(
        _unitsCompletedMeta,
        unitsCompleted.isAcceptableOrUnknown(
          data['units_completed']!,
          _unitsCompletedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitsCompletedMeta);
    }
    if (data.containsKey('planned_units')) {
      context.handle(
        _plannedUnitsMeta,
        plannedUnits.isAcceptableOrUnknown(
          data['planned_units']!,
          _plannedUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedUnitsMeta);
    }
    if (data.containsKey('unit_label')) {
      context.handle(
        _unitLabelMeta,
        unitLabel.isAcceptableOrUnknown(data['unit_label']!, _unitLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_unitLabelMeta);
    }
    if (data.containsKey('lesson_class')) {
      context.handle(
        _lessonClassMeta,
        lessonClass.isAcceptableOrUnknown(
          data['lesson_class']!,
          _lessonClassMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lessonClassMeta);
    }
    if (data.containsKey('unmeasured_units')) {
      context.handle(
        _unmeasuredUnitsMeta,
        unmeasuredUnits.isAcceptableOrUnknown(
          data['unmeasured_units']!,
          _unmeasuredUnitsMeta,
        ),
      );
    }
    if (data.containsKey('unmeasured_reason')) {
      context.handle(
        _unmeasuredReasonMeta,
        unmeasuredReason.isAcceptableOrUnknown(
          data['unmeasured_reason']!,
          _unmeasuredReasonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SessionIndexEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionIndexEntry(
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      workedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worked_seconds'],
      )!,
      unitsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}units_completed'],
      )!,
      plannedUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_units'],
      )!,
      unitLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_label'],
      )!,
      lessonClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_class'],
      )!,
      unmeasuredUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unmeasured_units'],
      )!,
      unmeasuredReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unmeasured_reason'],
      ),
    );
  }

  @override
  $SessionIndexEntriesTable createAlias(String alias) {
    return $SessionIndexEntriesTable(attachedDatabase, alias);
  }
}

class SessionIndexEntry extends DataClass
    implements Insertable<SessionIndexEntry> {
  /// `SessionRecord.lessonId` — `movement:<id>` (serbest) ya da ders anahtarı.
  /// Kova AYRIMI burada YOK (aynı `content_repository.dart`nın kendi kuralı:
  /// kullanıcı için TEK bir geçmiş var), `lessonId`in ÖN EKİ zaten taşıyor.
  final String lessonId;
  final DateTime completedAt;
  final int workedSeconds;
  final int unitsCompleted;
  final int plannedUnits;
  final String unitLabel;
  final String lessonClass;
  final int unmeasuredUnits;
  final String? unmeasuredReason;
  const SessionIndexEntry({
    required this.lessonId,
    required this.completedAt,
    required this.workedSeconds,
    required this.unitsCompleted,
    required this.plannedUnits,
    required this.unitLabel,
    required this.lessonClass,
    required this.unmeasuredUnits,
    this.unmeasuredReason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<String>(lessonId);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['worked_seconds'] = Variable<int>(workedSeconds);
    map['units_completed'] = Variable<int>(unitsCompleted);
    map['planned_units'] = Variable<int>(plannedUnits);
    map['unit_label'] = Variable<String>(unitLabel);
    map['lesson_class'] = Variable<String>(lessonClass);
    map['unmeasured_units'] = Variable<int>(unmeasuredUnits);
    if (!nullToAbsent || unmeasuredReason != null) {
      map['unmeasured_reason'] = Variable<String>(unmeasuredReason);
    }
    return map;
  }

  SessionIndexEntriesCompanion toCompanion(bool nullToAbsent) {
    return SessionIndexEntriesCompanion(
      lessonId: Value(lessonId),
      completedAt: Value(completedAt),
      workedSeconds: Value(workedSeconds),
      unitsCompleted: Value(unitsCompleted),
      plannedUnits: Value(plannedUnits),
      unitLabel: Value(unitLabel),
      lessonClass: Value(lessonClass),
      unmeasuredUnits: Value(unmeasuredUnits),
      unmeasuredReason: unmeasuredReason == null && nullToAbsent
          ? const Value.absent()
          : Value(unmeasuredReason),
    );
  }

  factory SessionIndexEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionIndexEntry(
      lessonId: serializer.fromJson<String>(json['lessonId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      workedSeconds: serializer.fromJson<int>(json['workedSeconds']),
      unitsCompleted: serializer.fromJson<int>(json['unitsCompleted']),
      plannedUnits: serializer.fromJson<int>(json['plannedUnits']),
      unitLabel: serializer.fromJson<String>(json['unitLabel']),
      lessonClass: serializer.fromJson<String>(json['lessonClass']),
      unmeasuredUnits: serializer.fromJson<int>(json['unmeasuredUnits']),
      unmeasuredReason: serializer.fromJson<String?>(json['unmeasuredReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<String>(lessonId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'workedSeconds': serializer.toJson<int>(workedSeconds),
      'unitsCompleted': serializer.toJson<int>(unitsCompleted),
      'plannedUnits': serializer.toJson<int>(plannedUnits),
      'unitLabel': serializer.toJson<String>(unitLabel),
      'lessonClass': serializer.toJson<String>(lessonClass),
      'unmeasuredUnits': serializer.toJson<int>(unmeasuredUnits),
      'unmeasuredReason': serializer.toJson<String?>(unmeasuredReason),
    };
  }

  SessionIndexEntry copyWith({
    String? lessonId,
    DateTime? completedAt,
    int? workedSeconds,
    int? unitsCompleted,
    int? plannedUnits,
    String? unitLabel,
    String? lessonClass,
    int? unmeasuredUnits,
    Value<String?> unmeasuredReason = const Value.absent(),
  }) => SessionIndexEntry(
    lessonId: lessonId ?? this.lessonId,
    completedAt: completedAt ?? this.completedAt,
    workedSeconds: workedSeconds ?? this.workedSeconds,
    unitsCompleted: unitsCompleted ?? this.unitsCompleted,
    plannedUnits: plannedUnits ?? this.plannedUnits,
    unitLabel: unitLabel ?? this.unitLabel,
    lessonClass: lessonClass ?? this.lessonClass,
    unmeasuredUnits: unmeasuredUnits ?? this.unmeasuredUnits,
    unmeasuredReason: unmeasuredReason.present
        ? unmeasuredReason.value
        : this.unmeasuredReason,
  );
  SessionIndexEntry copyWithCompanion(SessionIndexEntriesCompanion data) {
    return SessionIndexEntry(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      workedSeconds: data.workedSeconds.present
          ? data.workedSeconds.value
          : this.workedSeconds,
      unitsCompleted: data.unitsCompleted.present
          ? data.unitsCompleted.value
          : this.unitsCompleted,
      plannedUnits: data.plannedUnits.present
          ? data.plannedUnits.value
          : this.plannedUnits,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      lessonClass: data.lessonClass.present
          ? data.lessonClass.value
          : this.lessonClass,
      unmeasuredUnits: data.unmeasuredUnits.present
          ? data.unmeasuredUnits.value
          : this.unmeasuredUnits,
      unmeasuredReason: data.unmeasuredReason.present
          ? data.unmeasuredReason.value
          : this.unmeasuredReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionIndexEntry(')
          ..write('lessonId: $lessonId, ')
          ..write('completedAt: $completedAt, ')
          ..write('workedSeconds: $workedSeconds, ')
          ..write('unitsCompleted: $unitsCompleted, ')
          ..write('plannedUnits: $plannedUnits, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('lessonClass: $lessonClass, ')
          ..write('unmeasuredUnits: $unmeasuredUnits, ')
          ..write('unmeasuredReason: $unmeasuredReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    lessonId,
    completedAt,
    workedSeconds,
    unitsCompleted,
    plannedUnits,
    unitLabel,
    lessonClass,
    unmeasuredUnits,
    unmeasuredReason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionIndexEntry &&
          other.lessonId == this.lessonId &&
          other.completedAt == this.completedAt &&
          other.workedSeconds == this.workedSeconds &&
          other.unitsCompleted == this.unitsCompleted &&
          other.plannedUnits == this.plannedUnits &&
          other.unitLabel == this.unitLabel &&
          other.lessonClass == this.lessonClass &&
          other.unmeasuredUnits == this.unmeasuredUnits &&
          other.unmeasuredReason == this.unmeasuredReason);
}

class SessionIndexEntriesCompanion extends UpdateCompanion<SessionIndexEntry> {
  final Value<String> lessonId;
  final Value<DateTime> completedAt;
  final Value<int> workedSeconds;
  final Value<int> unitsCompleted;
  final Value<int> plannedUnits;
  final Value<String> unitLabel;
  final Value<String> lessonClass;
  final Value<int> unmeasuredUnits;
  final Value<String?> unmeasuredReason;
  final Value<int> rowid;
  const SessionIndexEntriesCompanion({
    this.lessonId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.workedSeconds = const Value.absent(),
    this.unitsCompleted = const Value.absent(),
    this.plannedUnits = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.lessonClass = const Value.absent(),
    this.unmeasuredUnits = const Value.absent(),
    this.unmeasuredReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionIndexEntriesCompanion.insert({
    required String lessonId,
    required DateTime completedAt,
    required int workedSeconds,
    required int unitsCompleted,
    required int plannedUnits,
    required String unitLabel,
    required String lessonClass,
    this.unmeasuredUnits = const Value.absent(),
    this.unmeasuredReason = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : lessonId = Value(lessonId),
       completedAt = Value(completedAt),
       workedSeconds = Value(workedSeconds),
       unitsCompleted = Value(unitsCompleted),
       plannedUnits = Value(plannedUnits),
       unitLabel = Value(unitLabel),
       lessonClass = Value(lessonClass);
  static Insertable<SessionIndexEntry> custom({
    Expression<String>? lessonId,
    Expression<DateTime>? completedAt,
    Expression<int>? workedSeconds,
    Expression<int>? unitsCompleted,
    Expression<int>? plannedUnits,
    Expression<String>? unitLabel,
    Expression<String>? lessonClass,
    Expression<int>? unmeasuredUnits,
    Expression<String>? unmeasuredReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (completedAt != null) 'completed_at': completedAt,
      if (workedSeconds != null) 'worked_seconds': workedSeconds,
      if (unitsCompleted != null) 'units_completed': unitsCompleted,
      if (plannedUnits != null) 'planned_units': plannedUnits,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (lessonClass != null) 'lesson_class': lessonClass,
      if (unmeasuredUnits != null) 'unmeasured_units': unmeasuredUnits,
      if (unmeasuredReason != null) 'unmeasured_reason': unmeasuredReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionIndexEntriesCompanion copyWith({
    Value<String>? lessonId,
    Value<DateTime>? completedAt,
    Value<int>? workedSeconds,
    Value<int>? unitsCompleted,
    Value<int>? plannedUnits,
    Value<String>? unitLabel,
    Value<String>? lessonClass,
    Value<int>? unmeasuredUnits,
    Value<String?>? unmeasuredReason,
    Value<int>? rowid,
  }) {
    return SessionIndexEntriesCompanion(
      lessonId: lessonId ?? this.lessonId,
      completedAt: completedAt ?? this.completedAt,
      workedSeconds: workedSeconds ?? this.workedSeconds,
      unitsCompleted: unitsCompleted ?? this.unitsCompleted,
      plannedUnits: plannedUnits ?? this.plannedUnits,
      unitLabel: unitLabel ?? this.unitLabel,
      lessonClass: lessonClass ?? this.lessonClass,
      unmeasuredUnits: unmeasuredUnits ?? this.unmeasuredUnits,
      unmeasuredReason: unmeasuredReason ?? this.unmeasuredReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (workedSeconds.present) {
      map['worked_seconds'] = Variable<int>(workedSeconds.value);
    }
    if (unitsCompleted.present) {
      map['units_completed'] = Variable<int>(unitsCompleted.value);
    }
    if (plannedUnits.present) {
      map['planned_units'] = Variable<int>(plannedUnits.value);
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<String>(unitLabel.value);
    }
    if (lessonClass.present) {
      map['lesson_class'] = Variable<String>(lessonClass.value);
    }
    if (unmeasuredUnits.present) {
      map['unmeasured_units'] = Variable<int>(unmeasuredUnits.value);
    }
    if (unmeasuredReason.present) {
      map['unmeasured_reason'] = Variable<String>(unmeasuredReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionIndexEntriesCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('completedAt: $completedAt, ')
          ..write('workedSeconds: $workedSeconds, ')
          ..write('unitsCompleted: $unitsCompleted, ')
          ..write('plannedUnits: $plannedUnits, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('lessonClass: $lessonClass, ')
          ..write('unmeasuredUnits: $unmeasuredUnits, ')
          ..write('unmeasuredReason: $unmeasuredReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GravitaDatabase extends GeneratedDatabase {
  _$GravitaDatabase(QueryExecutor e) : super(e);
  $GravitaDatabaseManager get managers => $GravitaDatabaseManager(this);
  late final $SessionIndexEntriesTable sessionIndexEntries =
      $SessionIndexEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [sessionIndexEntries];
}

typedef $$SessionIndexEntriesTableCreateCompanionBuilder =
    SessionIndexEntriesCompanion Function({
      required String lessonId,
      required DateTime completedAt,
      required int workedSeconds,
      required int unitsCompleted,
      required int plannedUnits,
      required String unitLabel,
      required String lessonClass,
      Value<int> unmeasuredUnits,
      Value<String?> unmeasuredReason,
      Value<int> rowid,
    });
typedef $$SessionIndexEntriesTableUpdateCompanionBuilder =
    SessionIndexEntriesCompanion Function({
      Value<String> lessonId,
      Value<DateTime> completedAt,
      Value<int> workedSeconds,
      Value<int> unitsCompleted,
      Value<int> plannedUnits,
      Value<String> unitLabel,
      Value<String> lessonClass,
      Value<int> unmeasuredUnits,
      Value<String?> unmeasuredReason,
      Value<int> rowid,
    });

class $$SessionIndexEntriesTableFilterComposer
    extends Composer<_$GravitaDatabase, $SessionIndexEntriesTable> {
  $$SessionIndexEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workedSeconds => $composableBuilder(
    column: $table.workedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitsCompleted => $composableBuilder(
    column: $table.unitsCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedUnits => $composableBuilder(
    column: $table.plannedUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonClass => $composableBuilder(
    column: $table.lessonClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unmeasuredUnits => $composableBuilder(
    column: $table.unmeasuredUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unmeasuredReason => $composableBuilder(
    column: $table.unmeasuredReason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionIndexEntriesTableOrderingComposer
    extends Composer<_$GravitaDatabase, $SessionIndexEntriesTable> {
  $$SessionIndexEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workedSeconds => $composableBuilder(
    column: $table.workedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitsCompleted => $composableBuilder(
    column: $table.unitsCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedUnits => $composableBuilder(
    column: $table.plannedUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonClass => $composableBuilder(
    column: $table.lessonClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unmeasuredUnits => $composableBuilder(
    column: $table.unmeasuredUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unmeasuredReason => $composableBuilder(
    column: $table.unmeasuredReason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionIndexEntriesTableAnnotationComposer
    extends Composer<_$GravitaDatabase, $SessionIndexEntriesTable> {
  $$SessionIndexEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get workedSeconds => $composableBuilder(
    column: $table.workedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitsCompleted => $composableBuilder(
    column: $table.unitsCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedUnits => $composableBuilder(
    column: $table.plannedUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<String> get lessonClass => $composableBuilder(
    column: $table.lessonClass,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unmeasuredUnits => $composableBuilder(
    column: $table.unmeasuredUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unmeasuredReason => $composableBuilder(
    column: $table.unmeasuredReason,
    builder: (column) => column,
  );
}

class $$SessionIndexEntriesTableTableManager
    extends
        RootTableManager<
          _$GravitaDatabase,
          $SessionIndexEntriesTable,
          SessionIndexEntry,
          $$SessionIndexEntriesTableFilterComposer,
          $$SessionIndexEntriesTableOrderingComposer,
          $$SessionIndexEntriesTableAnnotationComposer,
          $$SessionIndexEntriesTableCreateCompanionBuilder,
          $$SessionIndexEntriesTableUpdateCompanionBuilder,
          (
            SessionIndexEntry,
            BaseReferences<
              _$GravitaDatabase,
              $SessionIndexEntriesTable,
              SessionIndexEntry
            >,
          ),
          SessionIndexEntry,
          PrefetchHooks Function()
        > {
  $$SessionIndexEntriesTableTableManager(
    _$GravitaDatabase db,
    $SessionIndexEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionIndexEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionIndexEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionIndexEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> lessonId = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> workedSeconds = const Value.absent(),
                Value<int> unitsCompleted = const Value.absent(),
                Value<int> plannedUnits = const Value.absent(),
                Value<String> unitLabel = const Value.absent(),
                Value<String> lessonClass = const Value.absent(),
                Value<int> unmeasuredUnits = const Value.absent(),
                Value<String?> unmeasuredReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionIndexEntriesCompanion(
                lessonId: lessonId,
                completedAt: completedAt,
                workedSeconds: workedSeconds,
                unitsCompleted: unitsCompleted,
                plannedUnits: plannedUnits,
                unitLabel: unitLabel,
                lessonClass: lessonClass,
                unmeasuredUnits: unmeasuredUnits,
                unmeasuredReason: unmeasuredReason,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lessonId,
                required DateTime completedAt,
                required int workedSeconds,
                required int unitsCompleted,
                required int plannedUnits,
                required String unitLabel,
                required String lessonClass,
                Value<int> unmeasuredUnits = const Value.absent(),
                Value<String?> unmeasuredReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionIndexEntriesCompanion.insert(
                lessonId: lessonId,
                completedAt: completedAt,
                workedSeconds: workedSeconds,
                unitsCompleted: unitsCompleted,
                plannedUnits: plannedUnits,
                unitLabel: unitLabel,
                lessonClass: lessonClass,
                unmeasuredUnits: unmeasuredUnits,
                unmeasuredReason: unmeasuredReason,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionIndexEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$GravitaDatabase,
      $SessionIndexEntriesTable,
      SessionIndexEntry,
      $$SessionIndexEntriesTableFilterComposer,
      $$SessionIndexEntriesTableOrderingComposer,
      $$SessionIndexEntriesTableAnnotationComposer,
      $$SessionIndexEntriesTableCreateCompanionBuilder,
      $$SessionIndexEntriesTableUpdateCompanionBuilder,
      (
        SessionIndexEntry,
        BaseReferences<
          _$GravitaDatabase,
          $SessionIndexEntriesTable,
          SessionIndexEntry
        >,
      ),
      SessionIndexEntry,
      PrefetchHooks Function()
    >;

class $GravitaDatabaseManager {
  final _$GravitaDatabase _db;
  $GravitaDatabaseManager(this._db);
  $$SessionIndexEntriesTableTableManager get sessionIndexEntries =>
      $$SessionIndexEntriesTableTableManager(_db, _db.sessionIndexEntries);
}
