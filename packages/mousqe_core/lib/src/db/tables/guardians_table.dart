import 'package:drift/drift.dart';

/// نظير جدول `guardians` الخادمي — ✅ م.6.5.
///
/// اسمُ الأب وعملُه وهاتفُه ليست أعمدةً في `students` بل صفوفٌ هنا مربوطةٌ بالطالب
/// عبر [GuardianStudentTable]، لأن الوليَّ قد يتابع أكثر من ابنٍ في المعهد
/// ([PLAN.md §4.2](../../../../../docs/PLAN.md)). فاستمارةُ الطالب تقرأ الأربعةَ
/// من صفّين لا من ستة أعمدة.
@DataClassName('GuardianRow')
class Guardians extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get fullName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get alternatePhone => text().nullable()();
  TextColumn get occupation => text().nullable()();
  TextColumn get nationalId => text().nullable()();
  TextColumn get address => text().nullable()();
  BoolColumn get isAlive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}
