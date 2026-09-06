import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../data/views.dart';
import '../di/app_scope.dart';
import '../widgets/sync_bar.dart';

/// سجل الجلسات — مقروءاً من drift، ومرشَّحاً **بحلقات الأستاذ**.
///
/// الترشيح صريح لا مفترَض: `sync/pull` يجلب معهداً كاملاً، فالجهاز يخزّن جلسات
/// حلقاتٍ ليست له ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 7).
class SessionsLogScreen extends StatelessWidget {
  const SessionsLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final teacherUuid = deps.session.teacherUuid;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الجلسات')),
      body: Column(
        children: [
          const SyncBar(),
          const Divider(height: 1),
          Expanded(
            child: teacherUuid == null
                ? const EmptyState(
                    message: 'لا بيانات أستاذ على هذا الجهاز بعد.',
                  )
                : StreamBuilder<List<SessionLogEntry>>(
                    stream: deps.repository.watchSessionLog(teacherUuid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final entries = snapshot.data!;

                      if (entries.isEmpty) {
                        return const EmptyState(
                          message: 'لم تُفتح جلساتٌ في حلقاتك بعد.',
                          icon: Icons.event_note_outlined,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _SessionCard(entry: entries[index]),
                      );
                    },
                  ),
          ),
        ],
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.circleName,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(DateFormat('yyyy-MM-dd').format(entry.date)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(label: _statusLabel(entry.status)),
                if (entry.present > 0)
                  _Badge(status: BadgeStatus.present, count: entry.present),
                if (entry.absent > 0)
                  _Badge(status: BadgeStatus.absent, count: entry.absent),
                if (entry.late > 0)
                  _Badge(status: BadgeStatus.late, count: entry.late),
                if (entry.excused > 0)
                  _Badge(status: BadgeStatus.excused, count: entry.excused),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'completed' => 'مكتملة',
    'locked' => 'مقفلة',
    _ => 'مسودّة',
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status, required this.count});

  final BadgeStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AttendanceStatusBadge(status: status),
        const SizedBox(width: 4),
        Text('$count'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}
