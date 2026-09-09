import 'package:drift/drift.dart';

/// حضورُ أستاذٍ سجّله المشرف ولم يؤكّده الخادم بعد — نظير [LocalAttendances]
/// حرفياً، وبنفس مفتاحها الطبيعي (الحلقة + التاريخ + الشخص).
///
/// وبلا `recorded_at` في الحمولة المرسَلة: العقدُ لا يحمله
/// ([API.md §6](../../../../../docs/API.md))، فلا حسمَ تعارضٍ لهذه الصفوف. والعمودُ
/// هنا **زمنُ الكتابة على الجهاز** لا أكثر — يُعرَض لصاحبه ولا يُرسَل.
@DataClassName('LocalTeacherAttendanceRow')
class LocalTeacherAttendances extends Table {
  IntColumn get courseCircleId => integer()();
  DateTimeColumn get sessionDate => dateTime()();
  IntColumn get teacherId => integer()();
  TextColumn get status => text()();
  IntColumn get lateMinutes => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {courseCircleId, sessionDate, teacherId};
}
