import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// التعارضات — **رؤيةً وحكماً**، ✅ م.6.6 فوق نقطتَي م.6.1.
///
/// وهي البابُ الأخير من الخمسةَ عشر، وآخرُ ما كان يضطرّ المشرفَ إلى فتح المتصفّح.
///
/// ### 🔑 وما تفعله ليس «حلَّ التعارض» بل مراجعتَه
///
/// الحسمُ الآليّ يبقى قاعدةً في الخادم (`ResolveAttendanceConflicts` — «الأحدثُ
/// يفوز» بشروطه الأربعة)، لأنه يقع أثناء دفعةٍ لا أمام بشر. وما هنا **محكمةُ
/// استئناف**: تعرض القيمتين المتنازعتين وتسأل أيَّهما تبقى
/// ([APPS-FEATURES.md §4.3](../../../../../docs/APPS-FEATURES.md)).
///
/// ### 🔑 والقراءةُ من الشبكة — وهي الوحيدةُ في التطبيق مع سطح الإدارة
///
/// `sync_conflicts` جدولٌ **لا يُزامَن** ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md)):
/// هو أثرُ الدفعة لا بيانُ المعهد. فلها حالةُ فشلٍ صريحة تميّز «لا شبكة» من
/// «الخادم رفض» — نفسُ ما فعلته `users_screen` في م.6.5، وللسبب نفسِه.
class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({super.key});

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  /// الافتراضيُّ **المعلَّقةُ وحدها** — شاشةُ عملٍ لا سجلّ، كما في «أعذار الغياب».
  String _status = 'pending';

  Future<List<SyncConflict>>? _conflicts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // لا في `initState`: `AppScope.of` تسجّل اعتماداً على `InheritedWidget`،
    // وهو ما لا يجوز قبل أن تُربط الشجرة.
    _conflicts ??= _load();
  }

  Future<List<SyncConflict>> _load() =>
      AppScope.of(context).conflicts.load(status: _status);

  void _reload() => setState(() => _conflicts = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التعارضات'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Row(
              spacing: 12,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pending', label: Text('المعلَّقة')),
                    ButtonSegment(value: 'reviewed', label: Text('المراجَعة')),
                    ButtonSegment(value: 'all', label: Text('الكل')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (value) {
                    _status = value.first;
                    _reload();
                  },
                ),
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<SyncConflict>>(
        future: _conflicts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error!;

            return ErrorState(
              message: isOffline(error)
                  ? 'التعارضاتُ تُقرأ من الخادم — لا من مخزن الجهاز — لأنها '
                        'أثرُ الدفعة لا بيانُ المعهد. أعِد المحاولة حين تعود الشبكة.'
                  : messageFor(error),
              onRetry: _reload,
            );
          }

          final conflicts = snapshot.data ?? const <SyncConflict>[];

          if (conflicts.isEmpty) {
            return EmptyState(
              message: _status == 'pending'
                  ? 'لا تعارضَ ينتظر المراجعة — وهذا هو الحال المعتاد.'
                  : 'لا تعارضَ في هذا المعهد.',
              icon: Icons.rule_folder_outlined,
              onRetry: _reload,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ConflictCard(
              conflict: conflicts[index],
              canReview: AppScope.of(context).session.can('conflicts.review'),
              onResolved: _reload,
            ),
          );
        },
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.canReview,
    required this.onResolved,
  });

  final SyncConflict conflict;
  final bool canReview;
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = conflict.differingKeys;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              spacing: 8,
              children: [
                Text(conflict.tableName, style: theme.textTheme.titleMedium),
                Text(
                  conflict.rowUuid,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (conflict.isPending)
                  const Chip(
                    label: Text('ينتظر المراجعة'),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    label: Text('راجعها ${conflict.reviewedBy ?? '—'}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (conflict.createdAt != null)
              Text(
                'وقع في ${_moment(conflict.createdAt!)}'
                '${conflict.deviceUuid == null ? '' : ' · من جهاز ${conflict.deviceUuid}'}',
                style: theme.textTheme.bodySmall,
              ),
            // 🔑 المفاتيحُ المختلفةُ وحدها. حمولةُ صفِّ تفقّدٍ عشرون مفتاحاً
            // يتطابق تسعةَ عشرَ منها، وعرضُها كلَّها يدفن الخلافَ الذي وقع
            // الحكمُ عليه — ومن يقرّر على نصف الصورة يقرّر خطأً.
            if (keys.isEmpty)
              Text(
                'لا فرقَ بين الحمولتين في هذا الصفّ.',
                style: theme.textTheme.bodySmall,
              )
            else
              _DiffTable(conflict: conflict, keys: keys),
            if (canReview && conflict.isPending)
              Row(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _resolve(context, ConflictDecision.clientWins),
                    icon: const Icon(Icons.smartphone_outlined, size: 18),
                    label: Text(ConflictDecision.clientWins.label),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _resolve(context, ConflictDecision.serverWins),
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: Text(ConflictDecision.serverWins.label),
                  ),
                  Expanded(
                    child: Text(
                      'اعتمادُ قيمة الجهاز يكتبها فعلاً فتصل الأجهزةَ في سحبها '
                      'التالي؛ وإبقاءُ قيمة الخادم ختمٌ بلا كتابة.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(BuildContext context, ConflictDecision decision) async {
    final messenger = ScaffoldMessenger.of(context);
    final deps = AppScope.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      await deps.conflicts.resolve(uuid: conflict.uuid, decision: decision);
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isOffline(error)
                // الحكمُ متّصلٌ بطبعه فلا طابورَ له: من يقلب حكماً ينتظر نتيجته،
                // ولا معنى لأن يُصفّ قرارٌ على تعارضٍ قد يكون حُسم من جهازٍ آخر.
                ? 'الحكمُ في التعارض يحتاج اتصالاً — أعِد المحاولة حين تعود الشبكة.'
                : messageFor(error),
          ),
          backgroundColor: errorColor,
        ),
      );

      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('حُسم التعارض: ${decision.label}.')),
    );

    // قلبُ الحكم كتابةٌ في الخادم، وأثرُها يعود في `sync/pull` لا في ردّ الطلب.
    await deps.sync.syncNow();

    onResolved();
  }

  static String _moment(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _DiffTable extends StatelessWidget {
  const _DiffTable({required this.conflict, required this.keys});

  final SyncConflict conflict;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 32,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 48,
        columns: const [
          DataColumn(label: Text('الحقل')),
          DataColumn(label: Text('قيمةُ الخادم')),
          DataColumn(label: Text('قيمةُ الجهاز')),
        ],
        rows: [
          for (final key in keys)
            DataRow(
              cells: [
                DataCell(Text(key, style: theme.textTheme.bodySmall)),
                DataCell(Text(conflict.serverValueOf(key))),
                DataCell(
                  Text(
                    conflict.clientValueOf(key),
                    style: TextStyle(color: scheme.primary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
