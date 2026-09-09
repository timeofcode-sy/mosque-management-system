import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mousqe_core/mousqe_core.dart';

/// بياناتُ الدخول المولَّدة — **تُعرَض مرّةً واحدة**، ✅ م.6.5.
///
/// ولا قناةَ بريدٍ في المشروع، فالتسليمُ طباعةٌ أو نسخٌ يدوي. ولهذا كانت هذه
/// الكتابةُ REST مباشراً لا نوعَ عمليةٍ في الطابور: من يُنشئ حساباً ينتظر
/// الكلمةَ ليطبعها، ولا معنى لطابورٍ يحمل **سرّاً** إلى وقتٍ لاحق
/// ([PHASE-6-STAGES.MD §3.1](../../../../../docs/PHASE-6-STAGES.MD)).
///
/// والحوارُ **لا يُغلق بالضغط خارجه**: إغلاقٌ سهوي هنا يعني كلمةً ضاعت ولا
/// سبيلَ إلى قراءتها ثانيةً — لا من الخادم ولا من هنا.
Future<void> showCredentialsDialog(
  BuildContext context,
  IssuedCredentials credentials,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('بيانات الدخول'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              'تُعرَض هذه الكلمةُ مرّةً واحدة ولا تُقرأ بعد إغلاق هذا الحوار.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            _Field(label: 'اسم الدخول', value: credentials.username ?? '—'),
            _Field(label: 'كلمة المرور', value: credentials.password),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: '${credentials.username ?? ''}\n${credentials.password}',
              ),
            );

            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('نُسخت بيانات الدخول.')),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('نسخ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('نسختُها — أغلِق'),
        ),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
