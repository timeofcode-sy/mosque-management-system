import 'package:drift/drift.dart';

/// نظير جدول `shifts` الخادمي.
///
/// `startsAt` نصٌّ بصيغة `HH:MM:SS` كما يعود من عمود `time` الخادمي — وهو **مرجع
/// حساب دقائق التأخير** في `LateMinutes`، فبلا هذا الجدول لا يعرض التطبيق رقماً
/// أوف-لاين قبل أن يؤكّده الخادم (PHASE-5-STAGES.MD §0 البند 1).
@DataClassName('ShiftRow')
class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get courseId => integer()();
  TextColumn get name => text()();
  TextColumn get startsAt => text()();
  TextColumn get endsAt => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
