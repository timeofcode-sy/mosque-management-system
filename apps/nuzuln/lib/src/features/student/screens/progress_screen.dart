import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../../../widgets/recitation_log.dart';
import '../di/app_scope.dart';
import 'announcements_screen.dart';

/// حفظي: شريطُ الأجزاء، وتحته سجلُّ التسميع يوماً بيوم.
///
/// كان تحت الشريط نسبةٌ مئوية لكل جزء — تكرارٌ للشريط نفسِه بلونٍ آخر. والسجلُّ يقول ما
/// لا يقوله الشريط: ماذا سمّعتُ، ومتى، وبأيّ تقدير.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حفظي'),
        actions: const [AnnouncementsAction()],
      ),
      body: SnapshotView<(CurriculumProgressReport, List<RecitationLogEntry>)>(
        load: () async {
          final (progress, recitations) = await (repository.progress(), _recitations(repository)).wait;

          return (
            value: (progress.value, recitations.value),
            fetchedAt: progress.fetchedAt,
            isStale: progress.isStale || recitations.isStale,
          );
        },
        errorMessageBuilder: messageFor,
        builder: (context, data) {
          final (report, recitations) = data;
          final juz = JuzSummary.fromEntries(report.byCurriculum.values.expand((rows) => rows));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JuzProgressCard(
                memorized: juz.memorized,
                current: juz.current,
                title: 'أجزائي',
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              ),
              RecitationLog(entries: recitations),
            ],
          );
        },
      ),
    );
  }

  /// السجلُّ تكملةٌ للشريط لا شرطٌ له: خادمٌ أقدمُ بلا نقطته يعرض الشريطَ وحده.
  static Future<Snapshot<List<RecitationLogEntry>>> _recitations(StudentSelfRepository repository) async {
    try {
      return await repository.recitations();
    } on Object {
      return const Snapshot(<RecitationLogEntry>[]);
    }
  }
}
