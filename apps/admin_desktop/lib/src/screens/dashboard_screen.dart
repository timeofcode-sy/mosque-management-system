import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'student_profile_screen.dart' show badgeOf;

/// داشبورد المعهد — ✅ م.6.6، **محسوبٌ على الجهاز** من الصفوف المتزامنة.
///
/// وهو أوّلُ ما يفتحه المشرفُ كلَّ صباح، فقُدِّم على الأبواب كلِّها في القائمة.
/// وسؤالُه واحد: **«أين وصل اليومُ في المعهد؟»** — وهو نظيرُ `attendance_hub`
/// في م.6.4 مرفوعاً من الحلقة إلى المعهد كلِّه.
///
/// **ولا طلبَ شبكةٍ واحد فيه:** `circle_daily_stats` جدولٌ خادميٌّ لا يُزامَن،
/// وأرقامُه تُحسب هنا من `attendances` عبر [StatsRepository]. فيُفتح والشبكةُ
/// مقطوعة كما تُفتح شاشةُ التفقّد.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الداشبورد'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: TextButton.icon(
              onPressed: deps.sync.syncNow,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('مزامنة الآن'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<InstituteOverview>(
        stream: deps.stats.watchOverview(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final overview = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Counters(counters: overview.counters),
              const SizedBox(height: 16),
              if (!overview.hasCurrentCourse)
                // معهدٌ بلا دورةٍ جارية لا كشفَ له — ولا معنى لرسم صفرٍ عنه.
                const EmptyState(
                  message:
                      'لا دورةَ جاريةٌ في هذا المعهد بعد. تُهيَّأ الدورةُ ودواماتُها '
                      'وحلقاتُها من باب «الدورات والدوامات»، ثم تظهر أرقامُها هنا.',
                  icon: Icons.calendar_month_outlined,
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _TrendCard(
                        trend: overview.trend,
                        todayRate: overview.todayRate,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _BreakdownCard(breakdown: overview.breakdown),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _StandingsCard(standings: overview.standings),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.counters});

  final InstituteCounters counters;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: StatCard(
            value: '${counters.students}',
            label: 'طالبٌ في المعهد',
            icon: Icons.school_outlined,
          ),
        ),
        Expanded(
          child: StatCard(
            value: '${counters.enrolled}',
            label: 'مسجَّلٌ في الدورة الجارية',
            icon: Icons.how_to_reg_outlined,
          ),
        ),
        Expanded(
          child: StatCard(
            value: '${counters.circles}',
            label: 'حلقةٌ مشغَّلة',
            icon: Icons.groups_2_outlined,
          ),
        ),
        Expanded(
          child: StatCard(
            value: '${counters.teachers}',
            label: 'أستاذاً',
            icon: Icons.person_outline,
          ),
        ),
      ],
    );
  }
}

/// منحنى أسبوعين — أعمدةٌ لا خطّ، لأن الأيام منفصلةٌ لا متّصلة.
///
/// **واليومُ بلا جلسةٍ فراغٌ لا عمودٌ بطول صفر**: العطلةُ ليست يومَ حضورٍ سيّئاً،
/// ولو رُسمت صفراً لَقرأ المشرفُ منحنىً يهبط كلَّ جمعة.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend, required this.todayRate});

  final List<TrendPoint> trend;
  final double? todayRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final measured = trend.where((point) => point.rate != null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              children: [
                Text('حضورُ آخر أسبوعين', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  todayRate == null
                      // «لم تُقَس» خبرٌ غيرُ «قِيست فكانت صفراً» — والفرقُ بينهما
                      // هو الفرقُ بين يومٍ لم يبدأ ويومٍ غاب فيه الجميع.
                      ? 'اليوم: لم يُسجَّل تفقّدٌ بعد'
                      : 'اليوم: ${_percent(todayRate)}',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            if (measured.isEmpty)
              Text(
                'لا صفَّ حضورٍ في هذه المدّة بعد.',
                style: theme.textTheme.bodySmall,
              )
            else
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in trend)
                      Expanded(child: _TrendBar(point: point)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.point});

  final TrendPoint point;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = point.rate;

    return Tooltip(
      message: rate == null
          ? '${point.date.day}/${point.date.month} — لا جلسة'
          : '${point.date.day}/${point.date.month} — ${_percent(rate)}'
              ' في ${point.sessions} جلسة',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (rate != null)
              Container(
                height: 8 + rate / 100 * 100,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              )
            else
              // فراغٌ موسوم: خطٌّ رفيعٌ يقول «هنا يومٌ لم يُقَس» بدل عمودٍ يكذب.
              Container(height: 2, color: scheme.outlineVariant),
            const SizedBox(height: 4),
            Text('${point.date.day}', style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});

  final StatusBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text('توزيعُ الحالات', style: theme.textTheme.titleMedium),
            for (final status in AttendanceStatus.values)
              Row(
                children: [
                  AttendanceStatusBadge(status: badgeOf(status)),
                  const Spacer(),
                  Text('${breakdown.countOf(status)}'),
                ],
              ),
            const Divider(height: 8),
            Row(
              children: [
                Text('المجموع', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text('${breakdown.total}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.standings});

  final List<CircleStanding> standings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (standings.isEmpty) {
      return const EmptyState(
        message: 'لا حلقةَ مشغَّلةٌ في الدورة الجارية بعد.',
        icon: Icons.groups_2_outlined,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text('ترتيبُ الحلقات في دوامها', style: theme.textTheme.titleMedium),
            Text(
              'الترتيبُ داخلَ كل دوامٍ على حدة — حلقةُ الفجر لا تُقاس بحلقة العصر.',
              style: theme.textTheme.bodySmall,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('الحلقة')),
                  DataColumn(label: Text('الدوام')),
                  DataColumn(label: Text('الأساتذة')),
                  DataColumn(label: Text('الطلاب')),
                  DataColumn(label: Text('الجلسات')),
                  DataColumn(label: Text('النسبة')),
                ],
                rows: [
                  for (final row in standings)
                    DataRow(
                      cells: [
                        DataCell(Text(row.rank?.toString() ?? '—')),
                        DataCell(Text(row.circleName)),
                        DataCell(Text(row.shiftName)),
                        DataCell(Text(row.teachersLabel)),
                        DataCell(Text('${row.studentsCount}')),
                        DataCell(Text('${row.sessionsCount}')),
                        DataCell(
                          Text(
                            // حلقةٌ بلا صفِّ حضورٍ واحد لا تُرسم صفراً: لم تُقَس
                            // بعد، وهي ليست أسوأَ من حلقةٍ غاب طلابُها.
                            row.rate == null ? 'لم تُقَس' : _percent(row.rate),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _percent(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}٪';
