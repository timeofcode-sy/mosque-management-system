import 'package:drift/drift.dart';

/// نظير جدول `custom_fields` الخادمي — ✅ م.6.5.
///
/// «الواصفاتُ الإضافية» التي يعرّفها المشرف بلا كود ([PLAN.md §4.2]) — ولذلك لا
/// تستطيع الاستمارةُ أن تعرفها في زمن الترجمة: تُقرأ صفوفاً وتُرسَم حقولاً.
/// و`options` نصُّ JSON لقائمة الاختيار.
@DataClassName('CustomFieldRow')
class CustomFields extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get entity => text()();
  TextColumn get key => text()();
  TextColumn get label => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get options => text().nullable()();
  TextColumn get group => text().nullable()();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
