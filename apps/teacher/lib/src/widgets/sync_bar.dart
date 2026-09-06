import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../state/sync_controller.dart';

/// شريطُ حالة المزامنة: عددُ المعلَّق · آخر سحبٍ ناجح · زرُّ «زامن الآن».
///
/// وجودُه في كل شاشة مقصود: تطبيقٌ يكتب في طابور ولا يُظهر طولَ الطابور يترك
/// الأستاذ يظنّ أن ما سجّله وصل، بينما هو نائمٌ في جهازه منذ ساعات.
class SyncBar extends StatelessWidget {
  const SyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).sync;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return StreamBuilder<int>(
          stream: controller.pendingCount,
          initialData: 0,
          builder: (context, pending) {
            return Material(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SyncStatusIndicator(pendingCount: pending.data ?? 0),
                          _Detail(controller: controller),
                        ],
                      ),
                    ),
                    if (controller.isSyncing)
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        tooltip: 'زامن الآن',
                        onPressed: controller.syncNow,
                        icon: const Icon(Icons.sync),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.error != null) {
      return Text(
        controller.error!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    return StreamBuilder<DateTime?>(
      stream: controller.lastPulledAt,
      builder: (context, snapshot) {
        final at = snapshot.data;
        final label = at == null
            ? 'لم تكتمل مزامنةٌ بعد'
            : 'آخر مزامنة ${DateFormat('yyyy-MM-dd HH:mm').format(at.toLocal())}';

        return Text(
          controller.offline ? '$label · بلا اتصال' : label,
          style: theme.textTheme.bodySmall,
        );
      },
    );
  }
}
