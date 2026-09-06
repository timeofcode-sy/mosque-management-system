import 'package:drift/drift.dart';

/// نظير جدول `courses` الخادمي.
@DataClassName('CourseRow')
class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get name => text()();
  DateTimeColumn get startsOn => dateTime()();
  DateTimeColumn get endsOn => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
}
