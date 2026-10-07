import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// حضوري: الملخّصُ والمنحنى والسجلّ يوماً بيوم.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return Scaffold(
      appBar: AppBar(title: const Text('حضوري')),
      body: SnapshotView<ChildAttendance>(
        load: () async => (await repository.attendance()).ui,
        errorMessageBuilder: messageFor,
        emptyMessage: 'لا سجلَّ حضورٍ بعد.',
        isEmpty: (attendance) => attendance.summary.total == 0,
        builder: (context, attendance) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryGrid(summary: attendance.summary),
            AttendanceTrendChart(
              days: [
                for (final day in attendance.trend)
                  (date: day.date, rate: day.rate, sessions: day.sessions),
              ],
            ),
            const _SectionTitle('السجلّ'),
            for (final row in attendance.recent) _Row(row: row),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final ChildAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  // نسبةٌ `null` تُكتب «—» لا «٠٪» — قاعدةُ م.6.6 على السطح
                  // الذي يقرؤه صاحبُها.
                  value: summary.rate == null ? '—' : '${summary.rate!.toStringAsFixed(1)}٪',
                  label: 'نسبتي',
                  icon: Icons.percent,
                ),
              ),
              Expanded(
                child: StatCard(
                  value: '${summary.total}',
                  label: 'مجموع الجلسات',
                  icon: Icons.event_available_outlined,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: StatCard(value: '${summary.present}', label: 'حاضر')),
              Expanded(child: StatCard(value: '${summary.absent}', label: 'غائب')),
              Expanded(child: StatCard(value: '${summary.late}', label: 'متأخّر')),
              Expanded(child: StatCard(value: '${summary.excused}', label: 'مأذون')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final ChildAttendanceRow row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      // `sessionDate` لا `recordedAt`: هذا يومُ الحضور وذاك لحظةُ كتابة الأستاذ.
      title: Text(row.sessionDate == null ? '—' : formatDay(row.sessionDate!)),
      subtitle: row.note == null ? null : Text(row.note!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.lateMinutes != null && row.lateMinutes! > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text('${row.lateMinutes} د'),
            ),
          AttendanceStatusBadge(status: BadgeStatus.fromValue(row.status.value)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
