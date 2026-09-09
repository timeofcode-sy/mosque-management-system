import 'dart:convert';

/// تعارضٌ حسمه الخادم آلياً وينتظر مراجعةً بشرية — حمولةُ `GET /sync/conflicts`،
/// ✅ م.6.6 (والنقطتان قائمتان منذ م.6.1).
///
/// **ولماذا نموذجُ JSON لا صفُّ drift؟** لأن `sync_conflicts` جدولٌ **لا يُزامَن**
/// ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md)): هو أثرُ الدفعة
/// لا بيانُ المعهد، فلا يعبر `change_log` ولا يمكن أن يعبره. وهذه هي **النقطةُ
/// الوحيدة** التي يقرأ فيها الديسكتوب من الخادم لا من مخزنه — نفسُ ما قالته
/// [CHECKPOINT-PHASE-6.1.MD §4](../../../../../docs/CHECKPOINT-PHASE-6.1.MD).
///
/// **وبلا freezed عمداً:** [serverPayload] و[clientPayload] خريطتان **حرّتا
/// الشكل** — حمولةُ صفٍّ من أيّ جدولٍ كان. ونمذجتُهما تعني تعدادَ أعمدةِ كل جدول
/// يمكن أن يتعارض، وهو ما لا يُغلق أبداً.
class SyncConflict {
  const SyncConflict({
    required this.uuid,
    required this.tableName,
    required this.rowUuid,
    required this.serverPayload,
    required this.clientPayload,
    required this.resolution,
    required this.deviceUuid,
    required this.reviewedBy,
    required this.resolvedAt,
    required this.createdAt,
  });

  final String uuid;
  final String tableName;
  final String rowUuid;

  /// القيمتان المتنازعتان **كاملتين** لا ملخّصاً: من يقرّر على نصف الصورة يقرّر
  /// خطأً. وهو قرارُ `SyncConflictResource` نفسُه.
  final Map<String, dynamic> serverPayload;

  final Map<String, dynamic> clientPayload;

  /// ما حكم به الخادم آلياً — `server_wins` غالباً، بشروط
  /// `ResolveAttendanceConflicts` الأربعة.
  final String? resolution;

  final String? deviceUuid;
  final String? reviewedBy;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  /// المعلَّقُ ما لم يُختَم بعد — وهو الافتراضيُّ في شاشة الحكم: شاشةُ عملٍ لا سجلّ.
  bool get isPending => resolvedAt == null;

  /// المفاتيحُ التي **اختلفت** بين القيمتين — وهي كلُّ ما يعني صاحبَ القرار.
  ///
  /// حمولةُ صفِّ تفقّدٍ عشرون مفتاحاً يتطابق تسعةَ عشرَ منها، وعرضُها كلَّها
  /// يدفن الخلافَ الوحيد الذي وقع الحكمُ عليه.
  List<String> get differingKeys {
    final keys = {...serverPayload.keys, ...clientPayload.keys}.toList()..sort();

    return [
      for (final key in keys)
        if (_render(serverPayload[key]) != _render(clientPayload[key])) key,
    ];
  }

  static String _render(dynamic value) => switch (value) {
    null => '—',
    final Map<dynamic, dynamic> map => jsonEncode(map),
    final List<dynamic> list => jsonEncode(list),
    _ => value.toString(),
  };

  /// قيمةٌ مقروءة لمفتاحٍ في إحدى الحمولتين — `—` للغائب، فالغيابُ خبرٌ أيضاً.
  String serverValueOf(String key) => _render(serverPayload[key]);

  String clientValueOf(String key) => _render(clientPayload[key]);

  factory SyncConflict.fromJson(Map<String, dynamic> json) => SyncConflict(
    uuid: json['uuid']?.toString() ?? '',
    tableName: json['table_name']?.toString() ?? '',
    rowUuid: json['row_uuid']?.toString() ?? '',
    serverPayload: _map(json['server_payload']),
    clientPayload: _map(json['client_payload']),
    resolution: json['resolution']?.toString(),
    deviceUuid: json['device_uuid']?.toString(),
    reviewedBy: json['reviewed_by']?.toString(),
    resolvedAt: _date(json['resolved_at']),
    createdAt: _date(json['created_at']),
  );

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

/// الحكمُ في تعارض — قيمتان لا أكثر، وهما نفسُ ما يقبله `POST .../resolve`.
enum ConflictDecision {
  /// «اعتمِد قيمة الجهاز» ⇐ `OverturnSyncConflict` — كتابةٌ فعلية تصل الأجهزةَ
  /// في سحبها التالي.
  clientWins('client_wins', 'اعتمِد قيمة الجهاز'),

  /// «أبقِ قيمة الخادم» ⇐ `ReviewSyncConflict` — ختمٌ بلا كتابة.
  serverWins('server_wins', 'أبقِ قيمة الخادم');

  const ConflictDecision(this.value, this.label);

  final String value;
  final String label;
}
