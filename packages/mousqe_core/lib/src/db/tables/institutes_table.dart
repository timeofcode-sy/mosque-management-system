import 'package:drift/drift.dart';

/// نظير جدول `institutes` الخادمي — الأعمدة التي تصل عبر `change_log` فقط.
///
/// اسم صفّ البيانات مصرَّحٌ به صراحةً (`InstituteRow`) لأن الاسم الافتراضي
/// (`Institute`) يصطدم بنموذج `Institute` من `mousqe_core/src/models` — الاثنان
/// طبقتان مختلفتا الشكل عمداً (§ملاحظة plan §0) ولا يجوز دمجهما.
@DataClassName('InstituteRow')
class Institutes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get shortName => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get settings => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
