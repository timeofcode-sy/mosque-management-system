import 'package:drift/drift.dart';

/// حالةُ تفقّدٍ سجّلها الأستاذ ولم يؤكّدها الخادم بعد — تُعرض فوق صفوف
/// `attendances` المتزامنة، وتُمسح حين يفرغ الطابور ويعود السحب بها مطبَّقة.
///
/// `recordedAt` **زمنُ الجهاز وقت الضغط** لا وقت الإرسال — وهو مفتاح حسم التعارض
/// على الخادم ([SYNC-PROTOCOL.md §5](../../../../../docs/SYNC-PROTOCOL.md)).
@DataClassName('LocalAttendanceRow')
class LocalAttendances extends Table {
  IntColumn get courseCircleId => integer()();
  DateTimeColumn get sessionDate => dateTime()();
  IntColumn get studentId => integer()();
  TextColumn get status => text()();
  IntColumn get lateMinutes => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {courseCircleId, sessionDate, studentId};
}
