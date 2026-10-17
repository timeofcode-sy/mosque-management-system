import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../../../widgets/behavior_section.dart';
import '../../../widgets/recitation_log.dart';
import '../di/app_scope.dart';

/// ألسنةُ ابنٍ بعينه في الشريط السفلي — حضورُه، وحفظُه، وجانبُه السلوكي.
///
/// كانت ألسنةً علويّةً في صفحةٍ تُفتح من قائمة الأبناء؛ وصارت ألسنةَ الشريط السفلي نفسَه
/// ([GuardianShell])، والابنُ يُختار من رأس الشاشة حين يكون للحساب أكثرُ من ابن.
class ChildAttendanceView extends StatelessWidget {
  const ChildAttendanceView({super.key, required this.childUuid});

  final String childUuid;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return SnapshotView<ChildAttendance>(
      load: () async => (await repository.attendanceOf(childUuid)).ui,
      emptyMessage: 'لا سجلَّ حضورٍ بعد.',
      errorMessageBuilder: messageFor,
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
          const _SectionTitle('السجلّ — آخر 30 يوم تفقّد'),
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
    // الهامشُ بين البطاقات هنا لا فيها: بطاقاتُ الثيم بلا هامش.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              // 🔑 نسبةٌ `null` تُكتب «لا قياس» لا «٠%»: طالبٌ كلُّ سجلّاته
              // أعذارٌ لا مقامَ له، وصفرٌ ههنا يقول إنه لم يحضر يوماً.
              Expanded(
                child: StatCard(
                  value: summary.rate == null
                      ? '—'
                      : '${summary.rate!.toStringAsFixed(1)}%',
                  label: 'نسبة الحضور',
                  icon: NzIcons.percent,
                ),
              ),
              Expanded(
                child: StatCard(
                  value: '${summary.total}',
                  label: 'مجموع الجلسات',
                  icon: NzIcons.calendar,
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: StatCard(value: '${summary.present}', label: 'حاضر'),
              ),
              Expanded(
                child: StatCard(value: '${summary.absent}', label: 'غائب'),
              ),
              Expanded(
                child: StatCard(value: '${summary.late}', label: 'متأخّر'),
              ),
              Expanded(
                child: StatCard(
                  value: '${summary.excused}',
                  label: 'غائب بعذر',
                ),
              ),
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
          AttendanceStatusBadge(
            status: BadgeStatus.fromValue(row.status.value),
          ),
        ],
      ),
    );
  }
}

/// الجانبُ السلوكي: ما كتبه أساتذتُه عنه في التفقّد، وصفاتُه، ونقاطُ سلوكه.
class ChildBehaviorView extends StatelessWidget {
  const ChildBehaviorView({super.key, required this.childUuid});

  final String childUuid;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return SnapshotView<StudentBehavior>(
      load: () async => (await repository.behaviorOf(childUuid)).ui,
      errorMessageBuilder: messageFor,
      builder: (context, behavior) => BehaviorSection(behavior: behavior),
    );
  }
}

/// الحفظ: شريطُ الأجزاء، وتحته سجلُّ التسميع يوماً بيوم — لا نسبةٌ مئوية لكل جزء.
class ChildProgressView extends StatelessWidget {
  const ChildProgressView({super.key, required this.childUuid});

  final String childUuid;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return SnapshotView<(CurriculumProgressReport, List<RecitationLogEntry>)>(
      load: () async {
        final (progress, recitations) = await (repository.progressOf(childUuid), _recitations(repository)).wait;

        return (
          value: (progress.value, recitations.value),
          fetchedAt: progress.fetchedAt,
          isStale: progress.isStale || recitations.isStale,
        );
      },
      errorMessageBuilder: messageFor,
      builder: (context, data) {
        final (report, recitations) = data;
        final juz = JuzSummary.fromEntries(report.byCurriculum.values.expand((rows) => rows));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JuzProgressCard(
              memorized: juz.memorized,
              current: juz.current,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            ),
            RecitationLog(entries: recitations),
          ],
        );
      },
    );
  }

  /// السجلُّ تكملةٌ للشريط لا شرطٌ له: خادمٌ أقدمُ بلا نقطته يعرض الشريطَ وحده.
  Future<Snapshot<List<RecitationLogEntry>>> _recitations(GuardianRepository repository) async {
    try {
      return await repository.recitationsOf(childUuid);
    } on Object {
      return const Snapshot(<RecitationLogEntry>[]);
    }
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
