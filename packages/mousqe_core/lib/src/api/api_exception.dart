/// أخطاء الشبكة مصنَّفة حسب [API.md §5](../../../../docs/API.md).
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `401` — بلا توكن أو توكن مُبطَل.
class UnauthenticatedException extends ApiException {
  const UnauthenticatedException([super.message = 'Unauthenticated.']);
}

/// `403` بنص «هذا الحساب مقفل» — يُعالَج في طبقة أعلى بمسح drift كاملاً
/// ([SYNC-PROTOCOL.md §8](../../../../docs/SYNC-PROTOCOL.md) البند 10).
class AccountLockedException extends ApiException {
  const AccountLockedException([super.message = 'هذا الحساب مقفل.']);
}

/// `403` لدورٍ أو صلاحية غير متوفّرة، أو `404` لصفٍّ خارج ملكية المستخدم.
class ForbiddenException extends ApiException {
  const ForbiddenException(super.message);
}

/// `422` فشل تحقّق — تحمل رسائل الحقول كما وصلت من الخادم.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);

  final Map<String, List<String>> errors;
}

/// أي خطأ آخر (500 أو استثناء شبكة) — عام.
class UnknownApiException extends ApiException {
  const UnknownApiException(super.message);
}
