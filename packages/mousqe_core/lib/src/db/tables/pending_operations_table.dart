import 'package:drift/drift.dart';

/// طابور عمليات `sync/push` بانتظار الإرسال — [SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md)
/// البند 1: `op_uuid` يُثبَّت هنا **قبل** أي محاولة إرسال.
///
/// `sequence` عدّادٌ تصاعدي يفرض ترتيب الإرسال. والترتيبُ ليس تجميلاً: الخادم
/// يطبّق الدفعة `foreach` بترتيب المصفوفة، فـ`attendance.session.open` **يجب** أن
/// تسبق `attendance.take` على الجلسة نفسها وإلا فشلت الثانية
/// ([SYNC-PROTOCOL.md §3](../../../../../docs/SYNC-PROTOCOL.md) البند 3). و`createdAt`
/// وحده لا يكفي: عمليتان تُصفّان في نفس الميلي-ثانية تتساويان فيه، فيصير ترتيبهما
/// لِما تقرّره sqlite لا لِما قصده التطبيق.
class PendingOperations extends Table {
  TextColumn get opUuid => text()();
  IntColumn get sequence => integer()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {opUuid};
}
