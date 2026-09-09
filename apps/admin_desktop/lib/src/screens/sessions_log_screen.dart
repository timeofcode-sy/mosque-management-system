import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// سجلُّ جلسات المعهد — **كلُّها لا جلساتُ حلقاتِ صاحب الجهاز**.
///
/// وهو نظيرُ كشف الحلقات في الفرق: نفسُ الاستعلام في `mousqe_core` بمعاملٍ فارغ.
/// وحالةُ كل جلسة تُقرأ منه: مسوّدةٌ تنتظر، ومكتملةٌ يصحّحها حاملُ
/// `attendance.amend`، ومقفلةٌ لا يعدّلها أحد.
class SessionsLogScreen extends StatefulWidget {
  const SessionsLogScreen({super.key});

  @override
  State<SessionsLogScreen> createState() => _SessionsLogScreenState();
}

class _SessionsLogScreenState extends State<SessionsLogScreen> {
  /// ترشيحٌ بالحالة — والمشرفُ يفتح هذه الشاشة ليعرف **ما لم يُقفل بعد** غالباً.
  String? _status;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الجلسات')),
      body: StreamBuilder<List<SessionLogEntry>>(
        stream: deps.circles.watchSessionLog(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;

          if (all.isEmpty) {
            return const EmptyState(
              message: 'لم تُفتح جلساتٌ في المعهد بعد.',
              icon: Icons.event_note_outlined,
            );
          }

          final entries = _status == null
              ? all
              : all.where((entry) => entry.status == _status).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  spacing: 12,
                  children: [
                    SegmentedButton<String?>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: null, label: Text('الكل')),
                        ButtonSegment(value: 'draft', label: Text('مسودّة')),
                        ButtonSegment(
                          value: 'completed',
                          label: Text('مكتملة'),
                        ),
                        ButtonSegment(value: 'locked', label: Text('مقفلة')),
                      ],
                      selected: {_status},
                      onSelectionChanged: (values) =>
                          setState(() => _status = values.first),
                    ),
                    const Spacer(),
                    Text(
                      '${entries.length} جلسة',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? const EmptyState(
                        message: 'لا جلسة بهذه الحالة.',
                        icon: Icons.filter_alt_off_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _SessionCard(entry: entries[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.entry});

  final SessionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          spacing: 16,
          children: [
            Expanded(
              flex: 3,
              child: Text(entry.circleName, style: theme.textTheme.titleSmall),
            ),
            Text(DateFormat('yyyy-MM-dd').format(entry.date)),
            Expanded(
              flex: 4,
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  _StatusChip(status: entry.status),
                  if (entry.present > 0)
                    _Badge(status: BadgeStatus.present, count: entry.present),
                  if (entry.absent > 0)
                    _Badge(status: BadgeStatus.absent, count: entry.absent),
                  if (entry.late > 0)
                    _Badge(status: BadgeStatus.late, count: entry.late),
                  if (entry.excused > 0)
                    _Badge(status: BadgeStatus.excused, count: entry.excused),
                  Text('من ${entry.total}', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status, required this.count});

  final BadgeStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [AttendanceStatusBadge(status: status), Text('$count')],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = status == 'locked';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (locked ? theme.colorScheme.error : theme.colorScheme.primary)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (locked) Icon(Icons.lock, size: 12, color: theme.colorScheme.error),
          Text(
            switch (status) {
              'completed' => 'مكتملة',
              'locked' => 'مقفلة',
              _ => 'مسودّة',
            },
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
