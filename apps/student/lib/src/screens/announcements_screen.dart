import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// إعلاناتُ المعهد والحلقة.
///
/// 🔑 **والترشيحُ وقع في الخادم**: إعلانٌ وُجِّه إلى حلقةٍ ليست له لا يصل جهازَه
/// أصلاً، فلا يعرف بوجوده ([CHECKPOINT-PHASE-8.1.MD §3](../../../../../docs/CHECKPOINT-PHASE-8.1.MD)).
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
            for (final announcement in announcements) _Card(announcement: announcement),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  child: Text(announcement.title, style: theme.textTheme.titleSmall),
                ),
                // «لحلقتي» شارةٌ تقول للقارئ إن الإعلانَ يخصّه هو لا المعهدَ
                // كلَّه — فيقدّر أهميّتَه بلا أن يعرف بقيّةَ المشمولين.
                if (announcement.isForMyCircle)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'لحلقتي',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(announcement.body, style: theme.textTheme.bodyMedium),
            if (announcement.publishedAt case final String at) ...[
              const SizedBox(height: 8),
              Text(
                DateTime.tryParse(at) == null ? at : formatStamp(DateTime.parse(at)),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
