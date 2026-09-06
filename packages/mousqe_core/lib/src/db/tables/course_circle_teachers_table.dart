import 'package:drift/drift.dart';

/// نظير جدول `course_circle_teachers` الخادمي — إسناد الأستاذ إلى حلقة في دورة.
///
/// هو أساس ترشيح «حلقاتي» في العميل: السحب معهدٌ كامل ([SYNC-PROTOCOL.md §4](../../../../../docs/SYNC-PROTOCOL.md))
/// فيصل الجهازَ إسنادُ كل أستاذ في المعهد، ويرشّحه التطبيق بـ`teacher_uuid` القادم
/// في `/bootstrap` (البند 7 من §8).
@DataClassName('CourseCircleTeacherRow')
class CourseCircleTeachers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get courseCircleId => integer()();
  IntColumn get teacherId => integer()();
  TextColumn get role => text().withDefault(const Constant('main'))();
  DateTimeColumn get joinedOn => dateTime().nullable()();
  DateTimeColumn get leftOn => dateTime().nullable()();
}
