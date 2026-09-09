import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../screens/attendance_hub_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/catalog_screen.dart';
import '../screens/conflicts_screen.dart';
import '../screens/circles_screen.dart';
import '../screens/credentials_screen.dart';
import '../screens/curricula_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/enrollments_screen.dart';
import '../screens/excuses_screen.dart';
import '../screens/institute_settings_screen.dart';
import '../screens/institutes_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/students_screen.dart';
import '../screens/users_screen.dart';

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
/// أُعلنت الأبوابُ كلُّها في م.6.3 وشاشاتُها placeholder، **ومُلئت آخرُها في
/// م.6.6**. ولماذا أُعلنت قبل شاشاتها؟ لأن هذه القائمة هي **عقدُ الصلاحيات**
/// نفسُه: أن يرى المشرفُ ما يخصّه ولا يرى ما لا يخصّه. ولو أُخّرت إلى شاشاتها
/// لَما اختُبر ترشيحُها قبل أن يكتمل نصفُ المرحلة. وبناءُ ذلك على `user.permissions` من `/bootstrap`
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

// ✅ م.6.6 — الأربعةُ الأخيرة: فصار الخمسةَ عشرَ باباً كلُّها مفتوحةً، **ولم يبقَ
// بابٌ واحد على `PlaceholderScreen`**.
Widget _dashboard(BuildContext context) => const DashboardScreen();

Widget _reports(BuildContext context) => const ReportsScreen();

// ✅ م.6.4 — أوّلُ بابين تُملأ شاشاتُهما.
Widget _attendance(BuildContext context) => const AttendanceHubScreen();

Widget _circles(BuildContext context) => const CirclesScreen();

// ✅ م.6.5 — الإدارةُ اليومية وسطحُ الإدارة: تسعةُ أبوابٍ تُملأ دفعةً واحدة.
Widget _students(BuildContext context) => const StudentsScreen();

Widget _enrollments(BuildContext context) => const EnrollmentsScreen();

Widget _excuses(BuildContext context) => const ExcusesScreen();

Widget _catalog(BuildContext context) => const CatalogScreen();

Widget _curricula(BuildContext context) => const CurriculaScreen();

Widget _users(BuildContext context) => const UsersScreen();

Widget _credentials(BuildContext context) => const CredentialsScreen();

Widget _settings(BuildContext context) => const InstituteSettingsScreen();

Widget _institutes(BuildContext context) => const InstitutesScreen();

Widget _conflicts(BuildContext context) => const ConflictsScreen();

Widget _backup(BuildContext context) => const BackupScreen();
