import 'package:flutter/material.dart';
import '../di/app_scope.dart';
import '../widgets/color_field.dart';
import '../widgets/connected_action.dart';
import '../widgets/form_section.dart';

/// بياناتُ المعهد وألوانُه الثلاثة — ✅ م.6.5، فوق `PUT /admin/institute`.
///
/// **والقيمُ تُقرأ من اللقطة لا من الشبكة**: `institutes` جدولٌ يُزامَن، ولقطةُ
/// `/bootstrap` تحمل المعهدَ وثيمَه أصلاً — ولذلك لا `GET` في
/// `InstituteAdminController`. وما ينقص هو الكتابةُ وحدها.
///
/// **والحمولةُ الجزئية لا تمسح ما قبلها**: قواعدُ `InstituteForm` تطلب الألوانَ
/// والتفقّدَ والنقاطَ كاملةً لأن اللوحة ترسل النموذج كلَّه، وهذه الشاشةُ ترسل
/// بابين. فبدل تليين القاعدة تُكمَّل الحمولةُ على الخادم من الحالة المخزَّنة قبل
/// التحقّق ([CHECKPOINT-PHASE-6.2.MD §3.4](../../../../../docs/CHECKPOINT-PHASE-6.2.MD)).
///
/// ⚠️ **والشعارُ خارج هذه الشاشة**: رفعُ ملفٍّ عقدٌ آخر (`multipart`) لم يُفتح
/// بعد — [API.md §8]، وهو أثرٌ باقٍ من م.6.2.
class InstituteSettingsScreen extends StatefulWidget {
  const InstituteSettingsScreen({super.key});

  @override
  State<InstituteSettingsScreen> createState() =>
      _InstituteSettingsScreenState();
}

class _InstituteSettingsScreenState extends State<InstituteSettingsScreen> {
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();

  late String _primary;
  late String _secondary;
  late String _surface;
  late int _grace;

  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fill());
  }

  @override
  void dispose() {
    for (final controller in [_name, _shortName, _phone, _email, _address]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill() {
    final snapshot = AppScope.of(context).session.snapshot;
    final institute = snapshot?.institute;

    _name.text = institute?.name ?? '';
    _primary = institute?.theme.primary ?? '#0F5132';
    _secondary = institute?.theme.secondary ?? '#C9A227';
    _surface = institute?.theme.surface ?? '#F7F3EA';
    _grace = snapshot?.lateGraceMinutes ?? 0;

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات المعهد'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('حفظ'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FormSection(
            title: 'البيانات الأساسية',
            children: [
              _field(_name, 'اسم المعهد', width: 380),
              _field(_shortName, 'الاسم المختصر'),
              _field(_phone, 'الهاتف'),
              _field(_email, 'البريد الإلكتروني'),
              _field(_address, 'العنوان', width: 640),
            ],
          ),
          // والثلاثةُ **مصدرٌ واحد للأسطح الخمسة**: اللوحةُ والتقاريرُ المطبوعة
          // والتطبيقاتُ الأربعة تشتقّ سلالمَها منها بنفس النسب، فالتطابقُ مضمونٌ
          // مهما اختار المعهد ([PLAN.md §8]).
          FormSection(
            title: 'ألوان المعهد الثلاثة',
            children: [
              ColorField(
                label: 'اللون الأساسي',
                value: _primary,
                onChanged: (value) => setState(() => _primary = value),
              ),
              ColorField(
                label: 'اللون الثانوي',
                value: _secondary,
                onChanged: (value) => setState(() => _secondary = value),
              ),
              ColorField(
                label: 'لون السطح',
                value: _surface,
                onChanged: (value) => setState(() => _surface = value),
              ),
            ],
          ),
          FormSection(
            title: 'التفقّد',
            children: [
              SizedBox(
                width: 300,
                child: TextFormField(
                  initialValue: _grace.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'مهلة التأخير بالدقائق',
                    helperText: 'بعدها يُحسب الحاضرُ متأخّراً',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _grace = int.tryParse(value) ?? _grace,
                ),
              ),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('شعار المعهد'),
              subtitle: const Text(
                'يُرفع من لوحة التحكّم — رفعُ الملفات عقدٌ لم يُفتح في الـAPI بعد.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 300,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final deps = AppScope.of(context);

    await runConnected(
      context,
      () async {
        await deps.admin.updateInstitute({
          'name': _name.text.trim(),
          'short_name': _text(_shortName),
          'phone': _text(_phone),
          'email': _text(_email),
          'address': _text(_address),
          'theme': {
            'primary': _primary,
            'secondary': _secondary,
            'surface': _surface,
          },
          'attendance': {'late_grace_minutes': _grace},
        });

        // اللقطةُ تُعاد قراءتُها فيتبدّل ثيمُ النافذة في مكانه — وإلا بقي
        // المستخدمُ يرى ألوانَه القديمة حتى يخرج ويعود.
        await deps.session.refreshSnapshot();
      },
      success: 'حُفظت بيانات المعهد.',
    );

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  static String? _text(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();
}
