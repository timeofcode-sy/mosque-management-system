import 'package:drift/drift.dart';

/// نظير جدول `student_points` الخادمي.
@DataClassName('StudentPointRow')
class StudentPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get studentId => integer()();
  IntColumn get courseCircleId => integer().nullable()();
  IntColumn get attendanceSessionId => integer().nullable()();
  RealColumn get points => real()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get awardedOn => dateTime()();
}
