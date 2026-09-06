import 'package:drift/drift.dart';

/// نظير جدول `memorization_logs` الخادمي.
@DataClassName('RecitationRow')
class Recitations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get studentId => integer()();
  IntColumn get courseCircleId => integer().nullable()();
  IntColumn get attendanceSessionId => integer().nullable()();
  IntColumn get curriculumItemId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text().withDefault(const Constant('hifz'))();
  TextColumn get grade => text().nullable()();
  IntColumn get fromSurah => integer().nullable()();
  IntColumn get fromAyah => integer().nullable()();
  IntColumn get toSurah => integer().nullable()();
  IntColumn get toAyah => integer().nullable()();
  RealColumn get lines => real().nullable()();
  RealColumn get newLines => real().nullable()();
  RealColumn get points => real().withDefault(const Constant(0))();
  IntColumn get juz => integer().nullable()();
  TextColumn get notes => text().nullable()();
}
