import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/attendance_trend_chart.dart';
import '../widgets/snapshot_view.dart';
import 'submit_excuse_screen.dart';

/// ملفُّ ابنٍ بعينه — لسانان: حضورُه، وتقدُّمُ حفظه.
class ChildScreen extends StatelessWidget {
  const ChildScreen({super.key, required this.child});

  final GuardianChild child;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(child.fullName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الحضور', icon: Icon(Icons.fact_check_outlined)),
              Tab(text: 'الحفظ', icon: Icon(Icons.menu_book_outlined)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => SubmitExcuseScreen(child: child)),
          ),
          icon: const Icon(Icons.event_busy_outlined),
          label: const Text('تقديم إذن'),
        ),
        body: TabBarView(
          children: [
            _AttendanceTab(childUuid: child.uuid),
            _ProgressTab(childUuid: child.uuid),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.childUuid});

  final String childUuid;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return SnapshotView<ChildAttendance>(
      load: () => repository.attendanceOf(childUuid),
      emptyMessage: 'لا سجلَّ حضورٍ بعد.',
      isEmpty: (attendance) => attendance.summary.total == 0,
      builder: (context, attendance) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryGrid(summary: attendance.summary),
          AttendanceTrendChart(days: attendance.trend),
          const _SectionTitle('السجلّ — آخر ٣٠ يوم تفقّد'),
          for (final row in attendance.recent) _AttendanceRow(row: row),
        ],
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
              // 🔑 نسبةٌ `null` تُكتب «لا قياس» لا «٠٪»: طالبٌ كلُّ سجلّاته
              // أعذارٌ لا مقامَ له، وصفرٌ ههنا يقول إنه لم يحضر يوماً.
              Expanded(
                child: StatCard(
                  value: summary.rate == null ? '—' : '${summary.rate!.toStringAsFixed(1)}٪',
                  label: 'نسبة الحضور',
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

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.row});

  final ChildAttendanceRow row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      // 🔑 `sessionDate` لا `recordedAt`: هذا يومُ الحضور وذاك لحظةُ كتابة
      // الأستاذ، وتصحيحٌ رجعيٌّ يفرّق بينهما يوماً أو أكثر.
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
          AttendanceStatusBadge(status: badgeOf(row.status)),
        ],
      ),
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.childUuid});

  final String childUuid;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return SnapshotView<CurriculumProgressReport>(
      load: () => repository.progressOf(childUuid),
      emptyMessage: 'لم يُسجَّل تقدُّمٌ في المحفوظات بعد.',
      isEmpty: (report) => report.isEmpty,
      builder: (context, report) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final curriculum in report.curricula) ...[
            _SectionTitle(curriculum),
            for (final entry in report.byCurriculum[curriculum]!)
              _ProgressRow(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.entry});

  final CurriculumProgressEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(entry.itemName ?? '—'),
      subtitle: entry.percent == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: (entry.percent! / 100).clamp(0, 1).toDouble(),
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // النصُّ العربي من الخادم لا من ترجمةٍ ثانية ههنا.
          Text(entry.statusLabel, style: theme.textTheme.labelLarge),
          if (entry.score != null)
            Text('الدرجة ${entry.score}', style: theme.textTheme.bodySmall),
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
