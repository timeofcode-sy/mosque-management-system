import 'package:dio/dio.dart';

import 'api_exception.dart';

/// يستخرج [ApiException] المصنَّف من غلاف dio.
///
/// `_AuthInterceptor` يلفّه في `DioException.error` بدل رميه، لأن retrofit يتطلّب
/// أن يمرّ الخطأ عبر سلسلة dio. وما لا يحمل غلافاً هو **انقطاعُ شبكة** لا خطأً من
/// الخادم — والتمييز بينهما هو الفرق بين «أعد المحاولة» و«صحّح ما أرسلت».
ApiException? apiExceptionOf(Object error) {
  if (error is ApiException) {
    return error;
  }

  if (error is DioException && error.error is ApiException) {
    return error.error as ApiException;
  }

  return null;
}

/// `true` لانقطاع شبكة: لا استجابة أصلاً، فالحالة **مجهولة** لا فاشلة
/// ([SYNC-PROTOCOL.md §8](../../../../../docs/SYNC-PROTOCOL.md) البند 5).
bool isOffline(Object error) =>
    error is DioException && apiExceptionOf(error) == null;

/// رسالةٌ عربية صالحةٌ للعرض مباشرةً.
String messageFor(Object error) {
  if (isOffline(error)) {
    return 'لا اتصال بالخادم — سيُعاد الإرسال تلقائياً حين تعود الشبكة.';
  }

  return apiExceptionOf(error)?.message ?? 'حدث خطأ غير متوقّع.';
}

/// أدقُّ رسالةٍ ممكنة لعرضها في استمارة: رسالةُ الحقل إن وُجدت، وإلا رسالةُ
/// الغلاف.
///
/// `422` عند الدخول تعني «بيانات غير صحيحة» **أو** «حساب مقفل» — الخادم يوحّدهما
/// قصداً؛ ونصُّه هو ما يُعرض. أمّا رسالةُ الحقل فأدقّ من رسالة الغلاف.
String fieldMessageFor(Object error) {
  final api = apiExceptionOf(error);

  if (api is ValidationException) {
    return api.errors.values.expand((messages) => messages).firstOrNull ??
        api.message;
  }

  return messageFor(error);
}
