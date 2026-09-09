import 'package:drift/drift.dart';

/// نظير جدول `custom_field_values` الخادمي — ✅ م.6.5.
///
/// و`entityType` نصُّ صنفٍ من PHP لا تعدادٌ في Dart: الحمولةُ تصل خاماً من
/// `toArray()`، ومطابقتُه تكون بما وصل لا بما نتمنّاه ([SyncPayloadApplier]).
@DataClassName('CustomFieldValueRow')
class CustomFieldValues extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get customFieldId => integer()();
  TextColumn get entityType => text()();
  IntColumn get entityId => integer()();
  TextColumn get value => text().nullable()();
}
