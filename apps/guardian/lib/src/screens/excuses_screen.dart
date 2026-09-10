import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';
import '../widgets/snapshot_view.dart';

/// أعذارُ أبنائه وحالتُها — ومعها **جوابُ الطاقم** حين يصل.
///
/// نقطتُها (`GET /guardian/excuses`) بُنيت في م.7.1 لأن وليَّ الأمر خرج من
/// `sync/pull`: كانت مراجعةُ اللوحة تصله كتغييرٍ في التيّار، فبلا هذه الشاشة
/// يقدّم إذناً ثم لا يرى جوابَه أبداً.
class ExcusesScreen extends StatelessWidget {
  const ExcusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return Scaffold(
      appBar: AppBar(title: const Text('أذونات الغياب')),
      body: SnapshotView<List<GuardianExcuse>>(
        load: repository.excuses,
        emptyMessage: 'لم تقدّم إذناً بعد.\n'
            'يُقدَّم الإذنُ من ملفّ الابن قبل موعد الغياب.',
        isEmpty: (excuses) => excuses.isEmpty,
        builder: (context, excuses) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final excuse in excuses) _ExcuseCard(excuse: excuse)],
        ),
      ),
    );
  }
}

class _ExcuseCard extends StatelessWidget {
  const _ExcuseCard({required this.excuse});

  final GuardianExcuse excuse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _toneOf(theme, excuse.status);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    excuse.studentName ?? '—',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                // 🔑 الحالةُ بلونها الصريح: «قيد المراجعة» ليست قبولاً، ولو
                // عُرضت بلا تمييزٍ لَقرأ مقدِّمُها التقديمَ إذناً
                // ([PHASE-7-STAGES.MD §4] القاعدة الثانية).
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tone),
                  ),
                  child: Text(
                    excuse.statusLabel,
                    style: theme.textTheme.labelMedium?.copyWith(color: tone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'من ${formatDay(excuse.fromDate)} إلى ${formatDay(excuse.toDate)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (excuse.reason != null) ...[
              const SizedBox(height: 4),
              Text(excuse.reason!, style: theme.textTheme.bodySmall),
            ],
            if (excuse.isPending) ...[
              const SizedBox(height: 8),
              Text(
                'ينتظر مراجعةَ المعهد — الغيابُ لا يُحتسب مأذوناً قبل القبول.',
                style: theme.textTheme.bodySmall?.copyWith(color: tone),
              ),
            ],
            // جوابُ المراجِع: بدونه يرى وليُّ الأمر «مرفوض» بلا سبب فيعاود
            // التقديمَ بنفس الطلب.
            if (excuse.reviewNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(excuse.reviewNote!, style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _toneOf(ThemeData theme, ExcuseStatus status) => switch (status) {
        ExcuseStatus.pending => const Color(0xFFC9A227),
        ExcuseStatus.approved => const Color(0xFF177F5C),
        ExcuseStatus.rejected => const Color(0xFFB42318),
      };
}
