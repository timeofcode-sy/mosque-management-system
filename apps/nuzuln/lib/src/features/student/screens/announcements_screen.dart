import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// إعلاناتُ المعهد والحلقة.
///
/// 🔑 **والترشيحُ وقع في الخادم**: إعلانٌ وُجِّه إلى حلقةٍ ليست له لا يصل جهازَه
/// أصلاً، فلا يعرف بوجوده ([CHECKPOINT-PHASE-8.1.MD §3](../../../../../../../docs/checkpoints/CHECKPOINT-PHASE-8.1.MD)).
/// فليس في هذه الشاشة سطرُ ترشيحٍ واحد — وذاك مقصود.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات')),
      body: SnapshotView<List<Announcement>>(
        load: () async => (await repository.announcements()).ui,
        errorMessageBuilder: messageFor,
        emptyMessage: 'لا إعلاناتٍ بعد.',
        isEmpty: (announcements) => announcements.isEmpty,
        builder: (context, announcements) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final announcement in announcements)
              AnnouncementCard(
                title: announcement.title,
                body: announcement.body,
                publishedAt: announcement.publishedAt,
                circleBadge: announcement.isForMyCircle ? 'لحلقتي' : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// زرُّ الإعلانات في شريط كل لسان — الإعلانُ يُقرأ من أيّ مكانٍ في التطبيق لا من بابٍ واحد.
class AnnouncementsAction extends StatelessWidget {
  const AnnouncementsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'الإعلانات',
      icon: const NzIcon(NzIcons.announcement),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AnnouncementsScreen()),
      ),
    );
  }
}
