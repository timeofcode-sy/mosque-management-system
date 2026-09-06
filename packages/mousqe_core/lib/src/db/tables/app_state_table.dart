import 'package:drift/drift.dart';

/// مخزن مفتاح/قيمة للقطة `/bootstrap` وما شابهها — ما ليس صفَّ مزامنة ويجب أن
/// ينجو من إغلاق التطبيق: ثيمُ المعهد وفترةُ السماح ومعرّفُ الأستاذ.
///
/// يُمسح مع بقية الجداول في `AppDatabase.clearAll()` عند قفل الحساب.
@DataClassName('AppStateRow')
class AppState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
