import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// ملف الطالب: حضورُه ونقاطُه ومحفوظاتُه — كلُّها من drift.
///
/// النِّسَبُ والمجاميعُ تُحسب هنا لا تُطلب من الخادم: الإحصاءات المشتقّة خارج
/// المزامنة أصلاً ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md)).
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return StreamBuilder<StudentProfile?>(
      stream: deps.repository.watchStudentProfile(studentId),
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
      padding: const EdgeInsets.all(12),
      children: [
        if (profile.registrationNo != null)
          Text(
            'رقم التسجيل: ${profile.registrationNo}',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
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
          ],
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
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
        const SizedBox(height: 16),
        _Section(title: 'المحفوظات'),
        if (profile.recitations.isEmpty)
          const _Hint('لا تسميعَ مسجَّلاً بعد.')
        else
          for (final row in profile.recitations.take(20))
            ListTile(
              dense: true,
              title: Text(_range(row)),
              subtitle: Text(
                '${DateFormat('yyyy-MM-dd').format(row.date)} · '
                '${recitationTypeLabelOf(row.type)}${row.grade == null ? '' : ' · ${recitationGradeLabelOf(row.grade!)}'}',
              ),
              // الأسطر والنقاط محسوبةٌ على الخادم ومجمَّدة — تُعرض كما وصلت.
              trailing: Text('${row.points.toStringAsFixed(1)} ن'),
            ),
        const SizedBox(height: 8),
        _Section(title: 'النقاط اليدوية'),
        if (profile.points.isEmpty)
          const _Hint('لا نقاطَ يدوية.')
        else
          for (final row in profile.points.take(20))
            ListTile(
              dense: true,
              title: Text(pointsReasonLabelOf(row.reason)),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(row.awardedOn)),
              trailing: Text('${row.points.toStringAsFixed(1)} ن'),
            ),
        const SizedBox(height: 8),
        _Section(title: 'سجل الحضور'),
        if (profile.attendance.isEmpty)
          const _Hint('لا سجلَّ حضور بعد.')
        else
          for (final entry in profile.attendance.take(30))
            ListTile(
              dense: true,
              title: Text(DateFormat('yyyy-MM-dd').format(entry.date)),
              subtitle: entry.note == null ? null : Text(entry.note!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.lateMinutes != null)
                    Text('${entry.lateMinutes} د  '),
                  AttendanceStatusBadge(status: _badge(entry.status)),
                ],
              ),
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

  static BadgeStatus _badge(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => BadgeStatus.present,
    AttendanceStatus.absent => BadgeStatus.absent,
    AttendanceStatus.late => BadgeStatus.late,
    AttendanceStatus.excused => BadgeStatus.excused,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
