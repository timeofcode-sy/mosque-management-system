import 'package:drift/drift.dart';

/// نظير جدول `circles` الخادمي — اسم الحلقة الذي يعرضه التطبيق أوف-لاين.
///
/// `course_circles.circle_id` مفتاحٌ رقمي لا يحمل اسماً، فبلا هذا الجدول لا يعرض
/// التطبيق إلا «حلقة #4» بعد أول إعادة تشغيل بلا شبكة.
@DataClassName('CircleRow')
class Circles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get name => text()();
  TextColumn get level => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
