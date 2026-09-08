import 'package:flutter/material.dart';

/// استمارةُ الدخول باسم المستخدم — مشتركةٌ بين أسطح موسقي الأربعة.
///
/// بالاسم لا بالبريد ([API.md §3.1](../../../../../docs/API.md)): حساباتُ الأستاذ
/// والطالب مولَّدةٌ من اللوحة وقد لا يكون لصاحبها بريدٌ أصلاً.
///
/// وهي تملك حالتَها — النصّان، و«قيدَ الإرسال»، ورسالةَ الخطأ — ولا تعرف من
/// [onSubmit] إلا أنه ينجح أو يرمي. فيبقى في كل تطبيق سطران: عنوانُه، وما يفعله
/// بالاسم وكلمة المرور.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.icon = Icons.menu_book_outlined,
    this.notice,
    this.errorMessageBuilder,
    this.maxWidth = 420,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// رسالةٌ تُعرض قبل أي محاولة — «هذا الحساب مقفل» مثلاً.
  final String? notice;

  final Future<void> Function(String username, String password) onSubmit;

  /// يحوّل ما يرميه [onSubmit] إلى نصٍّ عربيّ صالحٍ للعرض. وبدونه تُعرض رسالةٌ
  /// عامّة — الحزمةُ لا تعرف أخطاء الشبكة، وهي طبقةُ عرضٍ لا طبقةَ بيانات.
  final String Function(Object failure)? errorMessageBuilder;

  final double maxWidth;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_username.text.trim(), _password.text);
    } on Object catch (failure) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = widget.errorMessageBuilder?.call(failure) ??
            'تعذّر الدخول. تحقّق من البيانات والاتصال.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(widget.icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (widget.notice != null) ...[
                  _Banner(
                    message: widget.notice!,
                    tone: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _username,
                  autocorrect: false,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'أدخل اسم المستخدم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'أدخل كلمة المرور' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Banner(message: _error!, tone: theme.colorScheme.error),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('دخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: tone)),
    );
  }
}
