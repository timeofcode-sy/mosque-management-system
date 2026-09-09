import 'package:drift/drift.dart';

/// نظير جدول `students` الخادمي.
///
/// 🔄 **م.6.5: صار الاستمارةَ كاملةً بعد أن كان أعمدةَ عرضٍ لتطبيق الأستاذ.**
/// الأستاذُ يقرأ اسماً ورقمَ بطاقةٍ وحالة، والمشرفُ **يحرّر الاستمارة أوف-لاين**
/// ([APPS-FEATURES.md §4.2](../../../../../docs/APPS-FEATURES.md) البند 5) —
/// وحمولةُ `student.save` قائمةٌ بيضاء من عشرين عموداً. فبثمانيةٍ محفوظةٍ محلياً
/// كان فتحُ طالبٍ للتحرير يعرض استمارةً **نصفُها فارغ**، وحفظُها يمحو ما لم
/// يُعرض: عنوانَه ووضعَه الصحي وملاحظاتِه.
///
/// والأعمدةُ تصل في `sync/pull` منذ م.4 — الحمولةُ صفُّ الجدول كاملاً — وكانت
/// تُقرأ ثم تُهمَل عند البناء. فالكسبُ سعةٌ في المخزن لا طلبُ شبكةٍ إضافي.
@DataClassName('StudentRow')
class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer()();
  TextColumn get registrationNo => text().nullable()();
  DateTimeColumn get registrationDate => dateTime().nullable()();
  TextColumn get registrationDateHijri => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get firstName => text()();
  TextColumn get fatherName => text()();
  TextColumn get familyName => text()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get birthPlace => text().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get nationalId => text().nullable()();
  TextColumn get gradeLevel => text().nullable()();
  TextColumn get studentJob => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get permanentAddress => text().nullable()();
  TextColumn get currentAddress => text().nullable()();
  IntColumn get familyMembersCount => integer().nullable()();
  TextColumn get studentHealthStatus => text().nullable()();
  TextColumn get familyHealthStatus => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
