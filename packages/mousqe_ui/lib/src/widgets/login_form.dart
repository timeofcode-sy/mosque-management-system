import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import '../brand/brand.dart';

/// استمارةُ الدخول باسم المستخدم — مشتركةٌ بين أسطح نزلاً الأربعة، ويعلوها شعارُه.
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
    this.notice,
    this.errorMessageBuilder,
    this.maxWidth = 420,
  });

  final String title;
  final String subtitle;

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
        _error =
            widget.errorMessageBuilder?.call(failure) ??
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
    final c = context.nz;

    // شاشة الدخول في جرد الشاشات: النموذجُ في وسط الصفحة على أرضية night بالنقش، والبطاقةُ raised فتبقى
    // مقروءةً في السمتين، والعلامةُ بنحاسها وبياضها على الليل وحده.
    return Material(
      type: MaterialType.transparency,
      child: NzPattern(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NzSpace.s4),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandGlyph(height: 96)),
                  const SizedBox(height: NzSpace.s5),
                  Container(
                    padding: const EdgeInsets.all(NzSpace.s5),
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(NzRadius.md),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.title,
                            style: NzType.display3.copyWith(color: c.ink),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: NzSpace.s1),
                          Text(
                            widget.subtitle,
                            style: NzType.body.copyWith(color: c.inkMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: NzSpace.s5),
                          if (widget.notice != null) ...[
                            _Banner(message: widget.notice!, error: true),
                            const SizedBox(height: NzSpace.s3),
                          ],
                          TextFormField(
                            controller: _username,
                            autocorrect: false,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: NzIcon(NzIcons.user, size: 20),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'أدخل اسم المستخدم'
                                : null,
                          ),
                          const SizedBox(height: NzSpace.s3),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const NzIcon(
                                NzIcons.lockClosed,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'إظهار كلمة المرور'
                                    : 'إخفاء كلمة المرور',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: NzIcon(
                                  _obscure ? NzIcons.eye : NzIcons.eyeSlash,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'أدخل كلمة المرور'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: NzSpace.s3),
                            _Banner(message: _error!, error: true),
                          ],
                          const SizedBox(height: NzSpace.s5),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: c.onPrimary,
                                    ),
                                  )
                                : const Text('تسجيل الدخول'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: NzSpace.s4),
                  Text(
                    'الحسابات تُنشئها إدارة المعهد — راجع مشرفك إن لم تصلك بيانات دخولك.',
                    style: NzType.caption.copyWith(
                      color: const Color(0xFFA8BBB2),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    // خطأٌ بزوج الهوية: danger على danger-soft، بأيقونة وكلمات تقول ما حدث — لا لونٌ وحده.
    return Container(
      padding: const EdgeInsets.all(NzSpace.s3),
      decoration: BoxDecoration(
        color: error ? c.dangerSoft : c.infoSoft,
        borderRadius: BorderRadius.circular(NzRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NzIcon(
            error ? NzIcons.warning : NzIcons.informationCircle,
            size: 18,
            color: error ? c.danger : c.info,
          ),
          const SizedBox(width: NzSpace.s2),
          Expanded(
            child: Text(
              message,
              style: NzType.body.copyWith(color: error ? c.danger : c.info),
            ),
          ),
        ],
      ),
    );
  }
}
