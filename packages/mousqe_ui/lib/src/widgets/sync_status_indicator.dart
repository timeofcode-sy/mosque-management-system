import 'package:flutter/material.dart';

/// نص + عدد معلّق، بلا منطق مزامنة داخله — يستقبل حالة جاهزة.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    required this.pendingCount,
    this.lastPulledAt,
  });

  final int pendingCount;
  final DateTime? lastPulledAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = pendingCount == 0
        ? 'كل التغييرات مُزامَنة'
        : '$pendingCount عملية بانتظار المزامنة';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          pendingCount == 0 ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
