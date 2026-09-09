import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../di/app_scope.dart';

/// نسخٌ احتياطي محلي لملفّ drift — ✅ م.6.6، وآخرُ بنود المرحلة السادسة.
///
/// ### 🔑 والنسخةُ **لا يُستعاد منها المعهد** — وهذا هو الحدُّ الذي تقوله الشاشة
///
/// مخزنُ drift مرآةُ تيّارٍ يُبثّ من الخادم، والديسكتوبُ لا يصير مصدرَ الحقيقة
/// ([APPS-FEATURES.md §4.3](../../../../../docs/APPS-FEATURES.md)). فما فسد من
/// المخزن يُصلَح **بمسحه وإعادة السحب** — وثمنُه دورةٌ واحدة، وهو نفسُ ما يفعله
/// تبديلُ المعهد (م.6.3). واستعادةُ لقطةٍ قديمة فوقه تصنع مؤشّرَ سحبٍ يشير إلى
/// ماضٍ ومخزناً يخالف الخادمَ بلا أن يشكوَ أحد.
///
/// **فما تحفظه النسخة شيءٌ واحدٌ لا يملكه غيرُها: `pending_operations`** —
/// كتاباتٌ صفّها صاحبُ الجهاز ولم تصل الخادمَ بعد، وليست في أيّ مكانٍ آخر في
/// الدنيا. ولذلك تقول الشاشةُ **كم في الطابور** قبل أن تنسخ، ولذلك لا زرَّ
/// «استعادة» فيها: النسخةُ تُفتح وتُقرأ، لا تُكتب فوق مخزنٍ عامل.
///
/// ### 🔑 والمجلَّدُ في «المستندات» خلافاً لملفّ drift نفسِه
///
/// م.6.3 أخرجت مخزنَ التطبيق من «المستندات» إلى مجلّد بيانات التطبيق، لأن
/// المستخدم لا يعنيه ملفُّ قاعدةٍ في مجلّده اليومي. والنسخةُ **عكسُه تماماً**:
/// هي ملفٌّ يُراد أن يُوجَد وأن يُنسَخ إلى قرصٍ خارجي — فبقاؤها في مجلّدٍ مخفيّ
/// يُبطل غايتَها.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  Directory? _directory;
  List<File> _backups = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'mousqe-backups'));
    final backups = await DatabaseBackup.list(directory);

    if (mounted) {
      setState(() {
        _directory = directory;
        _backups = backups;
      });
    }
  }

  Future<void> _write() async {
    final deps = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final directory = _directory;
    final errorColor = Theme.of(context).colorScheme.error;

    if (directory == null || _busy) {
      return;
    }

    setState(() => _busy = true);

    try {
      final file = await DatabaseBackup.write(deps.db, directory: directory);

      messenger.showSnackBar(
        SnackBar(content: Text('حُفظت النسخة: ${p.basename(file.path)}')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذّر كتابةُ النسخة: $error'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }

      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('نسخٌ احتياطي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Text(
                    'ما الذي تحفظه هذه النسخة؟',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'بياناتُ المعهد كلُّها موجودةٌ على الخادم، وتعود إلى أي جهازٍ '
                    'بأوّل مزامنة. فما تحفظه النسخةُ وحدها هو **ما لم يصل الخادمَ '
                    'بعد**: عملياتُ الطابور التي كُتبت على هذا الجهاز بلا شبكة.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  // 🔑 عدّادُ الطابور هو **حجّةُ الزرّ** لا زينةٌ فوقه: من يرى
                  // «٣ عمليات لم تصل» يعرف لماذا ينسخ اليوم؛ ومن يرى صفراً يعرف
                  // أن جهازه لا يحمل شيئاً فريداً.
                  StreamBuilder<int>(
                    stream: deps.sync.pendingCount,
                    builder: (context, snapshot) {
                      final pending = snapshot.data ?? 0;

                      return Row(
                        spacing: 8,
                        children: [
                          Icon(
                            pending == 0
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            color: pending == 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                          ),
                          Text(
                            pending == 0
                                ? 'الطابورُ فارغ — كلُّ ما على هذا الجهاز وصل الخادم.'
                                : '$pending عمليةً لم تصل الخادمَ بعد — وهي وحدها '
                                      'ما لا يوجد في مكانٍ آخر.',
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(),
                  Text(
                    'ولا زرَّ «استعادة» هنا بقصد: مخزنُ الجهاز مرآةٌ لِما على الخادم، '
                    'وإصلاحُ ما يفسد منه هو تسجيلُ الخروج ثم الدخول — فيُمسح ويُعاد '
                    'سحبُه كاملاً. والنسخةُ ملفُّ SQLite يُفتح ويُقرأ عند الحاجة.',
                    style: theme.textTheme.bodySmall,
                  ),
                  Row(
                    spacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _write,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_alt_outlined, size: 18),
                        label: const Text('احفظ نسخةً الآن'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('تحديث'),
                      ),
                    ],
                  ),
                  if (_directory != null)
                    SelectableText(
                      'المجلّد: ${_directory!.path}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('النسخُ المحفوظة', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_backups.isEmpty)
            const EmptyState(
              message: 'لا نسخةَ محفوظةٌ بعد على هذا الجهاز.',
              icon: Icons.save_alt_outlined,
            )
          else
            for (final file in _backups)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(p.basename(file.path)),
                  subtitle: Text(
                    '${_size(file.lengthSync())} · '
                    '${_moment(file.statSync().modified)}',
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024) {
      return '$bytes بايت';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} كيلوبايت';
    }

    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} ميغابايت';
  }

  static String _moment(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
