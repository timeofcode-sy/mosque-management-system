import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../di/app_scope.dart';

/// تشغيلُ كتابةٍ **متّصلة** — كلُّ ما يخرج من `CatalogRepository` و
/// `AdminRepository` يمرّ من هنا، ✅ م.6.5.
///
/// وهي ثلاثةُ أشياءَ تتكرّر في كل زرٍّ في هذه الشاشات، فجُمعت في موضعٍ واحد بدل
/// أن تُكتب في خمسةَ عشرَ حواراً:
///
/// 1. **تمييزُ الانقطاع من الرفض.** `isOffline` تفصل «لا شبكة» عن «الخادم رفض»،
///    ورسالتاهما مختلفتان اختلافاً يهمّ صاحب الجهاز: الأولى «أعِد المحاولة حين
///    تعود الشبكة»، والثانية سببٌ عربيٌّ يقوله الفعلُ نفسُه (422). ولولاه لَقرأ
///    المشرفُ «تعذّر الحفظ» في الحالتين ولم يعرف أيَّهما وقع.
/// 2. **مزامنةٌ فورية بعد النجاح.** الكتابةُ REST والقراءةُ من drift، فالصفُّ
///    الجديد لا يظهر حتى تصل دورةُ السحب التالية — دقيقةً كاملة. وبدونها كان
///    المشرفُ يحفظ دورةً فلا يراها، فيحفظها ثانية.
/// 3. **رسالةُ نجاحٍ واحدة** بصياغةٍ واحدة.
///
/// **ولماذا لا يُصفّ هذا في الطابور فيُحلّ الأمرُ كلُّه؟** لأن ما يمرّ هنا
/// صنفان لا يقبلان التأجيل: بنيةٌ يُبنى عليها، وسرٌّ يُنتظر
/// ([PHASE-6-STAGES.MD §3.1](../../../../../docs/PHASE-6-STAGES.MD)).
Future<bool> runConnected(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  final deps = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;

  try {
    await action();
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isOffline(error)
              ? 'هذه الكتابة تحتاج اتصالاً — أعِد المحاولة حين تعود الشبكة.'
              : messageFor(error),
        ),
        backgroundColor: errorColor,
      ),
    );

    return false;
  }

  messenger.showSnackBar(SnackBar(content: Text(success)));

  // الأثرُ يعود في `sync/pull` لا من ردّ الطلب: الديسكتوب لا يصير مصدرَ الحقيقة
  // ([APPS-FEATURES.md §4.3]) — فيُطلَب السحبُ الآن بدل انتظار الدورة.
  await deps.sync.syncNow();

  return true;
}
