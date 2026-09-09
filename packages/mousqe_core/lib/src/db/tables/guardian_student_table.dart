import 'package:drift/drift.dart';

/// نظير جدول `guardian_student` الخادمي — ✅ م.6.5.
///
/// و`relation` هو ما يقرأ به النموذجُ «الأب» من «الأم»: `SaveStudentRegistration`
/// يفهرس الأولياءَ بصلة القرابة لا بترتيبهم، فالاستمارةُ تُملأ منها بنفس المفتاح.
@DataClassName('GuardianStudentRow')
class GuardianStudentTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get guardianId => integer()();
  IntColumn get studentId => integer()();
  TextColumn get relation => text().withDefault(const Constant('father'))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get canViewReports => boolean().withDefault(const Constant(true))();
  BoolColumn get canSubmitExcuses => boolean().withDefault(const Constant(true))();

  @override
  String get tableName => 'guardian_student';
}
