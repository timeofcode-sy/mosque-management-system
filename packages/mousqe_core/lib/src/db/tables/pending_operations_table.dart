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

  /// سببُ رفض الخادم للعملية، أو `null` ما دامت في الطابور — ✅ م.6.2.
  ///
  /// العمليةُ التي تعود في `failed[]` **تُعزَل ولا تُحذف ولا يُعاد إرسالُها آلياً**
  /// ([SYNC-PROTOCOL.md §3](../../../../../docs/SYNC-PROTOCOL.md) البند 4): حذفُها
  /// ضياعُ كتابةٍ لم يعرف بها صاحبُها، وإعادةُ إرسالها كلَّ دورةٍ ضجيجٌ لن ينجح
  /// أبداً — نوعٌ مجهول أو صفٌّ من معهدٍ آخر لا يصير مقبولاً بالتكرار. فالحكمُ
  /// فيها لصاحب الجهاز: يراها برسالتها في شريط المزامنة، ثم يعيد المحاولة أو
  /// يتخلّى عنها.
  TextColumn get failedReason => text().nullable()();

  DateTimeColumn get failedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {opUuid};
}
