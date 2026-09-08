import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart' as ui;

import '../di/app_scope.dart';

/// وصلةُ [SyncBar] المشترك بـ[SyncController] هذا التطبيق.
///
/// الشريطُ نفسه في `mousqe_ui` يستقبل حالةً جاهزة ولا يعرف المحرّك؛ وما هنا هو
/// الربطُ بمصادر هذا التطبيق — وهو وحده ما يختلف بين الأستاذ والديسكتوب.
class AppSyncBar extends StatelessWidget {
  const AppSyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).sync;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return StreamBuilder<int>(
          stream: controller.pendingCount,
          initialData: 0,
          builder: (context, pending) {
            return StreamBuilder<List<PendingOperation>>(
              stream: controller.failedOperations,
              initialData: const [],
              builder: (context, failed) {
                return StreamBuilder<DateTime?>(
                  stream: controller.lastPulledAt,
                  builder: (context, lastPulled) {
                    return ui.SyncBar(
                      pendingCount: pending.data ?? 0,
                      isSyncing: controller.isSyncing,
                      offline: controller.offline,
                      errorMessage: controller.error,
                      lastPulledAt: lastPulled.data,
                      onSync: controller.syncNow,
                      failures: [
                        for (final row in failed.data ?? const <PendingOperation>[])
                          ui.SyncFailureView(
                            opUuid: row.opUuid,
                            type: row.type,
                            reason: row.failedReason ?? '',
                          ),
                      ],
                      onRetryFailure: controller.retryFailed,
                      onDiscardFailure: controller.discardFailed,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
