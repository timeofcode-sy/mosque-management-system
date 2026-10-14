import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/connected_action.dart';
import '../widgets/sync_bar.dart';

/// إدارةُ المعاهد — ✅ م.6.5، خلف `institutes.manage`.
///
/// **وهي منزوعةٌ من `admin` عمداً** ([APPS-FEATURES.md §4.3]): مديرُ المعهد يدير
/// معهدَه لا شبكةَ المعاهد، فهذا البابُ للمبرمج والمشرف الأعلى وحدهما — ولا
/// يظهر لغيرهما أصلاً (ترشيحُ القائمة الجانبية في م.6.3).
///
/// **وإنشاءُ معهدٍ ينشئ معه دورةً أولى مسوّدة** (`CreateInstitute`): معهدٌ بلا
/// دورةٍ لا حلقةَ فيه ولا جلسة، فبدايتُه من الصفر كانت تعني شاشاتٍ فارغة لا
/// يعرف صاحبُها من أين يبدأ.
class InstitutesScreen extends StatefulWidget {
  const InstitutesScreen({super.key});

  @override
  State<InstitutesScreen> createState() => _InstitutesScreenState();
}

class _InstitutesScreenState extends State<InstitutesScreen> {
  Future<List<InstituteOption>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    final deps = AppScope.of(context);

    // بقوسين لا بسهم: الإسنادُ بالسهم يُرجع المستقبلَ نفسَه، و`setState` يرفض
    // دالّةً تُرجع Future.
    setState(() {
      _future = deps.admin.loadInstitutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = AppScope.of(context).session.snapshot?.institute.uuid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعاهد'),
        actions: [
          const PhoneSyncAction(),
          IconButton(
            tooltip: 'تحديث',
            icon: const NzIcon(NzIcons.review),
            onPressed: _reload,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
            child: FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const NzIcon(NzIcons.mosque, size: 18),
              label: const Text('معهد جديد'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<InstituteOption>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              message: isOffline(snapshot.error!)
                  ? 'قائمةُ المعاهد تحتاج اتصالاً.'
                  : messageFor(snapshot.error!),
              icon: NzIcons.offline,
              onRetry: _reload,
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final institutes = snapshot.data!;

          if (institutes.isEmpty) {
            return const EmptyState(
              message: 'لا معاهد بعد.',
              icon: NzIcons.mosque,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: institutes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final institute = institutes[index];

              return ListTile(
                leading: const NzIcon(NzIcons.mosque),
                title: Row(
                  spacing: 8,
                  children: [
                    Flexible(child: Text(institute.name)),
                    if (institute.uuid == active)
                      const Chip(
                        label: Text(
                          'المعهد العامل',
                          style: TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                subtitle: Text(institute.isActive ? 'فعّال' : 'موقوف'),
                trailing: IconButton(
                  icon: const NzIcon(NzIcons.edit, size: 18),
                  onPressed: () => _edit(context, institute),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, [InstituteOption? institute]) async {
    final name = TextEditingController(text: institute?.name ?? '');
    var isActive = institute?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(institute == null ? 'معهد جديد' : 'تحرير المعهد'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم المعهد',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('فعّال'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
                ),
                if (institute == null)
                  Text(
                    'تُنشأ معه دورةٌ أولى مسوّدة، فلا يُفتح على شاشاتٍ فارغة.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                // وباقي بيانات المعهد وألوانُه تُحرَّر من بابه بعد التبديل
                // إليه: نموذجٌ واحد للمعهد لا نموذجان يفترقان.
                if (institute != null)
                  Text(
                    'الألوانُ وبقيةُ البيانات تُحرَّر من باب «بيانات المعهد» '
                    'بعد التبديل إليه.',
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

    final deps = AppScope.of(context);
    final body = {'name': name.text.trim(), 'is_active': isActive};

    final ok = await runConnected(
      context,
      () => institute == null
          ? deps.admin.createInstitute(body)
          : deps.admin.updateInstituteByUuid(institute.uuid, body),
      success: institute == null ? 'أُنشئ المعهد.' : 'حُفظ المعهد.',
    );

    if (ok) {
      _reload();
    }
  }
}
