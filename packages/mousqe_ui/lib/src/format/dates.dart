/// التاريخ بصوت العلامة: الميلادي افتراضيٌّ بأسماء الأشهر المعتمدة في سوريا (كانون الثاني، شباط، آذار …)
/// وأسماء الأيام، **والأرقام لاتينية (0–9)** كما في كل النظام. لا نعتمد `DateFormat('…', 'ar')` لأن
/// أسماءه تخالف المعتمد هنا (يناير، فبراير …).
const List<String> syrianMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

/// يبدأ بالاثنين ليوافق `DateTime.weekday` (1 = الاثنين … 7 = الأحد).
const List<String> arabicWeekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// «الخميس، 9 تشرين الأول 2026م» — [withWeekday] و[withYear] اختياريان.
String formatLongDate(
  DateTime date, {
  bool withWeekday = true,
  bool withYear = true,
}) {
  final day = '${date.day} ${syrianMonths[date.month - 1]}';
  final year = withYear ? ' ${date.year}م' : '';
  final weekday = withWeekday ? '${arabicWeekdays[date.weekday - 1]}، ' : '';

  return '$weekday$day$year';
}
