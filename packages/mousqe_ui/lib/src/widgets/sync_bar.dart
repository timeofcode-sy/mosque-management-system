import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'sync_status_indicator.dart';

/// عمليةٌ رفضها الخادم فعُزلت في الطابور — بلا أنواع الحزمة، فالمكوّن يستقبل
/// حالةً جاهزة كبقيّة `mousqe_ui`.
class SyncFailureView {
  const SyncFailureView({
    required this.opUuid,
    required this.type,
    required this.reason,
  });

  final String opUuid;
  final String type;
  final String reason;
}

/// شريطُ حالة المزامنة: عددُ المعلَّق · آخر سحبٍ ناجح · زرُّ «زامن الآن» ·
/// **والمعزولاتُ التي رفضها الخادم**.
///
/// وجودُه في كل شاشة مقصود: تطبيقٌ يكتب في طابور ولا يُظهر طولَ الطابور يترك
/// صاحبَه يظنّ أن ما سجّله وصل، بينما هو نائمٌ في جهازه منذ ساعات.
///
/// 🔄 م.6.3 — رُفع من `apps/teacher/` إلى الحزمة حين احتاجه الديسكتوب، وكسب في
/// الطريق بابَ المعزولات: عقدُ م.6.2 يقول إنها «تُعرض برسالتها في شريط المزامنة»
/// ولم يكن لها عارضٌ بعد.
class SyncBar extends StatelessWidget {
  const SyncBar({
    super.key,
    required this.pendingCount,
    required this.isSyncing,
    required this.onSync,
    this.failures = const [],
    this.lastPulledAt,
    this.errorMessage,
    this.offline = false,
    this.onRetryFailure,
    this.onDiscardFailure,
    this.trailing,
  });

  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSync;
  final List<SyncFailureView> failures;
  final DateTime? lastPulledAt;

  /// خطأٌ **من الخادم** — انقطاعُ الشبكة يُعرض بـ[offline] لا هنا.
  final String? errorMessage;
  final bool offline;

  final void Function(String opUuid)? onRetryFailure;
  final void Function(String opUuid)? onDiscardFailure;

  /// ما يُلحَق بيمين الشريط — مبدّلُ المعاهد في الديسكتوب مثلاً.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failures.isNotEmpty) _FailureStrip(failures: failures, onOpen: () => _openFailures(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SyncStatusIndicator(pendingCount: pendingCount),
                      _Detail(
                        lastPulledAt: lastPulledAt,
                        errorMessage: errorMessage,
                        offline: offline,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (isSyncing)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'زامن الآن',
                    onPressed: onSync,
                    icon: const Icon(Icons.sync),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFailures(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => _FailuresDialog(
        failures: failures,
        onRetry: onRetryFailure,
        onDiscard: onDiscardFailure,
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.lastPulledAt,
    required this.errorMessage,
    required this.offline,
  });

  final DateTime? lastPulledAt;
  final String? errorMessage;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (errorMessage != null) {
      return Text(
        errorMessage!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    final at = lastPulledAt;
    final label = at == null
        ? 'لم تكتمل مزامنةٌ بعد'
        : 'آخر مزامنة ${DateFormat('yyyy-MM-dd HH:mm').format(at.toLocal())}';

    return Text(
      offline ? '$label · بلا اتصال' : label,
      style: theme.textTheme.bodySmall,
    );
  }
}

/// شريطٌ أحمر فوق حالة المزامنة — لا يختفي حتى يبتّ فيه صاحبُ الجهاز.
class _FailureStrip extends StatelessWidget {
  const _FailureStrip({required this.failures, required this.onOpen});

  final List<SyncFailureView> failures;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.error.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.report_outlined, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${failures.length} عملية رفضها الخادم ولن يُعاد إرسالها',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onOpen, child: const Text('راجِعها')),
        ],
      ),
    );
  }
}

class _FailuresDialog extends StatelessWidget {
  const _FailuresDialog({
    required this.failures,
    required this.onRetry,
    required this.onDiscard,
  });

  final List<SyncFailureView> failures;
  final void Function(String opUuid)? onRetry;
  final void Function(String opUuid)? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('عمليات رفضها الخادم'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'لا تُحذف ولا يُعاد إرسالها تلقائياً: تكرارُ إرسالها لا يجعلها مقبولة. '
              'أصلِح السبب ثم أعِد المحاولة، أو تخلَّ عنها.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: failures.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final failure = failures[index];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(failure.type, style: theme.textTheme.titleSmall),
                    subtitle: Text(failure.reason),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onRetry != null)
                          IconButton(
                            tooltip: 'أعِد المحاولة',
                            onPressed: () => onRetry!(failure.opUuid),
                            icon: const Icon(Icons.refresh),
                          ),
                        if (onDiscard != null)
                          IconButton(
                            tooltip: 'تخلَّ عنها',
                            onPressed: () => onDiscard!(failure.opUuid),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
