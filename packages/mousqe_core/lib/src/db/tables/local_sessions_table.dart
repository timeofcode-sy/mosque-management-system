import 'package:drift/drift.dart';

/// جلسةٌ فتحها هذا الجهاز **قبل** أن يعرفها الخادم — طبقة مسودّة محلية بحتة لا
/// تُزامَن ولا تُطبَّق عليها حمولةُ `change_log`.
///
/// لماذا جدولٌ مستقلّ بدل صفٍّ في `attendance_sessions`؟ لأن الجهاز لا يعرف إن
/// كان أحدٌ قد سبقه إلى فتح جلسة اليوم نفسه: مشرفٌ من اللوحة، أو أستاذٌ ثانٍ من
/// جهازه. لو زرع الجهازُ صفّاً في الجدول المتزامن لصار عند عودة الشبكة **صفّان**
/// لنفس (الحلقة + التاريخ) بمعرّفين مختلفين — أحدهما وهمٌ لا شيء يزيله. أمّا هنا
/// فالمفتاح هو (الحلقة + التاريخ) نفسه، والمسودّة تُمسح كلّها حين يفرغ الطابور
/// ويعود السحبُ بالصفوف الحقيقية.
@DataClassName('LocalSessionRow')
class LocalSessions extends Table {
  IntColumn get courseCircleId => integer()();
  DateTimeColumn get sessionDate => dateTime()();

  /// المعرّف الذي يولّده هذا الجهاز ويرسله في `attendance.session.open`.
  TextColumn get uuid => text()();

  /// ضغط الأستاذ «إقفال الجلسة» وهو بلا شبكة.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// ضغط المشرف «قفل نهائي» وهو بلا شبكة — م.6.4.
  ///
  /// لم يكن له عمود لأن الأستاذ لا يقفل: بابُه `attendance.lock` وهو لا يملكها.
  /// وبدونه كان الكشفُ يعود قابلاً للتحرير على جهاز القافل نفسِه حتى تصل دورةُ
  /// السحب — أي أن المشرف يقفل ثم يجد البابَ مفتوحاً أمامه.
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {courseCircleId, sessionDate};
}
