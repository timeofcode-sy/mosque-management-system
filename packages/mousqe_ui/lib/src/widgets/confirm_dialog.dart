import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// حوارُ تأكيدٍ واحد لكل فعلٍ لا يُتراجَع عنه بلمسة: حذفٌ أو خروج.
///
/// يعيد `true` حين يؤكّد صاحبُ الجهاز وحدها — والإغلاقُ بالضغط خارجه أو بزرّ
/// الرجوع إلغاء.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: dialogContext.nz.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// تأكيدُ الخروج قبل مسح الجلسة: لمسةٌ خاطئةٌ على زرّ الخروج تعني كتابةَ اسم
/// المستخدم وكلمته من جديد — وكثيرٌ من الآباء لا يحفظونها.
Future<bool> confirmSignOut(BuildContext context) => confirmAction(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من هذا الجهاز؟\n'
          'ستحتاج اسمَ المستخدم وكلمةَ المرور للدخول من جديد.',
      confirmLabel: 'خروج',
      destructive: true,
    );
