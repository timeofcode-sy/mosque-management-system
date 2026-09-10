import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';
import 'excuses_screen.dart';

/// تقديمُ إذن غيابٍ مسبق — **الكتابةُ الوحيدة في التطبيق كلِّه**.
///
/// وهي متّصلةٌ بطبعها: من يقدّم إذناً ينتظر جواباً، فلا طابورَ أوف-لاين لها
/// ([API.md §3.6](../../../../docs/API.md)). ولذلك تقول الشاشةُ صراحةً إن
/// الشبكة لازمة، ولا تدّعي نجاحاً لم يقع.
class SubmitExcuseScreen extends StatefulWidget {
  const SubmitExcuseScreen({super.key, required this.child});

  final GuardianChild child;

  @override
  State<SubmitExcuseScreen> createState() => _SubmitExcuseScreenState();
}

class _SubmitExcuseScreenState extends State<SubmitExcuseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  DateTime _from = DateTime.now().add(const Duration(days: 1));
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تقديم إذن غياب')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.child.fullName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _DateField(
              label: 'من تاريخ',
              value: _from,
              onPick: (picked) => setState(() {
                _from = picked;
                // «إلى» لا تسبق «من» أبداً: الخادم يرفضها بـ422، وتصحيحُها ههنا
                // أرخصُ من رحلةٍ إلى الخادم لتقول ما نعرفه.
                if (_to.isBefore(picked)) {
                  _to = picked;
                }
              }),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'إلى تاريخ',
              value: _to,
              firstDate: _from,
              onPick: (picked) => setState(() => _to = picked),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'السبب',
                hintText: 'سفر عائلي · موعد طبي · ظرف عائلي',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'اكتب سبب الغياب.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('إرسال الطلب'),
            ),
            const SizedBox(height: 12),
            Text(
              'يُرسَل الطلبُ إلى المعهد فوراً ويحتاج اتصالاً بالإنترنت، ثم يظهر '
              'في «أذونات الغياب» حتى يراجعه الطاقم. والغيابُ لا يُحتسب مأذوناً '
              'قبل القبول.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AppScope.of(context).repository.submitExcuse(
            childUuid: widget.child.uuid,
            fromDate: _iso(_from),
            toDate: _iso(_to),
            reason: _reason.text.trim(),
          );

      if (!mounted) {
        return;
      }

      // إلى القائمة لا رجوعاً إلى ما قبلها: الطلبُ صار له حالةٌ تُتابَع، وإظهارُها
      // فوراً هو ما يمنع إعادةَ التقديم ظنّاً أن الأوّل لم يصل.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ExcusesScreen()),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      // الخطأُ يُعرض ولا يُبتلع في طابور — ولا يُغلق النموذجُ، فما كُتب باقٍ.
      setState(() {
        _busy = false;
        _error = fieldMessageFor(error);
      });
    }
  }

  static String _iso(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.firstDate,
  });

  final String label;
  final DateTime value;
  final DateTime? firstDate;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? now.subtract(const Duration(days: 7)),
          lastDate: now.add(const Duration(days: 365)),
        );

        if (picked != null) {
          onPick(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormat('EEEE d MMMM yyyy', 'ar').format(value)),
      ),
    );
  }
}
