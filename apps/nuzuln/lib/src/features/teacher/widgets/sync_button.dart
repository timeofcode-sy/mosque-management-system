import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart' as ui;

import '../di/app_scope.dart';

/// زرُّ المزامنة في شريط الأستاذ العلوي — حلّ محلّ شريط المزامنة السفلي: الحالُ في أيقونةٍ تتبدّل،
/// والتفصيلُ وأفعالُه في ورقةٍ تُفتح منه.
///
/// الزرُّ والورقةُ في `mousqe_ui` يستقبلان حالةً جاهزة ولا يعرفان المحرّك؛ وما هنا هو الربطُ
/// بـ[SyncController] هذا التطبيق.
class AppSyncButton extends StatelessWidget {
  const AppSyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).sync;

    return SyncSource(
      builder: (context, snapshot) => ui.SyncButton(
        snapshot: snapshot,
        onOpen: () => ui.showSyncSheet(
          context,
          // نطاقُ الأستاذ يلفّ التطبيقَ كلَّه، فالورقةُ تبلغه كما تبلغه الشاشات.
          builder: (sheet) => SyncSource(
            builder: (context, snapshot) => ui.SyncPanel(
              snapshot: snapshot,
              onSync: controller.syncNow,
              onRetryFailure: controller.retryFailed,
              onDiscardFailure: controller.discardFailed,
            ),
          ),
        ),
      ),
    );
  }
}

/// حالةُ المزامنة حيّةً من [SyncController]: العدّادُ والمعزولاتُ وآخرُ سحب.
class SyncSource extends StatelessWidget {
  const SyncSource({super.key, required this.builder});

  final Widget Function(BuildContext context, ui.SyncSnapshot snapshot) builder;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).sync;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => StreamBuilder<int>(
        stream: controller.pendingCount,
        initialData: 0,
        builder: (context, pending) => StreamBuilder<List<PendingOperation>>(
          stream: controller.failedOperations,
          initialData: const [],
          builder: (context, failed) => StreamBuilder<DateTime?>(
            stream: controller.lastPulledAt,
            builder: (context, lastPulled) => builder(
              context,
              ui.SyncSnapshot(
                pendingCount: pending.data ?? 0,
                isSyncing: controller.isSyncing,
                offline: controller.offline,
                errorMessage: controller.error,
                lastPulledAt: lastPulled.data,
                failures: [
                  for (final row in failed.data ?? const <PendingOperation>[])
                    ui.SyncFailureView(
                      opUuid: row.opUuid,
                      type: row.type,
                      reason: row.failedReason ?? '',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
