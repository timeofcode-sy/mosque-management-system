import 'package:drift/drift.dart';

/// نظير جدول `course_circles` الخادمي.
@DataClassName('CourseCircleRow')
class CourseCircles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get courseId => integer()();
  IntColumn get circleId => integer()();
  IntColumn get shiftId => integer()();
  TextColumn get room => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
