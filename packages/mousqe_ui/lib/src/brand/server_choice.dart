import 'package:flutter/material.dart';

/// ما يحتاجه حوارُ اختيار الخادم من التطبيق — بيانٌ ودوالّ لا أكثر.
///
/// الحزمةُ طبقةُ عرضٍ لا تعرف `mousqe_core`، فكلُّ ما يخصّ الشبكة والجلسة يأتيها
/// من التطبيق في هذا الكائن ([LoginForm] يفعل الشيء نفسه بـ`onSubmit`).
class ServerChoice {
  const ServerChoice({
    required this.primaryHost,
    required this.usesPrimary,
    required this.localAddress,
    required this.validateLocal,
    required this.check,
    required this.apply,
    this.warning,
  });

  /// اسمُ النطاق الرئيسي كما يُعرض — `nuzuln.com`.
  final String primaryHost;

  final bool usesPrimary;

  /// آخرُ عنوانٍ محلّيٍّ أُدخل، أو فارغ.
  final String localAddress;

  /// تُظهر فوق الأزرار حين يترتّب على التبديل ما يستحقّ التنبيه — «سيُخرجك من
  /// حسابك». `null` حين لا شيء: جهازٌ لم يدخل بعد.
  final String? warning;

  /// رسالةُ الخطأ إن لم يصلح العنوانُ المحلّي، وإلا `null`.
  final String? Function(String local) validateLocal;

  /// يفحص الاتصالَ بالخيار: `null` ناجحٌ، وإلا نصٌّ يُعرض.
  final Future<String?> Function(bool primary, String local) check;

  /// يطبّق الاختيار. يرمي ما يمنع (طابورٌ لم يصل) فيُعرض نصُّه في الحوار.
  final Future<void> Function(bool primary, String local) apply;
}

/// يفتح حوارَ اختيار الخادم — يُستدعى من [SplashGate.onServerChoice].
Future<void> showServerChoiceDialog(BuildContext context, ServerChoice choice) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ServerChoiceDialog(choice: choice),
  );
}

class _ServerChoiceDialog extends StatefulWidget {
  const _ServerChoiceDialog({required this.choice});

  final ServerChoice choice;

  @override
  State<_ServerChoiceDialog> createState() => _ServerChoiceDialogState();
}

class _ServerChoiceDialogState extends State<_ServerChoiceDialog> {
  late final TextEditingController _local;
  late bool _primary;

  bool _busy = false;
  String? _fieldError;
  String? _error;
  String? _success;

  ServerChoice get _choice => widget.choice;

  @override
  void initState() {
    super.initState();
    _primary = _choice.usesPrimary;
    _local = TextEditingController(text: _choice.localAddress);
  }

  @override
  void dispose() {
    _local.dispose();
    super.dispose();
  }

  /// `true` إن صلح الاختيار للمتابعة — وإلا يضع رسالةَ الحقل.
  bool _validate() {
    if (_primary) {
      return true;
    }

    final message = _choice.validateLocal(_local.text);
    setState(() => _fieldError = message);

    return message == null;
  }

  Future<void> _test() async {
    if (_busy || !_validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    final failure = await _choice.check(_primary, _local.text);

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _error = failure;
      _success = failure == null ? 'الخادم يستجيب ✓' : null;
    });
  }

  Future<void> _save() async {
    if (_busy || !_validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    try {
      await _choice.apply(_primary, _local.text);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('الخادم'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<bool>(
                groupValue: _primary,
                onChanged: (value) {
                  if (_busy || value == null) {
                    return;
                  }

                  setState(() {
                    _primary = value;
                    _fieldError = null;
                    _error = null;
                    _success = null;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      title: const Text('الخادم الرئيسي'),
                      subtitle: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(_choice.primaryHost),
                        ),
                      ),
                    ),
                    const RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      title: Text('خادم محلّي'),
                      subtitle: Text(
                        'حاسوبٌ على الشبكة نفسها، أو يُنشئ نقطةَ اتصالٍ للجوّالات',
                      ),
                    ),
                  ],
                ),
              ),
              if (!_primary) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _local,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    labelText: 'عنوان الحاسوب',
                    hintText: '192.168.1.10:8000',
                    helperText: 'العنوانُ ثم المنفذ — 8000 إن لم تكتبه',
                    errorText: _fieldError,
                  ),
                  onChanged: (_) => setState(() {
                    _fieldError = null;
                    _error = null;
                    _success = null;
                  }),
                  onSubmitted: (_) => _save(),
                ),
              ],
              if (_choice.warning case final warning?) ...[
                const SizedBox(height: 16),
                Text(warning, style: theme.textTheme.bodySmall),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (_success case final success?) ...[
                const SizedBox(height: 12),
                Text(success, style: TextStyle(color: theme.colorScheme.primary)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _test,
          child: const Text('اختبار الاتصال'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
