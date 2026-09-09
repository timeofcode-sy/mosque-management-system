import 'package:drift/drift.dart';

/// نظير جدول `shift_days` الخادمي — ✅ م.6.5: أيامُ الدوام الأسبوعية (0–6).
///
/// جدولٌ يُبثّ منذ م.4 وكان `SyncPayloadApplier` يُسقطه، فكان الديسكتوب سيعرض
/// دواماً بلا أيامه — وشاشةُ الدوامات أوّلُ من يحتاجها.
@DataClassName('ShiftDayRow')
class ShiftDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get shiftId => integer()();
  IntColumn get weekday => integer()();
}
