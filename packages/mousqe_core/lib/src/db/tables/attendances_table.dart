import 'package:drift/drift.dart';

/// نظير جدول `attendances` الخادمي.
@DataClassName('AttendanceRow')
class Attendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get attendanceSessionId => integer()();
  IntColumn get studentId => integer()();
  TextColumn get status => text().withDefault(const Constant('present'))();
  IntColumn get lateMinutes => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get notePolarity => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
}
