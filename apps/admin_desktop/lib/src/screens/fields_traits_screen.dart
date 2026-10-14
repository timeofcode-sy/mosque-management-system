import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import '../widgets/color_field.dart';
import '../widgets/connected_action.dart';
import '../widgets/sync_bar.dart';

/// الواصفاتُ الإضافية والصفاتُ الشخصية — كانتا في لوحة الويب وحدها، خلف `settings.manage`.
///
/// الجدولان يُزامَنان، فالقراءةُ من drift والكتابةُ REST يعود أثرُها في السحب.
class FieldsTraitsScreen extends StatelessWidget {
  const FieldsTraitsScreen({super.key});

  static const entities = {'student': 'الطالب', 'teacher': 'الأستاذ', 'circle': 'الحلقة'};

  static const types = {
    'text': 'نص قصير',
    'textarea': 'نص طويل',
    'number': 'رقم',
    'date': 'تاريخ',
    'select': 'قائمة',
    'multi_select': 'قائمة متعدّدة',
    'bool': 'نعم أو لا',
  };

  static const polarities = {
    'positive': 'صفة إيجابية',
    'neutral': 'صفة محايدة',
    'negative': 'صفة تحتاج متابعة',
  };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الواصفات والصفات'),
          actions: const [PhoneSyncAction()],
          bottom: const TabBar(
            tabs: [Tab(text: 'الواصفات الإضافية'), Tab(text: 'الصفات الشخصية')],
          ),
        ),
        body: const TabBarView(children: [_FieldsTab(), _TraitsTab()]),
      ),
    );
  }
}

// ------------------------------------------------------------------ الواصفات

class _FieldsTab extends StatelessWidget {
  const _FieldsTab();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return _ListBody<CustomFieldDefinition>(
      stream: deps.content.watchCustomFields(),
      emptyMessage: 'لا واصفات إضافية بعد.\nأضف حقلاً يظهر في استمارة الطالب أو الأستاذ أو الحلقة.',
      createLabel: 'واصفة جديدة',
      onCreate: () => _edit(context),
      itemBuilder: (context, field) => ListTile(
        title: Text(field.label),
        subtitle: Text(
          [
            FieldsTraitsScreen.entities[field.entity] ?? field.entity,
            FieldsTraitsScreen.types[field.type] ?? field.type,
            if (field.group != null) field.group!,
            if (field.isRequired) 'مطلوبة',
            if (!field.isActive) 'معطّلة',
          ].join(' · '),
        ),
        trailing: RowActionsMenu(
          actions: [
            RowAction(
              icon: NzIcons.edit,
              label: 'تحرير',
              onPressed: () => _edit(context, field),
            ),
            RowAction(
              icon: NzIcons.trash,
              label: 'حذف',
              destructive: true,
              onPressed: () => _delete(context, field),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [CustomFieldDefinition? field]) async {
    final label = TextEditingController(text: field?.label ?? '');
    final options = TextEditingController(text: field?.options.join('\n') ?? '');
    final group = TextEditingController(text: field?.group ?? '');
    final order = TextEditingController(text: '${field?.sortOrder ?? 0}');
    var entity = field?.entity ?? 'student';
    var type = field?.type ?? 'text';
    var isRequired = field?.isRequired ?? false;
    var isActive = field?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(field == null ? 'واصفة جديدة' : 'تحرير الواصفة'),
          scrollable: true,
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                TextField(
                  controller: label,
                  autofocus: field == null,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: entity,
                  decoration: const InputDecoration(
                    labelText: 'تخصّ',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in FieldsTraitsScreen.entities.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) => setDialogState(() => entity = value ?? entity),
                ),
                DropdownButtonFormField<String>(
                  initialValue: FieldsTraitsScreen.types.containsKey(type) ? type : 'text',
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in FieldsTraitsScreen.types.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? type),
                ),
                if (type == 'select' || type == 'multi_select')
                  TextField(
                    controller: options,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'الخيارات — خيارٌ في كل سطر',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: group,
                        decoration: const InputDecoration(
                          labelText: 'المجموعة (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: order,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الترتيب',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مطلوبة'),
                  value: isRequired,
                  onChanged: (value) => setDialogState(() => isRequired = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مفعّلة'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
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

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () => deps.content.saveCustomField(
        uuid: field?.uuid,
        fieldKey: field?.key,
        entity: entity,
        label: label.text.trim(),
        type: type,
        options: [
          if (type == 'select' || type == 'multi_select')
            for (final line in options.text.split('\n'))
              if (line.trim().isNotEmpty) line.trim(),
        ],
        group: group.text,
        isRequired: isRequired,
        isActive: isActive,
        sortOrder: int.tryParse(order.text.trim()) ?? 0,
      ),
      success: field == null ? 'أُضيفت الواصفة.' : 'حُفظت الواصفة.',
    );
  }

  Future<void> _delete(BuildContext context, CustomFieldDefinition field) async {
    final confirmed = await confirmAction(
      context,
      title: 'حذف الواصفة',
      message: 'ستُحذف «${field.label}» من الاستمارات، وتختفي قيمُها المحفوظة من العرض.',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () => deps.content.deleteCustomField(field.uuid),
      success: 'حُذفت الواصفة.',
    );
  }
}

// ------------------------------------------------------------------ الصفات

class _TraitsTab extends StatelessWidget {
  const _TraitsTab();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return _ListBody<TraitView>(
      stream: deps.content.watchTraits(),
      emptyMessage: 'لا صفات بعد.',
      createLabel: 'صفة جديدة',
      onCreate: () => _edit(context),
      itemBuilder: (context, trait) => ListTile(
        leading: CircleAvatar(
          radius: 8,
          backgroundColor: _color(trait.color) ?? _polarityColor(context, trait.polarity),
        ),
        title: Text(trait.name),
        subtitle: Text(
          [
            FieldsTraitsScreen.polarities[trait.polarity] ?? trait.polarity,
            if (trait.isGlobal) 'عامّة لكل المعاهد',
            if (!trait.isActive) 'معطّلة',
          ].join(' · '),
        ),
        // العامّةُ مزروعةٌ لكل المعاهد، فلا يحرّرها معهدٌ واحد.
        trailing: trait.isGlobal
            ? const NzIcon(NzIcons.lockClosed, size: 18)
            : RowActionsMenu(
                actions: [
                  RowAction(
                    icon: NzIcons.edit,
                    label: 'تحرير',
                    onPressed: () => _edit(context, trait),
                  ),
                  RowAction(
                    icon: NzIcons.trash,
                    label: 'حذف',
                    destructive: true,
                    onPressed: () => _delete(context, trait),
                  ),
                ],
              ),
      ),
    );
  }

  static Color? _color(String? hex) {
    final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);

    return value == null || (hex ?? '').replaceFirst('#', '').length != 6
        ? null
        : Color(0xFF000000 | value);
  }

  static Color _polarityColor(BuildContext context, String polarity) => switch (polarity) {
        'positive' => context.nz.success,
        'negative' => context.nz.warning,
        _ => context.nz.inkMuted,
      };

  Future<void> _edit(BuildContext context, [TraitView? trait]) async {
    final name = TextEditingController(text: trait?.name ?? '');
    final order = TextEditingController(text: '${trait?.sortOrder ?? 0}');
    var polarity = trait?.polarity ?? 'positive';
    var color = trait?.color ?? '';
    var isActive = trait?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(trait == null ? 'صفة جديدة' : 'تحرير الصفة'),
          scrollable: true,
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                TextField(
                  controller: name,
                  autofocus: trait == null,
                  decoration: const InputDecoration(
                    labelText: 'الصفة',
                    border: OutlineInputBorder(),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: polarity,
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in FieldsTraitsScreen.polarities.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (value) => setDialogState(() => polarity = value ?? polarity),
                ),
                ColorField(
                  label: 'اللون (اختياري)',
                  value: color,
                  onChanged: (value) => color = value,
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الترتيب',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مفعّلة'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
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

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () => deps.content.saveTrait(
        uuid: trait?.uuid,
        name: name.text.trim(),
        polarity: polarity,
        color: color.trim().isEmpty ? null : color.trim(),
        sortOrder: int.tryParse(order.text.trim()) ?? 0,
        isActive: isActive,
      ),
      success: trait == null ? 'أُضيفت الصفة.' : 'حُفظت الصفة.',
    );
  }

  Future<void> _delete(BuildContext context, TraitView trait) async {
    final confirmed = await confirmAction(
      context,
      title: 'حذف الصفة',
      message: 'ستُحذف «${trait.name}». والصفةُ المُسندةُ إلى طلابٍ لا تُحذف — عطّلها بدلاً من ذلك.',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () => deps.content.deleteTrait(trait.uuid),
      success: 'حُذفت الصفة.',
    );
  }
}

class _ListBody<T> extends StatelessWidget {
  const _ListBody({
    required this.stream,
    required this.emptyMessage,
    required this.createLabel,
    required this.onCreate,
    required this.itemBuilder,
  });

  final Stream<List<T>> stream;
  final String emptyMessage;
  final String createLabel;
  final VoidCallback onCreate;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreate,
        icon: const NzIcon(NzIcons.plus),
        label: Text(createLabel),
      ),
      body: StreamBuilder<List<T>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snapshot.data!;

          if (rows.isEmpty) {
            return EmptyState(message: emptyMessage, icon: NzIcons.list);
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(context.gutter(), 16, context.gutter(), 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => itemBuilder(context, rows[index]),
          );
        },
      ),
    );
  }
}
