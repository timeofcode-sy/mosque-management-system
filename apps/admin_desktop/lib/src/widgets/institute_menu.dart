import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';

/// ترويسةُ القائمة الجانبية: اسمُ المعهد العامل، **ومبدّلُه لمن له أكثر من معهد**.
///
/// لا يظهر المبدّلُ لمديرِ معهدٍ واحد: `institutes.manage` منزوعةٌ من `admin`
/// عمداً ([APPS-FEATURES.md §4.3])، فقائمتُه معهدٌ واحد ولا معنى لزرٍّ يفتحها.
class InstituteMenu extends StatelessWidget {
  const InstituteMenu({super.key, this.compact = false});

  /// نسخةٌ بلا ترويسة — تُعرض في شاشة «لا أبواب» حيث لا قائمةَ جانبية أصلاً.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dependencies = AppScope.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        dependencies.session,
        dependencies.institutes,
      ]),
      builder: (context, _) {
        final snapshot = dependencies.session.snapshot;
        final switcher = dependencies.institutes;

        if (compact && !switcher.hasChoice) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot?.institute.name ?? 'موسقي',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      snapshot?.courseName ?? 'لا دورةَ جارية',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (switcher.hasChoice)
                IconButton(
                  tooltip: 'بدّل المعهد',
                  icon: const Icon(Icons.unfold_more, size: 20),
                  onPressed: () => _open(context, dependencies),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    AppDependencies dependencies,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showDialog<InstituteOption>(
      context: context,
      builder: (context) => _InstitutePicker(
        options: dependencies.institutes.options,
        currentUuid: dependencies.session.snapshot?.institute.uuid,
      ),
    );

    if (chosen == null) {
      return;
    }

    try {
      await dependencies.institutes.switchTo(chosen.uuid);
    } on PendingWorkBlocksSwitch catch (blocked) {
      // ليست خطأً بل رفضٌ مبرَّر: كتاباتٌ لم تصل الخادم بعد، ومسحُ المخزن يمحوها.
      messenger.showSnackBar(SnackBar(content: Text(blocked.message)));
    } on Object catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(failure))));
    }
  }
}

class _InstitutePicker extends StatelessWidget {
  const _InstitutePicker({required this.options, required this.currentUuid});

  final List<InstituteOption> options;
  final String? currentUuid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('بدّل المعهد'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'التبديلُ يمسح مخزنَ هذا الجهاز ويسحب المعهدَ الجديد من الصفر — '
              'فقد يستغرق دقائق على معهدٍ قائمٍ منذ شهور.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      leading: Icon(
                        option.uuid == currentUuid
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(option.name),
                      subtitle: option.isActive ? null : const Text('موقوف'),
                      onTap: option.uuid == currentUuid
                          ? null
                          : () => Navigator.of(context).pop(option),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
