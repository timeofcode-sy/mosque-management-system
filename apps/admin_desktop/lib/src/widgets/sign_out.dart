import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// الخروجُ بعد تأكيد — من شريط المكتب الجانبي، و«المزيد» على الهاتف، وشاشة «لا أبواب».
///
/// الخروجُ يمسح مخزنَ الجهاز، فما لم يُزامَن يضيع: لمسةٌ خاطئة هنا ليست إعادةَ دخولٍ فقط.
Future<void> confirmAndSignOut(BuildContext context) async {
  final session = AppScope.of(context).session;

  final confirmed = await confirmAction(
    context,
    title: 'تسجيل الخروج',
    message: 'يُمسح مخزنُ هذا الجهاز عند الخروج، فما لم يُزامَن من كتاباتك يضيع. '
        'تأكّد أن زرَّ المزامنة أعلى الشاشة لا يعرض عملياتٍ معلّقة.',
    confirmLabel: 'خروج',
    destructive: true,
  );

  if (confirmed) {
    await session.signOut();
  }
}
