import 'package:drift/drift.dart';

/// نظير جدول `teachers` الخادمي — أعمدة العرض لا الاستمارة كاملة.
@DataClassName('TeacherRow')
class Teachers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get displayName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
