import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// مراجعةُ أعذار الغياب — ✅ م.6.5، نوعُ `excuse.review`.
///
/// وهي **الفجوةُ المسمّاة** في [APPS-FEATURES.md §4.2](../../../../../docs/APPS-FEATURES.md)
/// البند 4: كان في أنواع الطابور `excuse.submit` (تقديمٌ من وليّ الأمر) بلا
/// مراجعة، فكان على المشرف أن يفتح المتصفّح ليقبل إذناً — وهو يبتّ فيها وهو في
/// المسجد لا على مكتبه.
///
/// **وقبولُ الإذن يصحّح الماضي بنفسه:** `ReviewAbsenceExcuse` يحوّل غيابَ الجلسات
/// غيرِ المقفلة في مدّته إلى «مأذون» داخل معاملته، فلا يفتح المشرفُ جلساتٍ
/// ويصحّحها واحدةً واحدة. **والمقفلةُ لا تُمسّ** — القفلُ نهائيّ.
class ExcusesScreen extends StatefulWidget {
  const ExcusesScreen({super.key});

  @override
  State<ExcusesScreen> createState() => _ExcusesScreenState();
}

class _ExcusesScreenState extends State<ExcusesScreen> {
  /// الافتراضيُّ **المعلَّقةُ وحدها**: هذه شاشةُ عملٍ لا سجلٌّ، وما بُتَّ فيه
  /// انتهى أمرُه.
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أعذار الغياب'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('المعلَّقة')),
                ButtonSegment(value: 'all', label: Text('الكل')),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ExcuseView>>(
        stream: deps.students.watchExcuses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final excuses = snapshot.data!
              .where((excuse) => _filter == 'all' || excuse.isPending)
              .toList();

          if (excuses.isEmpty) {
            return EmptyState(
              message: _filter == 'pending'
                  ? 'لا إذنَ ينتظر المراجعة.'
                  : 'لم يصل أيُّ إذنِ غيابٍ بعد.',
              icon: Icons.mark_email_read_outlined,
              onRetry: deps.sync.syncNow,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: excuses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ExcuseCard(
              excuse: excuses[index],
              canReview: deps.session.can('excuses.review'),
            ),
          );
        },
      ),
    );
  }
}

class _ExcuseCard extends StatelessWidget {
  const _ExcuseCard({required this.excuse, required this.canReview});

  final ExcuseView excuse;
  final bool canReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Text(excuse.studentName, style: theme.textTheme.titleMedium),
                _StatusChip(excuse: excuse),
                const Spacer(),
                Text(
                  '${_date(excuse.fromDate)} ← ${_date(excuse.toDate)}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            Text(excuse.reason),
            if (excuse.reviewNote != null)
              Text(
                'ملاحظة المراجعة: ${excuse.reviewNote}',
                style: theme.textTheme.bodySmall,
              ),
            // البتُّ يظهر لمن يملكه وحده، والمبتوتُ فيه لا يُعاد البتُّ فيه —
            // ولا زرَّ معطَّلاً في الحالتين.
            if (canReview && excuse.isPending)
              Row(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _review(context, approve: true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('قبول'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _review(context, approve: false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('رفض'),
                  ),
                  Text(
                    'القبولُ يحوّل غيابَ الجلسات غير المقفلة في هذه المدّة إلى «مأذون».',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, {required bool approve}) async {
    final note = await _askNote(context, approve: approve);

    if (note == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    await AppScope.of(context).students.reviewExcuse(
          excuseUuid: excuse.uuid,
          approve: approve,
          note: note,
        );

    messenger.showSnackBar(
      SnackBar(
        content: Text(approve ? 'قُبل الإذن وصُفَّ للمزامنة.' : 'رُفض الإذن وصُفَّ للمزامنة.'),
      ),
    );
  }

  /// `null` تعني إلغاءً، والنصُّ الفارغ يعني «بلا ملاحظة» — والفرقُ بينهما هو
  /// ما يمنع أن يصير الضغطُ على «إلغاء» بتّاً صامتاً.
  Future<String?> _askNote(BuildContext context, {required bool approve}) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approve ? 'قبول الإذن' : 'رفض الإذن'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختيارية)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(approve ? 'قبول' : 'رفض'),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.excuse});

  final ExcuseView excuse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground) = switch (excuse.status) {
      'approved' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'rejected' => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (excuse.pending)
            Icon(Icons.cloud_upload_outlined, size: 14, color: foreground),
          Text(
            excuse.statusLabel,
            style: TextStyle(color: foreground, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
