import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart' as ui;

import '../config.dart';
import '../di/app_scope.dart';

/// وصلةُ مكوّنات المزامنة المشتركة بـ[SyncController] هذا التطبيق.
///
/// المكوّناتُ نفسُها في `mousqe_ui` تستقبل حالةً جاهزة ولا تعرف المحرّك؛ وما هنا هو الربطُ
/// بمصادر هذا التطبيق — وهو وحده ما يختلف بين الأستاذ والإدارة.
///
/// على الحاسوب شريطٌ أسفل النافذة ([AppSyncBar]) — المساحةُ واسعة والتفصيلُ ظاهر. وعلى الهاتف
/// زرٌّ في شريط كل شاشةٍ العلوي ([PhoneSyncAction]) يتبدّل شكلُه بالحال، وتفصيلُه في ورقة.
class AppSyncBar extends StatelessWidget {
  const AppSyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).sync;

    return SyncSource(
      builder: (context, snapshot) => ui.SyncBar(
        pendingCount: snapshot.pendingCount,
        isSyncing: snapshot.isSyncing,
        offline: snapshot.offline,
        errorMessage: snapshot.errorMessage,
        lastPulledAt: snapshot.lastPulledAt,
        onSync: controller.syncNow,
        failures: snapshot.failures,
        onRetryFailure: controller.retryFailed,
        onDiscardFailure: controller.discardFailed,
      ),
    );
  }
}

/// زرُّ المزامنة في شريط الشاشة العلوي على الهاتف، ولا شيء على الحاسوب (له [AppSyncBar]).
class PhoneSyncAction extends StatelessWidget {
  const PhoneSyncAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isPhone) {
      return const SizedBox.shrink();
    }

    final controller = AppScope.of(context).sync;

    return SyncSource(
      builder: (context, snapshot) => ui.SyncButton(
        snapshot: snapshot,
        onOpen: () => ui.showSyncSheet(
          context,
          // نطاقُ التطبيق يلفّ `MaterialApp` كلَّه، فالورقةُ تبلغه كما تبلغه الشاشات.
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
