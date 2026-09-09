import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// ملفُّ الطالب: حضورُه ونقاطُه ومحفوظاتُه — كلُّها من drift.
///
/// النِّسَبُ والمجاميعُ تُحسب هنا لا تُطلب من الخادم: الإحصاءاتُ المشتقّة خارج
/// المزامنة أصلاً ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md))،
/// وحسابُها في [StudentProfile] داخل `mousqe_core` — يستدعيه السطحان.
///
/// وما يختلف عن نظيرِه في تطبيق الأستاذ **التخطيطُ وحده**: الشاشةُ عريضة فتُعرض
/// الأقسامُ الثلاثة في عمودين متجاورين بدل قائمةٍ واحدة طويلة يُمرَّر فيها.
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return StreamBuilder<StudentProfile?>(
      stream: deps.circles.watchStudentProfile(studentId),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: Text(profile?.fullName ?? 'ملف الطالب')),
          body: profile == null
              ? const Center(child: CircularProgressIndicator())
              : _Body(profile: profile),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = profile.attendanceRate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.registrationNo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'رقم التسجيل: ${profile.registrationNo}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: StatCard(
                value: rate == null ? '—' : '${rate.toStringAsFixed(1)}٪',
                label: 'نسبة الحضور',
                icon: Icons.percent,
              ),
            ),
            Expanded(
              child: StatCard(
                value: profile.totalPoints.toStringAsFixed(1),
                label: 'مجموع النقاط',
                icon: Icons.star_outline,
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.present)}',
                label: 'حاضر',
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.absent)}',
                label: 'غائب',
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.late)}',
                label: 'متأخر',
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.excused)}',
                label: 'مأذون',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Expanded(
              child: _Section(
                title: 'المحفوظات',
                empty: 'لا تسميعَ مسجَّلاً بعد.',
                children: [
                  for (final row in profile.recitations.take(30))
                    ListTile(
                      dense: true,
                      title: Text(_range(row)),
                      subtitle: Text(
                        '${DateFormat('yyyy-MM-dd').format(row.date)} · '
                        '${recitationTypeLabelOf(row.type)}'
                        '${row.grade == null ? '' : ' · ${recitationGradeLabelOf(row.grade!)}'}',
                      ),
                      // الأسطر والنقاط محسوبةٌ على الخادم ومجمَّدة — تُعرض كما وصلت.
                      trailing: Text('${row.points.toStringAsFixed(1)} ن'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'النقاط اليدوية',
                    empty: 'لا نقاطَ يدوية.',
                    children: [
                      for (final row in profile.points.take(20))
                        ListTile(
                          dense: true,
                          title: Text(pointsReasonLabelOf(row.reason)),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(row.awardedOn),
                          ),
                          trailing: Text('${row.points.toStringAsFixed(1)} ن'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'سجل الحضور',
                    empty: 'لا سجلَّ حضور بعد.',
                    children: [
                      for (final entry in profile.attendance.take(30))
                        ListTile(
                          dense: true,
                          title: Text(
                            DateFormat('yyyy-MM-dd').format(entry.date),
                          ),
                          subtitle: entry.note == null
                              ? null
                              : Text(entry.note!),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 8,
                            children: [
                              if (entry.lateMinutes != null)
                                Text('${entry.lateMinutes} د'),
                              AttendanceStatusBadge(
                                status: badgeOf(entry.status),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _range(RecitationRow row) {
    if (row.fromSurah == null || row.toSurah == null) {
      return 'تسميع';
    }

    return '${Quran.name(row.fromSurah!)} ${row.fromAyah ?? ''} '
        '← ${Quran.name(row.toSurah!)} ${row.toAyah ?? ''}';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(empty, style: theme.textTheme.bodySmall),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

/// `AttendanceStatus` ⇒ شارةُ `mousqe_ui` — والحزمةُ لا تعرف تعدادات `mousqe_core`
/// عمداً ([CHECKPOINT-PHASE-6.3.MD §3.1]).
BadgeStatus badgeOf(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => BadgeStatus.present,
  AttendanceStatus.absent => BadgeStatus.absent,
  AttendanceStatus.late => BadgeStatus.late,
  AttendanceStatus.excused => BadgeStatus.excused,
};
