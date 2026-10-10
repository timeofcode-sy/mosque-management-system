import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

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
        load: () async => (await repository.excuses()).ui,
        emptyMessage: 'لم تقدّم إذناً بعد.\n'
            'يُقدَّم الإذنُ من ملفّ الابن قبل موعد الغياب.',
        errorMessageBuilder: messageFor,
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
    final tone = _toneOf(excuse.status);

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
                StatusBadge(
                  excuse.statusLabel,
                  tone: tone,
                  icon: switch (excuse.status) {
                    ExcuseStatus.pending => NzIcons.clock,
                    ExcuseStatus.approved => NzIcons.checkCircle,
                    ExcuseStatus.rejected => NzIcons.xCircle,
                  },
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
                'ينتظر مراجعةَ المعهد — الغيابُ لا يُحتسب غائباً بعذر قبل القبول.',
                style: NzType.caption.copyWith(color: context.nz.warning),
              ),
            ],
            // جوابُ المراجِع: بدونه يرى وليُّ الأمر «مرفوض» بلا سبب فيعاود
            // التقديمَ بنفس الطلب.
            if (excuse.reviewNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(NzSpace.s3),
                decoration: BoxDecoration(
                  color: context.nz.surfaceSunken,
                  borderRadius: BorderRadius.circular(NzRadius.sm),
                ),
                child: Text(excuse.reviewNote!, style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }

  StatusTone _toneOf(ExcuseStatus status) => switch (status) {
        ExcuseStatus.pending => StatusTone.warning,
        ExcuseStatus.approved => StatusTone.success,
        ExcuseStatus.rejected => StatusTone.danger,
      };
}
