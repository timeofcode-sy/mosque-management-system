import 'package:drift/drift.dart';

/// نظير جدول `enrollments` الخادمي — كشفُ طلاب الحلقة.
///
/// بدونه لا يستطيع الأستاذ فتحَ جلسةٍ أوف-لاين أصلاً: صفوفُ الحضور تُبذَر على
/// الخادم عند الفتح، وقبل أن تصل لا يعرف الجهازُ من في الحلقة. وشرطا
/// `enrolledOn`/`leftOn` هما ما يجعل التفقّد الرجعي يرى الحلقة كما كانت يومَها،
/// كما في `OpenAttendanceSession::enrollmentsOn` حرفياً.
@DataClassName('EnrollmentRow')
class Enrollments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get courseCircleId => integer()();
  IntColumn get studentId => integer()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get enrolledOn => dateTime().nullable()();
  DateTimeColumn get leftOn => dateTime().nullable()();
}
