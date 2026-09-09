import '../api/api_client.dart';
import '../models/admin_user.dart';
import '../models/institute_option.dart';

/// سطحُ الإدارة المتّصل: المستخدمون والأدوارُ وبياناتُ الدخول وبياناتُ المعهد
/// وإدارةُ المعاهد — ✅ م.6.5، فوق النقاطِ التسعَ عشرةَ التي بُنيت في م.6.2.
///
/// **وهو الوحيدُ في التطبيق الذي لا يعمل أوف-لاين**، وذلك حكمٌ لا نقص:
///
/// - **الحساباتُ والأدوارُ وكلماتُ المرور متّصلةٌ بطبعها** — من يُنشئ حساباً
///   ينتظر كلمةَ المرور ليطبعها، ولا معنى لطابورٍ يحمل **سرّاً** إلى وقتٍ لاحق
///   ([PHASE-6-STAGES.MD §3.1](../../../../../docs/PHASE-6-STAGES.MD)).
/// - **و`users` جدولٌ لا يُزامَن عمداً** — حمولتُه بيانات دخول لا تُبثّ في تيّارٍ
///   يقرؤه كل جهاز في المعهد ([SYNC-PROTOCOL.md §2](../../../../../docs/SYNC-PROTOCOL.md)).
///   فما لا يصل في `sync/pull` لا بدّ أن يُقرأ من الشبكة، ولا مخزنَ له.
///
/// **والحراسةُ في الأفعال لا هنا:** `assertAssignable` و`outranks` تُطبَّقان على
/// السطحين معاً، فلا يُسند أحدٌ دوراً أعلى من دوره ولا يبدّل مشرفٌ كلمةَ نظيره —
/// سواءٌ فتح اللوحةَ أو الديسكتوب. ورفضُ الفعل يعود **422 برسالته العربية** لا
/// 403 صامتة.
class AdminRepository {
  AdminRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ------------------------------------------------- المستخدمون والأدوار

  /// كتالوجُ الأدوار **من الخادم لا من نسخةٍ في Dart** — بدونه كان على الديسكتوب
  /// أن ينسخ `PanelRole` وهرمَه وتسمياتِه، فيفترق السطحان عند أوّل تعديل.
  Future<List<RoleOption>> loadRoles() async {
    final response = await _api.adminRoles();

    return _list(response.data).map(RoleOption.fromJson).toList();
  }

  Future<List<AdminUser>> loadUsers({String? search, String? role, String? scope}) async {
    final response = await _api.adminUsers(search, role, scope);

    return _list(response.data).map(AdminUser.fromJson).toList();
  }

  /// إنشاءُ حسابٍ جديد — ويعود بكلمة المرور المولَّدة **مرّةً واحدة**.
  Future<IssuedCredentials> inviteUser({
    required String firstName,
    required String lastName,
    required String role,
    String? email,
    String? phone,
  }) async {
    final response = await _api.inviteUser({
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });

    final body = response.data;

    return IssuedCredentials.fromJson(
      Map<String, dynamic>.from(
        (body is Map ? body['credentials'] : null) as Map? ?? const {},
      ),
    );
  }

  Future<void> assignRole({required int userId, required String role}) =>
      _api.assignUserRole(userId, {'role': role});

  Future<void> revokeRole({required int userId, required String role}) =>
      _api.revokeUserRole(userId, {'role': role});

  /// توليدُ كلمةِ مرورٍ جديدة — تعود مرّةً واحدة كما في [inviteUser].
  Future<IssuedCredentials> resetPassword(int userId) async {
    final response = await _api.resetUserPassword(userId, const {});

    final body = response.data;

    return IssuedCredentials.fromJson(
      Map<String, dynamic>.from(
        (body is Map ? body['credentials'] : null) as Map? ?? const {},
      ),
    );
  }

  /// إقفالُ حسابٍ أو فتحُه — والمقفلُ يُمسح مخزنُه عند أوّل طلبٍ يرفضه الخادم
  /// ([SYNC-PROTOCOL.md §8] البند 10).
  Future<void> setActivation({required int userId, required bool active}) =>
      _api.setUserActivation(userId, {'is_active': active});

  /// بطاقاتُ الدخول للطباعة — و`password` يعود `null` لمن بدّل كلمته بنفسه.
  Future<List<CredentialCard>> loadCredentials({String? role, String? search}) async {
    final response = await _api.adminCredentials(role, search);

    return _list(response.data).map(CredentialCard.fromJson).toList();
  }

  // ------------------------------------------------------------- المعهد

  /// حفظُ بيانات المعهد أو ألوانِه — **والحمولةُ الجزئية لا تمسح ما قبلها**.
  ///
  /// قواعدُ `InstituteForm` تطلب الألوانَ والتفقّدَ والنقاطَ كاملةً لأن اللوحة
  /// ترسل النموذج كلَّه في كل حفظ؛ والديسكتوبُ يبعث بابَ الألوان وحده. فبدل
  /// **تليين القاعدة** — وهو ما يجعل نموذجين للمعهد يفترقان — تُكمَّل الحمولةُ
  /// على الخادم من الحالة المخزَّنة قبل التحقّق
  /// ([CHECKPOINT-PHASE-6.2.MD §3.4](../../../../../docs/CHECKPOINT-PHASE-6.2.MD)).
  Future<void> updateInstitute(Map<String, dynamic> body) =>
      _api.updateInstitute(body);

  /// إنشاءُ معهد — لحاملِ `institutes.manage` وحده، وهي **منزوعةٌ من `admin`**
  /// عمداً: مديرُ المعهد يدير معهدَه لا شبكةَ المعاهد.
  Future<void> createInstitute(Map<String, dynamic> body) =>
      _api.createInstitute(body);

  Future<void> updateInstituteByUuid(String uuid, Map<String, dynamic> body) =>
      _api.updateInstituteByUuid(uuid, body);

  /// المعاهدُ التي يعمل فيها صاحبُ الحساب — نفسُ نقطةِ مبدّل المعاهد (م.6.1).
  Future<List<InstituteOption>> loadInstitutes() async {
    final response = await _api.institutes();

    return _list(response.data).map(InstituteOption.fromJson).toList();
  }

  /// `{"data": [...]}` — والغلافُ ثابتٌ في كل نقاط `/admin`.
  static List<Map<String, dynamic>> _list(dynamic body) {
    final data = body is Map ? body['data'] : null;

    if (data is! List) {
      return const [];
    }

    return [
      for (final row in data)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }
}
