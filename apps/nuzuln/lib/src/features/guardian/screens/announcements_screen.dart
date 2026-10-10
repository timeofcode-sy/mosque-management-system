import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// إعلاناتُ المعهد وحلقاتِ أبنائك الموجَّهة إلى أولياء الأمور.
///
/// 🔑 **والترشيحُ وقع في الخادم**: إعلانٌ وُجِّه إلى فئةٍ أخرى أو إلى حلقةٍ ليست لك لا يصل جهازَك أصلاً — فليس في
/// هذه الشاشة سطرُ ترشيحٍ واحد. وتُقرأ بلقطةٍ محفوظةٍ تُعرض دون اتصال مع إشعار «لا اتصال».
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
                circleBadge: announcement.isForMyCircle ? 'لحلقة ابني' : null,
              ),
          ],
        ),
      ),
    );
  }
}
