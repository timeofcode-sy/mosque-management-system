import 'package:drift/drift.dart';

/// نظير جدول `attendance_sessions` الخادمي.
@DataClassName('AttendanceSessionRow')
class AttendanceSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get courseCircleId => integer()();
  DateTimeColumn get sessionDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
