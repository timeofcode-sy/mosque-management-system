import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';
import '../state/api_errors.dart';

/// الدخول باسم المستخدم لا بالبريد ([API.md §3.1](../../../../../docs/API.md)):
/// حساباتُ الأستاذ مولَّدة من اللوحة وقد لا يكون لصاحبها بريدٌ أصلاً.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      await AppScope.of(context).session
          .signIn(username: _username.text.trim(), password: _password.text);
    } on Object catch (failure) {
      if (!mounted) {
        return;
      }

      setState(() => _error = _readableError(failure));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// `422` عند الدخول تعني «بيانات غير صحيحة» **أو** «حساب مقفل» — الخادم يوحّدهما
  /// قصداً؛ ونصُّه هو ما يُعرض. أمّا رسالةُ الحقل فأدقّ من رسالة الغلاف.
  String _readableError(Object failure) {
    final api = apiExceptionOf(failure);

    if (api is ValidationException) {
      return api.errors.values.expand((messages) => messages).firstOrNull ??
          api.message;
    }

    return messageFor(failure);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = AppScope.of(context).session.notice;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تطبيق الأستاذ',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سجّل الدخول باسم المستخدم الذي زوّدك به المعهد',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (notice != null) ...[
                      _Banner(message: notice, tone: theme.colorScheme.error),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'أدخل اسم المستخدم'
                          : null,
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
