import 'package:drift/drift.dart';

/// طابور عمليات `sync/push` بانتظار الإرسال — [SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md)
/// البند 1: `op_uuid` يُثبَّت هنا **قبل** أي محاولة إرسال.
class PendingOperations extends Table {
  TextColumn get opUuid => text()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {opUuid};
}
