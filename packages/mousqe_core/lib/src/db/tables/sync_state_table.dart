import 'package:drift/drift.dart';

/// صفٌّ وحيد بمفتاح `deviceUuid` يحمل `last_pulled_seq` — [SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md)
/// البند 4: يُقرأ ويُكتب محلياً فقط، لا اعتماد على مؤشّر الخادم.
///
/// و`lastPulledAt` زمنُ آخر سحبٍ ناجح — يعرضه مؤشّر المزامنة في الشاشات، وهو
/// إجابةُ «متى آخر مرة رأى هذا الجهاز الخادم؟» التي لا يجيبها الرقم المتسلسل وحده.
class SyncState extends Table {
  TextColumn get deviceUuid => text()();
  IntColumn get lastPulledSeq => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {deviceUuid};
}
