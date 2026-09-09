import 'package:drift/drift.dart';

/// نظير جدول `student_curriculum_progress` الخادمي — ✅ م.6.5.
///
/// وهو ما تقرأ منه الاستمارةُ «محفوظاتِ الطالب»: البندُ المختار صفٌّ حالتُه
/// `memorized` أو `mastered`، والمُزال يعود `not_started` **ولا يُحذف صفُّه** —
/// فتبقى درجاتُ الأستاذ وملاحظاتُه.
@DataClassName('StudentProgressRow')
class StudentCurriculumProgressTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get studentId => integer()();
  IntColumn get curriculumItemId => integer()();
  IntColumn get courseCircleId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('not_started'))();
  IntColumn get percent => integer().withDefault(const Constant(0))();
  IntColumn get score => integer().nullable()();
  RealColumn get points => real().withDefault(const Constant(0))();
  DateTimeColumn get completedOn => dateTime().nullable()();
  DateTimeColumn get achievedOn => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  String get tableName => 'student_curriculum_progress';
}
