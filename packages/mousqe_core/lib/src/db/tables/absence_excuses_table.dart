import 'package:drift/drift.dart';

/// نظير جدول `absence_excuses` الخادمي.
@DataClassName('AbsenceExcuseRow')
class AbsenceExcusesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get studentId => integer()();
  DateTimeColumn get fromDate => dateTime()();
  DateTimeColumn get toDate => dateTime()();
  TextColumn get reason => text()();
  TextColumn get attachmentPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get reviewNote => text().nullable()();

  @override
  String get tableName => 'absence_excuses';
}
