import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/connected_action.dart';

/// المناهجُ وبنودُها — ✅ م.6.5.
///
/// وهذه الشاشةُ هي ما كان ينتظر النقطة: `SaveCurriculumItem` قائمٌ منذ م.4.5 بلا
/// غلافٍ في الـAPI ([CHECKPOINT-PHASE-6.2.MD §10] البند 4)، فبُني له في هذه
/// المرحلة `CurriculumAdminController`، وبُني معه `SaveCurriculum` للوعاء.
///
/// **وثلاثةُ أحكامٍ تظهر في الواجهة لأنها في الخادم أصلاً:**
///
/// | الحكم | كيف يظهر |
/// |---|---|
/// | أجزاءُ القرآن الثلاثون **ثابتة** | لا زرَّ إضافةٍ ولا حذفٍ في منهج القرآن — وتحريرُ اسم جزءٍ قائمٍ يبقى متاحاً |
/// | المنهجُ العامّ **يُرى ولا يُحرَّر وعاؤه** | وسمُ «عامّ» بلا زرِّ تحرير، وتُضاف إليه بنودٌ كما في اللوحة |
/// | بندٌ عليه سجلُّ محفوظاتٍ **لا يُحذف** | الحذفُ يعود برسالته العربية من الخادم، فلا يُخفى الزرُّ بشرطٍ لا يعرفه الجهاز |
class CurriculaScreen extends StatelessWidget {
  const CurriculaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('المناهج')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCurriculum(context),
        icon: const Icon(Icons.add),
        label: const Text('منهج جديد'),
      ),
      body: StreamBuilder<List<CurriculumView>>(
        stream: deps.catalog.watchCurricula(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final curricula = snapshot.data!;

          if (curricula.isEmpty) {
            return EmptyState(
              message: 'لم تصل المناهجُ بعد.\n'
                  'القرآنُ والحديثُ والمتون مزروعةٌ عامةً — زامِن الجهازَ لتصلك.',
              icon: Icons.menu_book_outlined,
              onRetry: deps.sync.syncNow,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: curricula.length,
            itemBuilder: (context, index) =>
                _CurriculumCard(curriculum: curricula[index]),
          );
        },
      ),
    );
  }
}

class _CurriculumCard extends StatelessWidget {
  const _CurriculumCard({required this.curriculum});

  final CurriculumView curriculum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          spacing: 8,
          children: [
            Text(curriculum.name),
            if (curriculum.isGlobal)
              Tooltip(
                message: 'منهجٌ مزروعٌ لكل المعاهد — يُرى ولا يُحرَّر وعاؤه',
                child: Chip(
                  label: const Text('عامّ', style: TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${curriculum.typeLabel} · ${curriculum.items.length} بند',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أجزاءُ القرآن ثابتة، فلا زرَّ إضافةٍ أصلاً — لا زرٌّ يُرفض عند الضغط.
            if (!curriculum.isFixedQuran)
              IconButton(
                tooltip: 'بند جديد',
                icon: const Icon(Icons.playlist_add, size: 20),
                onPressed: () => _editItem(context, curriculum),
              ),
            if (!curriculum.isGlobal)
              IconButton(
                tooltip: 'تحرير المنهج',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _editCurriculum(context, curriculum),
              ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          for (final item in curriculum.items)
            ListTile(
              dense: true,
              title: Text(item.name),
              subtitle: Text(
                [
                  item.code,
                  if (item.count != null)
                    '${curriculum.countLabel}: ${item.count}',
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تحرير البند',
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    onPressed: () => _editItem(context, curriculum, item),
                  ),
                  if (!curriculum.isFixedQuran)
                    IconButton(
                      tooltip: 'حذف البند',
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: () => _deleteItem(context, item),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _editCurriculum(
  BuildContext context, [
  CurriculumView? curriculum,
]) async {
  final name = TextEditingController(text: curriculum?.name ?? '');
  var type = curriculum?.type ?? 'custom';

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(curriculum == null ? 'منهج جديد' : 'تحرير المنهج'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم المنهج',
                  border: OutlineInputBorder(),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'النوع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'custom', child: Text('منهج مخصّص')),
                  DropdownMenuItem(value: 'hadith', child: Text('الحديث الشريف')),
                  DropdownMenuItem(value: 'mutun', child: Text('المتون العلمية')),
                ],
                onChanged: (value) => setDialogState(() => type = value ?? type),
              ),
              Text(
                // ولماذا لا «قرآن» في القائمة؟ لأن أجزاءه ثابتةٌ ومزروعةٌ عامةً،
                // ومنهجُ قرآنٍ ثانٍ في معهدٍ واحد لا معنى له.
                'نوعُ «القرآن» مزروعٌ عامّاً بأجزائه الثلاثين، ولا يُنشأ من هنا.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) {
    return;
  }

  await runConnected(
    context,
    () => AppScope.of(context).catalog.saveCurriculum(
          uuid: curriculum?.uuid,
          name: name.text.trim(),
          type: type,
        ),
    success: 'حُفظ المنهج.',
  );
}

Future<void> _editItem(
  BuildContext context,
  CurriculumView curriculum, [
  CurriculumItemView? item,
]) async {
  final name = TextEditingController(text: item?.name ?? '');
  final count = TextEditingController(text: item?.count?.toString() ?? '');
  final countLabel = curriculum.countLabel;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item == null ? 'بند جديد' : 'تحرير البند'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم البند',
                border: OutlineInputBorder(),
              ),
            ),
            // العدّادُ يظهر لنوعه وحده: أحاديثُ الحديث وأبياتُ المتون، ومنه
            // تُشتقّ نقاطُ الطالب (م.4.5). ولا عدّادَ لمنهجٍ مخصّص.
            if (countLabel != null)
              TextField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: countLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );

  if (saved != true || !context.mounted) {
    return;
  }

  await runConnected(
    context,
    () => AppScope.of(context).catalog.saveCurriculumItem(
          uuid: item?.uuid,
          curriculumUuid: curriculum.uuid,
          name: name.text.trim(),
          count: int.tryParse(count.text),
        ),
    success: 'حُفظ البند.',
  );
}

Future<void> _deleteItem(BuildContext context, CurriculumItemView item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('حذف البند'),
      content: Text('يُحذف «${item.name}» نهائياً من المنهج.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  // وبندٌ عليه سجلُّ محفوظاتٍ يعود برسالته من الخادم — الجهازُ لا يعرف من
  // حفظه، فالحكمُ حيث المعرفة.
  await runConnected(
    context,
    () => AppScope.of(context).catalog.deleteCurriculumItem(item.uuid),
    success: 'حُذف البند.',
  );
}
