import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_user.freezed.dart';
part 'admin_user.g.dart';

/// صفٌّ في `GET /admin/users` — [API.md §3.10](../../../../docs/API.md).
///
/// **ولماذا `id` لا `uuid`؟** لأن `users` جدولٌ **لا يُزامَن** عمداً: حمولتُه بيانات
/// دخول لا تُبثّ في تيّارٍ يقرؤه كل جهاز في المعهد
/// ([SYNC-PROTOCOL.md §2](../../../../docs/SYNC-PROTOCOL.md))، فلا صفَّ منه يعبر
/// `change_log` ليحتاج معرّفاً عالمياً. وهو أيضاً سببُ وجود نقطةِ قراءةٍ لهذا
/// المورد وحده: ما لا يصل في `sync/pull` لا بدّ أن يُقرأ من الشبكة.
///
/// ⚠️ **بلا كلمة مرور:** النسخةُ المقروءة تأتي من [CredentialCard] وحدها، وهي
/// محصورةٌ بالرتبة على الخادم.
@freezed
abstract class AdminUser with _$AdminUser {
  const factory AdminUser({
    required int id,
    required String name,
    String? username,
    String? email,
    String? phone,
    required bool isActive,
    @Default(<UserRoleAssignment>[]) List<UserRoleAssignment> roles,
  }) = _AdminUser;

  factory AdminUser.fromJson(Map<String, dynamic> json) =>
      _$AdminUserFromJson(json);
}

/// إسنادُ دورٍ لمستخدم داخل معهد — أو خارج المعاهد كلها إن كان الدور عابراً.
///
/// المستخدمُ الواحد قد يحمل أكثر من دور في أكثر من معهد، ولذلك قائمةٌ لا حقلٌ
/// واحد: مشرفٌ في معهدٍ ومديرٌ في آخر حالةٌ قائمة لا استثناء.
@freezed
abstract class UserRoleAssignment with _$UserRoleAssignment {
  const factory UserRoleAssignment({
    required String role,
    required String label,
    String? institute,
    required bool isGlobal,
  }) = _UserRoleAssignment;

  factory UserRoleAssignment.fromJson(Map<String, dynamic> json) =>
      _$UserRoleAssignmentFromJson(json);
}

/// صفٌّ في `GET /admin/roles` — كتالوجُ الأدوار **من الخادم لا من نسخةٍ في Dart**.
///
/// بدونه كان على الديسكتوب أن ينسخ `PanelRole` وهرمَه وتسمياتِه العربية، فيفترق
/// السطحان عند أوّل تعديل عليه
/// ([PHASE-6-STAGES.MD §0](../../../../docs/PHASE-6-STAGES.MD) القرار 3).
/// و`rank` الأصغرُ أعلى — وعليه تقوم قاعدة «لا يُسند دورٌ أعلى من دور المُسنِد».
@freezed
abstract class RoleOption with _$RoleOption {
  const factory RoleOption({
    required String name,
    required String label,
    required bool isGlobal,
    required int rank,
  }) = _RoleOption;

  factory RoleOption.fromJson(Map<String, dynamic> json) =>
      _$RoleOptionFromJson(json);
}

/// بياناتُ دخولٍ مولَّدة تُعرض **مرّةً واحدة** بعد إنشاء حسابٍ أو تبديل كلمة مرور.
///
/// لا قناةَ بريد في المشروع، فالتسليمُ طباعةٌ ونسخٌ يدوي — ولهذا كانت هذه الكتابةُ
/// REST مباشراً لا نوعَ عمليةٍ في الطابور: من يُنشئ حساباً ينتظر الكلمةَ ليطبعها،
/// ولا معنى لطابورٍ يحمل سرّاً إلى وقتٍ لاحق
/// ([PHASE-6-STAGES.MD §3.1](../../../../docs/PHASE-6-STAGES.MD)).
@freezed
abstract class IssuedCredentials with _$IssuedCredentials {
  const factory IssuedCredentials({
    String? username,
    required String password,
  }) = _IssuedCredentials;

  factory IssuedCredentials.fromJson(Map<String, dynamic> json) =>
      _$IssuedCredentialsFromJson(json);
}

/// صفٌّ في `GET /admin/credentials` — بطاقةُ دخولٍ جاهزةٌ للطباعة.
///
/// `password` يعود `null` لمن بدّل كلمته بنفسه: النسخةُ المقروءة تُمسح حينها
/// فلا يبقى لأحدٍ اطّلاعٌ على ما اختاره.
@freezed
abstract class CredentialCard with _$CredentialCard {
  const factory CredentialCard({
    required int id,
    required String name,
    required String role,
    String? username,
    String? password,
    required bool isActive,
    String? detail,
  }) = _CredentialCard;

  factory CredentialCard.fromJson(Map<String, dynamic> json) =>
      _$CredentialCardFromJson(json);
}
