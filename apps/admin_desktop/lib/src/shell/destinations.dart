import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../screens/placeholder_screen.dart';

/// عائلاتُ الأبواب في القائمة الجانبية — عناوينُ تجميعٍ لا شاشات.
enum SectionGroup {
  overview('الاطّلاع'),
  circle('الحلقة والتفقّد'),
  daily('الإدارة اليومية'),
  institute('المعهد'),
  system('النظام');

  const SectionGroup(this.label);

  final String label;
}

/// بابٌ في القائمة الجانبية: عنوانُه، وأيقونتُه، و**الصلاحيةُ التي تفتحه**.
class DesktopSection {
  const DesktopSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    required this.permissions,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final SectionGroup group;

  /// يُفتح البابُ بـ**واحدةٍ** من هذه لا بكلّها: «الطلاب» يراها من يملك
  /// `students.view` قارئاً، ومن يملك `students.manage` كاتباً — والفرقُ بينهما
  /// داخلَ الشاشة لا في ظهورها. وقائمةٌ فارغة تعني باباً يفتحه كلُّ من دخل.
  final List<String> permissions;

  final WidgetBuilder builder;

  bool isVisibleTo(BootstrapSnapshot? snapshot) {
    if (permissions.isEmpty) {
      return true;
    }

    return snapshot?.canAny(permissions) ?? false;
  }
}

/// كتالوجُ الأبواب كاملاً — وترتيبُه هو ترتيبُ القائمة الجانبية.
///
/// الشاشاتُ نفسُها تُبنى في م.6.4–6.6؛ وما يُحسم هنا هو **الهيكل**: أيُّ بابٍ
/// موجود، وأيُّ صلاحيةٍ تفتحه. وبناءُ ذلك على `user.permissions` من `/bootstrap`
/// لا على اسم الدور هو القرار 3 في [PHASE-6-STAGES.MD §0] — نسخةٌ واحدة من
/// البرنامج، وواجهتُها تفترق بما يملكه فاتحُها.
const List<DesktopSection> desktopSections = [
  DesktopSection(
    id: 'dashboard',
    label: 'الداشبورد',
    icon: Icons.space_dashboard_outlined,
    group: SectionGroup.overview,
    permissions: ['reports.view'],
    builder: _dashboard,
  ),
  DesktopSection(
    id: 'reports',
    label: 'التقارير والطباعة',
    icon: Icons.print_outlined,
    group: SectionGroup.overview,
    permissions: ['reports.view', 'reports.export'],
    builder: _reports,
  ),
  DesktopSection(
    id: 'attendance',
    label: 'التفقّد',
    icon: Icons.fact_check_outlined,
    group: SectionGroup.circle,
    permissions: ['attendance.view'],
    builder: _attendance,
  ),
  DesktopSection(
    id: 'circles',
    label: 'الحلقات',
    icon: Icons.groups_2_outlined,
    group: SectionGroup.circle,
    permissions: ['circles.view'],
    builder: _circles,
  ),
  DesktopSection(
    id: 'students',
    label: 'الطلاب',
    icon: Icons.school_outlined,
    group: SectionGroup.daily,
    permissions: ['students.view', 'students.manage'],
    builder: _students,
  ),
  DesktopSection(
    id: 'enrollments',
    label: 'التسجيل والنقل',
    icon: Icons.swap_horiz_outlined,
    group: SectionGroup.daily,
    permissions: ['enrollments.manage', 'transfers.manage'],
    builder: _enrollments,
  ),
  DesktopSection(
    id: 'excuses',
    label: 'أعذار الغياب',
    icon: Icons.mark_email_read_outlined,
    group: SectionGroup.daily,
    permissions: ['excuses.review'],
    builder: _excuses,
  ),
  DesktopSection(
    id: 'catalog',
    label: 'الدورات والدوامات',
    icon: Icons.calendar_month_outlined,
    group: SectionGroup.institute,
    permissions: ['courses.manage', 'shifts.manage', 'circles.manage'],
    builder: _catalog,
  ),
  DesktopSection(
    id: 'curricula',
    label: 'المناهج',
    icon: Icons.menu_book_outlined,
    group: SectionGroup.institute,
    permissions: ['curricula.manage'],
    builder: _curricula,
  ),
  DesktopSection(
    id: 'users',
    label: 'المستخدمون والأدوار',
    icon: Icons.badge_outlined,
    group: SectionGroup.institute,
    permissions: ['users.manage', 'users.invite'],
    builder: _users,
  ),
  DesktopSection(
    id: 'credentials',
    label: 'بيانات الدخول',
    icon: Icons.key_outlined,
    group: SectionGroup.institute,
    permissions: ['credentials.export', 'credentials.manage'],
    builder: _credentials,
  ),
  DesktopSection(
    id: 'settings',
    label: 'بيانات المعهد',
    icon: Icons.tune_outlined,
    group: SectionGroup.institute,
    permissions: ['settings.manage'],
    builder: _settings,
  ),
  DesktopSection(
    id: 'institutes',
    label: 'المعاهد',
    icon: Icons.apartment_outlined,
    group: SectionGroup.institute,
    permissions: ['institutes.manage'],
    builder: _institutes,
  ),
  DesktopSection(
    id: 'conflicts',
    label: 'التعارضات',
    icon: Icons.rule_folder_outlined,
    group: SectionGroup.system,
    permissions: ['conflicts.review'],
    builder: _conflicts,
  ),
  DesktopSection(
    id: 'backup',
    label: 'نسخٌ احتياطي',
    icon: Icons.save_alt_outlined,
    group: SectionGroup.system,
    // نسخُ ملفِّ drift عملٌ محليٌّ بحت، فلا صلاحيةَ خادمية تحرسه — لكن من لا
    // يسحب لا يملك ما ينسخه، فرُبط بمن له مخزنٌ أصلاً.
    permissions: ['sync.pull'],
    builder: _backup,
  ),
];

/// ما يظهر منها لصاحب هذه اللقطة — **ما لا يملكه المستخدم لا يظهر أصلاً**.
///
/// لا إخفاءٌ بتعطيلٍ ولا رسالةُ «لا تملك الصلاحية» عند الضغط: بابٌ مقفلٌ ظاهر
/// يجعل نصفَ البرنامج حائطاً أمام المشرف، وهو لا يعنيه أصلاً.
List<DesktopSection> visibleSections(BootstrapSnapshot? snapshot) {
  return [
    for (final section in desktopSections)
      if (section.isVisibleTo(snapshot)) section,
  ];
}

Widget _dashboard(BuildContext context) => const PlaceholderScreen(
      title: 'الداشبورد',
      phase: 'م.6.6',
      note: 'إحصاءاتُ المعهد — تُحسب محلياً من الصفوف المتزامنة لا من الخادم.',
    );

Widget _reports(BuildContext context) => const PlaceholderScreen(
      title: 'التقارير والطباعة',
      phase: 'م.6.6',
      note: 'تقاريرُ الحلقات والطلاب مطبوعةً من الجهاز، فتُطبع والشبكةُ مقطوعة.',
    );

Widget _attendance(BuildContext context) => const PlaceholderScreen(
      title: 'التفقّد',
      phase: 'م.6.4',
      note: 'تفقّدُ أي حلقةٍ في المعهد، وتصحيحُ تفقّدٍ بعد الإقفال، وقفلُ الجلسة.',
    );

Widget _circles(BuildContext context) => const PlaceholderScreen(
      title: 'الحلقات',
      phase: 'م.6.4',
      note: 'كشفُ حلقات المعهد وسجلُّ جلساتها وملفّاتُ طلابها.',
    );

Widget _students(BuildContext context) => const PlaceholderScreen(
      title: 'الطلاب',
      phase: 'م.6.5',
      note: 'الاستمارةُ الكاملة — تُكتب أوف-لاين وتمرّ بالطابور نوعَ `student.save`.',
    );

Widget _enrollments(BuildContext context) => const PlaceholderScreen(
      title: 'التسجيل والنقل',
      phase: 'م.6.5',
      note: 'تسجيلُ الطالب في حلقةٍ ونقلُه بينها — `enrollment.save` و`student.transfer`.',
    );

Widget _excuses(BuildContext context) => const PlaceholderScreen(
      title: 'أعذار الغياب',
      phase: 'م.6.5',
      note: 'قبولُ إذن الغياب ورفضُه من المسجد بلا شبكة — نوعُ `excuse.review`.',
    );

Widget _catalog(BuildContext context) => const PlaceholderScreen(
      title: 'الدورات والدوامات',
      phase: 'م.6.5',
      note: 'بنيةُ الدورة — REST مباشر تحت `/admin` لا طابور، فهي تُهيَّأ متّصلاً.',
    );

Widget _curricula(BuildContext context) => const PlaceholderScreen(
      title: 'المناهج',
      phase: 'م.6.5',
      note: 'وتنتظر نقطتَها: `SaveCurriculumItem` قائمٌ على اللوحة بلا غلافٍ بعد.',
    );

Widget _users(BuildContext context) => const PlaceholderScreen(
      title: 'المستخدمون والأدوار',
      phase: 'م.6.5',
      note: 'فوق `/admin/users` و`/admin/roles` — ولا يُسند أحدٌ دوراً أعلى من دوره.',
    );

Widget _credentials(BuildContext context) => const PlaceholderScreen(
      title: 'بيانات الدخول',
      phase: 'م.6.5',
      note: 'توليدُ كلمات المرور وطباعةُ البطاقات وإقفالُ الحسابات.',
    );

Widget _settings(BuildContext context) => const PlaceholderScreen(
      title: 'بيانات المعهد',
      phase: 'م.6.5',
      note: 'بياناتُ المعهد وألوانُه الثلاثة — ومنها يُبنى ثيمُ الأسطح الخمسة.',
    );

Widget _institutes(BuildContext context) => const PlaceholderScreen(
      title: 'المعاهد',
      phase: 'م.6.5',
      note: 'إنشاءُ المعاهد وتحريرُها — للمبرمج والمشرف الأعلى وحدهما.',
    );

Widget _conflicts(BuildContext context) => const PlaceholderScreen(
      title: 'التعارضات',
      phase: 'م.6.6',
      note: 'رؤيةُ القيمتين المتنازعتين وقلبُ الحكم — غلافٌ فوق نقطتَي م.6.1.',
    );

Widget _backup(BuildContext context) => const PlaceholderScreen(
      title: 'نسخٌ احتياطي',
      phase: 'م.6.6',
      note: 'نسخةٌ محلية من ملفّ drift.',
    );
