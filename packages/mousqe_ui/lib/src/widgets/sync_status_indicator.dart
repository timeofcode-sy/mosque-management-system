import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// نص + عدد معلّق، بلا منطق مزامنة داخله — يستقبل حالة جاهزة.
///
/// المُزامَنُ بـ success وما ينتظر بـ warning: أيقونةٌ وكلمات معاً، فلا يكفي اللون وحده.
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
    final c = context.nz;
    final synced = pendingCount == 0;
    final color = synced ? c.success : c.warning;
    final label = synced
        ? 'كل التغييرات مُزامَنة'
        : '$pendingCount عملية بانتظار المزامنة';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NzIcon(
          synced ? NzIcons.checkCircle : NzIcons.review,
          size: 16,
          color: color,
        ),
        const SizedBox(width: NzSpace.s2),
        Text(label, style: NzType.label.copyWith(color: color)),
      ],
    );
  }
}
