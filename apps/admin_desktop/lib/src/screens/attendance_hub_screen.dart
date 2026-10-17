import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import '../widgets/sync_bar.dart';
import 'attendance_screen.dart';
import 'sessions_log_screen.dart';

/// بابُ «التفقّد» — **يومُ المعهد كلُّه في شاشة**.
///
/// وهو ما يفرّقه عن باب «الحلقات»: ذاك كشفٌ يُبحث فيه عن حلقةٍ بعينها، وهذا
/// سؤالٌ واحد يسأله المشرفُ كلَّ صباح — **أيُّ حلقةٍ لم تُتفقَّد اليوم؟** فالحالةُ
/// ظاهرةٌ لكل حلقة قبل أن يفتحها، والترتيبُ يضع ما لم يُفتح أوّلاً.
class AttendanceHubScreen extends StatefulWidget {
  const AttendanceHubScreen({super.key});

  @override
  State<AttendanceHubScreen> createState() => _AttendanceHubScreenState();
}

class _AttendanceHubScreenState extends State<AttendanceHubScreen> {
  late DateTime _date = _today();

  /// الحلقاتُ التي ليس لها دوامٌ في اليوم تُخفى خلف زرّ «التفقّد الاستدراكي» — وتعود
  /// مخفيّةً كلما تبدّل اليوم.
  bool _showMakeup = false;

  static DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    // التاريخُ ثلاثةُ أزرار: في شريط العنوان على الشاشة العريضة، وتحته على الهاتف
    // — اسمُ اليوم كاملاً لا يسعه شريطٌ فيه عنوان.
    final dateNav = [
      IconButton(
        tooltip: 'اليوم السابق',
        icon: const NzIcon(NzIcons.back),
        onPressed: () => _setDate(_date.subtract(const Duration(days: 1))),
      ),
      TextButton.icon(
        onPressed: _pickDate,
        icon: const NzIcon(NzIcons.calendar, size: 18),
        label: Text(formatLongDate(_date)),
      ),
      IconButton(
        tooltip: 'اليوم التالي',
        // لا تفقُّدَ لغدٍ: `showDatePicker` يمنعه، فيُمنع هنا أيضاً وإلا
        // اختلف البابان إلى نفس التاريخ.
        icon: const NzIcon(NzIcons.chevronLeft),
        onPressed: _date.isBefore(_today())
            ? () => _setDate(_date.add(const Duration(days: 1)))
            : null,
      ),
    ];

    // سجلُّ الجلسات هنا لا في «الحلقات»: هو سجلُّ ما تُفقِّد.
    final sessionsLog = IconButton(
      tooltip: 'سجل الجلسات',
      icon: const NzIcon(NzIcons.clock),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SessionsLogScreen()),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('التفقّد'),
        actions: context.isCompact
            ? [const PhoneSyncAction(), sessionsLog]
            : [...dateNav, sessionsLog, const SizedBox(width: 8)],
        bottom: context.isCompact
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: dateNav,
                  ),
                ),
              )
            : null,
      ),
      body: StreamBuilder<List<CircleView>>(
        stream: deps.circles.watchCircles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final circles = snapshot.data!;

          if (circles.isEmpty) {
            return EmptyState(
              message:
                  'لا حلقات في الدورة الجارية.\n'
                  'إن كانت الدورة قد بدأت للتوّ فزامِن الجهازَ ليصلك كشفُها.',
              icon: NzIcons.attendance,
              onRetry: deps.sync.syncNow,
            );
          }

          return StreamBuilder<Set<int>>(
            stream: deps.circles.watchScheduledCircleIds(_date),
            builder: (context, scheduledSnapshot) =>
                StreamBuilder<Map<int, String>>(
                  stream: deps.circles.watchDayStatuses(_date),
                  initialData: const {},
                  builder: (context, statuses) {
                    if (!scheduledSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final byStatus = statuses.data ?? const <int, String>{};
                    final scheduled = scheduledSnapshot.data!;
                    int order(CircleView a, CircleView b) {
                      final rank =
                          _rank(byStatus[a.id]) - _rank(byStatus[b.id]);

                      return rank != 0
                          ? rank
                          : a.shiftName.compareTo(b.shiftName);
                    }

                    // حلقاتُ اليوم: ما له دوامٌ فيه، وما فُتحت له جلسةٌ فيه ولو استدراكاً.
                    final today = [
                      for (final circle in circles)
                        if (scheduled.contains(circle.id) ||
                            byStatus.containsKey(circle.id))
                          circle,
                    ]..sort(order);
                    final others = [
                      for (final circle in circles)
                        if (!today.contains(circle)) circle,
                    ]..sort((a, b) => a.circleName.compareTo(b.circleName));

                    Widget tile(CircleView circle) => _CircleTile(
                      circle: circle,
                      status: byStatus[circle.id],
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AttendanceScreen(circle: circle, date: _date),
                        ),
                      ),
                    );

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (today.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'لا حلقةَ لها دوامٌ ${formatLongDate(_date)}.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        for (final circle in today) ...[
                          tile(circle),
                          const SizedBox(height: 8),
                        ],
                        if (others.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          if (!_showMakeup)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _showMakeup = true),
                              icon: const NzIcon(NzIcons.plus, size: 18),
                              label: Text(
                                'التفقّد الاستدراكي — ${others.length} حلقة بلا دوامٍ اليوم',
                              ),
                            )
                          else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              child: Text(
                                'تفقّدٌ استدراكي — حلقاتٌ ليس لها دوامٌ أساسيٌّ في هذا اليوم',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            for (final circle in others) ...[
                              tile(circle),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ],
                    );
                  },
                ),
          );
        },
      ),
    );
  }

  /// ما لم يُفتح أوّلاً، ثم المسوّدة، ثم ما فُرغ منه — فالشاشة تُقرأ من أعلاها.
  static int _rank(String? status) => switch (status) {
    null => 0,
    'draft' => 1,
    'completed' => 2,
    _ => 3,
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      _setDate(DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// يومٌ آخر يطوي الاستدراكيَّ ثانيةً: حلقاتُ اليوم الجديد غيرُ حلقات السابق.
  void _setDate(DateTime date) => setState(() {
    _date = date;
    _showMakeup = false;
  });
}

class _CircleTile extends StatelessWidget {
  const _CircleTile({
    required this.circle,
    required this.status,
    required this.onOpen,
  });

  final CircleView circle;
  final String? status;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: NzIcon(_icon, color: _color(theme)),
        title: Text(circle.circleName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${circle.shiftName} · ${circle.shiftStartsAtLabel} — '
          '${circle.studentsCount} طالباً'
          '${circle.teachers.isEmpty ? '' : ' — ${circle.teachersLabel}'}',
        ),
        // الهاتف: الحالةُ وحدها في الطرف — السهمُ يأكل عرضاً يحتاجه السطرُ الثاني.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              _label,
              style: theme.textTheme.labelLarge?.copyWith(color: _color(theme)),
            ),
            if (!context.isCompact) const NzIcon(NzIcons.chevronLeft),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }

  String get _icon => switch (status) {
    null => NzIcons.radioOff,
    'draft' => NzIcons.edit,
    'completed' => NzIcons.checkCircle,
    _ => NzIcons.lockClosed,
  };

  String get _label => switch (status) {
    null => 'لم يُفتح',
    'draft' => 'مسودّة',
    'completed' => 'مكتملة',
    _ => 'مقفلة',
  };

  Color _color(ThemeData theme) => switch (status) {
    null => theme.colorScheme.onSurfaceVariant,
    'draft' => theme.colorScheme.primary,
    'completed' => theme.colorScheme.tertiary,
    _ => theme.colorScheme.error,
  };
}
