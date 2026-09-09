import '../api/api_client.dart';
import '../models/sync_conflict.dart';

/// التعارضات — رؤيةً وحكماً، ✅ م.6.6 فوق نقطتَي م.6.1.
///
/// وهو **الاستثناءُ الوحيد** في قاعدة «الديسكتوب يقرأ من مخزنه لا من الشبكة»:
/// `sync_conflicts` جدولٌ لا يُزامَن ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md))،
/// فما لا يصل في `sync/pull` لا بدّ أن يُقرأ من الشبكة — نفسُ حجّة
/// [AdminRepository] مع `users`.
///
/// **ولماذا لا طابورَ للحكم؟** لأنه متّصلٌ بطبعه: من يقلب حكماً ينتظر نتيجته،
/// ولا معنى لأن يُصفّ قرارٌ أوف-لاين على تعارضٍ قد يكون حُسم من جهازٍ آخر — وهو
/// نصُّ [PHASE-6-STAGES.MD §3.1](../../../../../docs/PHASE-6-STAGES.MD) على
/// الصنف الثاني.
///
/// **والحراسةُ في الخادم لا هنا:** النقطتان خلف `conflicts.review`، ورفضُ
/// الفعل يعود **422 برسالته العربية** — أشهرُها جلسةٌ مقفلة، فإن `TakeAttendance`
/// ترفضها ولو بـ`amend`.
class ConflictRepository {
  ConflictRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// [status] واحدةٌ من `pending` · `reviewed` · `all` — والافتراضيُّ المعلَّق.
  Future<List<SyncConflict>> load({String status = 'pending'}) async {
    final response = await _api.syncConflicts(status);
    final body = response.data;

    final rows = body is Map ? body['data'] : body;

    return [
      for (final row in rows is List ? rows : const [])
        if (row is Map) SyncConflict.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> resolve({
    required String uuid,
    required ConflictDecision decision,
  }) => _api.resolveSyncConflict(uuid, {'decision': decision.value});
}
