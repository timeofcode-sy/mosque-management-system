import 'package:drift/drift.dart';

/// منحةُ نقاطٍ سجّلها الأستاذ ولم يؤكّدها الخادم بعد — نظير [LocalRecitations]،
/// وبنفس السبب: مسودّةٌ تُعرَض موسومةً فوق صفوف `student_points` المتزامنة.
///
/// النقاط هنا **رقمُ الأستاذ نفسه** لا رقماً محسوباً، فهي تُعرض كما كتبها.
@DataClassName('LocalPointRow')
class LocalPoints extends Table {
  TextColumn get uuid => text()();
  IntColumn get studentId => integer()();
  IntColumn get courseCircleId => integer().nullable()();
  DateTimeColumn get sessionDate => dateTime()();
  RealColumn get points => real()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();

  /// شاهدةُ حذف — انظر [LocalRecitations.deleted].
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {uuid};
}
