import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// حفظي: بنودُ المحفوظات مجمَّعةً باسم المنهج.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;

    return Scaffold(
      appBar: AppBar(title: const Text('حفظي')),
      body: SnapshotView<CurriculumProgressReport>(
        load: () async => (await repository.progress()).ui,
        errorMessageBuilder: messageFor,
        emptyMessage: 'لم يُسجَّل تقدُّمٌ في المحفوظات بعد.',
        isEmpty: (report) => report.isEmpty,
        builder: (context, report) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final curriculum in report.curricula) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(curriculum, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final entry in report.byCurriculum[curriculum]!)
                _Entry(entry: entry),
            ],
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry});

  final CurriculumProgressEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(entry.itemName ?? '—'),
      subtitle: entry.percent == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: (entry.percent! / 100).clamp(0, 1).toDouble(),
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // النصُّ العربي من الخادم لا من ترجمةٍ ثانية ههنا.
          Text(entry.statusLabel, style: theme.textTheme.labelLarge),
          if (entry.score != null)
            Text('الدرجة ${entry.score}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
