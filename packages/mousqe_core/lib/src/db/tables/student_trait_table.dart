import 'package:drift/drift.dart';

/// نظير جدول `student_trait` الخادمي — ✅ م.6.5.
@DataClassName('StudentTraitRow')
class StudentTraitTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get studentId => integer()();
  IntColumn get traitId => integer()();
  TextColumn get note => text().nullable()();

  @override
  String get tableName => 'student_trait';
}
