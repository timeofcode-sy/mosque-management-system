import 'package:drift/drift.dart';

/// نظير جدول `teacher_attendances` الخادمي — حضورُ الأستاذ في الجلسة نفسِها.
///
/// جدولٌ منفصل عن `attendances` لا عمودٌ فيه: حضورُ الأستاذ **لا يدخل** في نسبة
/// الحلقة ولا في ترتيبها، فخلطُهما كان يلوّث الإحصاء بصفٍّ ليس طالباً — وهي نفسُ
/// الحجّة التي فصلت `TakeTeacherAttendance` عن `TakeAttendance` على الخادم.
///
/// وصل الجهازَ في `sync/pull` منذ م.4، ولم يكن له صفٌّ يستقبله حتى م.6.4 — لأن
/// الأستاذ لا يتفقّد الأساتذة، والديسكتوبُ هو أوّلُ عميلٍ يفعل.
@DataClassName('TeacherAttendanceRow')
class TeacherAttendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get attendanceSessionId => integer()();
  IntColumn get teacherId => integer()();
  TextColumn get status => text().withDefault(const Constant('present'))();
  IntColumn get lateMinutes => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
}
