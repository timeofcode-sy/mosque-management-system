import 'package:drift/drift.dart';

/// نظير جدول `students` الخادمي — أعمدة العرض في تطبيق الأستاذ لا الاستمارة كاملة.
@DataClassName('StudentRow')
class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get registrationNo => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get firstName => text()();
  TextColumn get fatherName => text()();
  TextColumn get familyName => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
