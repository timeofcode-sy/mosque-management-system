import 'package:drift/drift.dart';

/// تسميعٌ سجّله الأستاذ ولم يؤكّده الخادم بعد — يُعرض فوق صفوف `recitations`
/// المتزامنة، ويُمسح حين يفرغ الطابور ويعود السحب به مطبَّقاً.
///
/// لماذا جدولٌ مستقلّ بدل الكتابة في `recitations` رأساً؟ لأن **الأسطر والنقاط
/// يحسبها الخادم ويجمّدها** ([API.md §6](../../../../../docs/API.md)): صفٌّ محليٌّ
/// في الجدول المتزامن يعني عرضَ «صفر نقطة» كأنها حقيقةٌ حسمها الخادم. أمّا هنا
/// فالمسودّة تُعرَض بوسمها: مدىً بلا نقاط، بانتظار المزامنة.
///
/// و[uuid] هو مفتاح كل شيء: العميل يولّده ويرسله في `recitation.save`، فيصير
/// التصحيح إعادةَ إرسالٍ بنفس المعرّف، والحذف عمليةً تشير إليه.
@DataClassName('LocalRecitationRow')
class LocalRecitations extends Table {
  TextColumn get uuid => text()();
  IntColumn get studentId => integer()();
  IntColumn get courseCircleId => integer()();
  DateTimeColumn get sessionDate => dateTime()();
  TextColumn get type => text()();
  TextColumn get grade => text().nullable()();
  IntColumn get fromSurah => integer()();
  IntColumn get fromAyah => integer()();
  IntColumn get toSurah => integer()();
  IntColumn get toAyah => integer()();
  IntColumn get juz => integer().nullable()();
  TextColumn get notes => text().nullable()();

  /// شاهدةُ حذف: التسميع زال من الجهاز وينتظر أن يزول من الخادم. بدونها يعود
  /// الصفُّ المتزامن إلى الظهور بين الحذف ونجاح الدفع.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {uuid};
}
