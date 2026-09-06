import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../db/database.dart';
import 'sync_payload_applier.dart';

/// محرّك المزامنة أوف-لاين — العشرة بنود من
/// [SYNC-PROTOCOL.md §8](../../../../docs/SYNC-PROTOCOL.md) حرفياً.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required ApiClient apiClient,
    required String app,
    required String deviceUuid,
    SyncPayloadApplier? applier,
  })  : _db = db,
        _apiClient = apiClient,
        _app = app,
        _deviceUuid = deviceUuid,
        _applier = applier ?? SyncPayloadApplier(db);

  final AppDatabase _db;
  final ApiClient _apiClient;
  final String _app;
  final String _deviceUuid;
  final SyncPayloadApplier _applier;

  static const _uuid = Uuid();


  /// بند 1 — الطابور: يثبّت `op_uuid` **قبل** أي محاولة إرسال، بلا إرسال فوري.
  ///
  /// الإدراج ضمن معاملة لأن الرقم التسلسلي يُقرأ ثم يُكتب: بلا المعاملة تأخذ
  /// عمليتان متتاليتان نفسَ الرقم، فيضيع الترتيب الذي يعتمد عليه الخادم.
  Future<String> enqueue(String type, Map<String, dynamic> payload) async {
    final opUuid = _uuid.v4();

    await _db.transaction(() async {
      final highest = _db.pendingOperations.sequence.max();
      final row = await (_db.selectOnly(_db.pendingOperations)..addColumns([highest])).getSingle();

      await _db.into(_db.pendingOperations).insert(PendingOperationsCompanion.insert(
            opUuid: opUuid,
            sequence: (row.read(highest) ?? 0) + 1,
            type: type,
            payload: jsonEncode(payload),
            createdAt: DateTime.now(),
          ));
    });

    return opUuid;
  }

  /// بند 2 و5 — الدفع: يرسل كل المعلَّق، ويحذف من الطابور ما ورد في `applied`
  /// أو `skipped` فقط. استثناء الشبكة أثناء الاستجابة **لا يمسح شيئاً** —
  /// الباقي يُعاد إرساله في المحاولة التالية بنفس `op_uuid`.
  Future<void> push() async {
    final pending = await (_db.select(_db.pendingOperations)
          ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
        .get();

    if (pending.isEmpty) {
      return;
    }

    final operations = [
      for (final row in pending)
        {
          'op_uuid': row.opUuid,
          'type': row.type,
          ...jsonDecode(row.payload) as Map<String, dynamic>,
        },
    ];

    final Map<String, dynamic> body;
    try {
      // device_uuid جزءٌ من الحمولة لا من الترويسة: به يميّز ResolveAttendanceConflicts
      // «كتابتي» من «كتابة غيري» (SYNC-PROTOCOL §5)، وبه يُختَم last_pushed_at.
      final response = await _apiClient.syncPush({
        'device_uuid': _deviceUuid,
        'operations': operations,
      });
      body = response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        rethrow;
      }
      // استجابةٌ مفقودة (انقطاع شبكة) — حالة مجهولة لا فشل، فلا حذف بلا تأكيد.
      return;
    }

    final applied = (body['applied'] as List<dynamic>? ?? []).cast<String>();
    final skipped = (body['skipped'] as List<dynamic>? ?? []).cast<String>();
    final confirmed = {...applied, ...skipped};

    if (confirmed.isEmpty) {
      return;
    }

    await (_db.delete(_db.pendingOperations)..where((t) => t.opUuid.isIn(confirmed))).go();
  }

  /// بند 3 و6 — السحب: يكرّر `sync/pull` حتى تعود `changes` فارغة، ويطبّق كل
  /// صفحة بترتيب `server_seq` تصاعدياً **قبل** طلب الصفحة التالية.
  Future<void> pull() async {
    var since = await _lastPulledSeq();

    while (true) {
      final response = await _apiClient.syncPull(since, _app, _deviceUuid);
      final body = response.data as Map<String, dynamic>;
      final changes = (body['changes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      if (changes.isEmpty) {
        break;
      }

      for (final change in changes) {
        await _applier.apply(
          tableName: change['table_name'] as String,
          operation: change['operation'] as String,
          rowUuid: change['row_uuid'] as String,
          payload: change['payload'] as Map<String, dynamic>?,
        );
      }

      since = body['server_seq'] as int? ?? since;
      await _saveLastPulledSeq(since);
    }

    await _stampLastPulledAt();
  }

  /// دورةٌ كاملة: دفعُ ما تراكم ثم سحبُ ما فات — بهذا الترتيب، فما دفعناه يعود
  /// إلينا في نفس السحب مُطبَّقاً كما حسمه الخادم.
  Future<void> sync() async {
    await push();
    await pull();
  }

  /// عددُ العمليات المعلَّقة، متدفّقاً — يغذّي مؤشّر المزامنة في الشاشات.
  Stream<int> watchPendingCount() {
    final total = _db.pendingOperations.opUuid.count();
    final query = _db.selectOnly(_db.pendingOperations)..addColumns([total]);

    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// زمنُ آخر سحبٍ ناجح لهذا الجهاز، متدفّقاً.
  Stream<DateTime?> watchLastPulledAt() {
    return (_db.select(_db.syncState)..where((t) => t.deviceUuid.equals(_deviceUuid)))
        .watchSingleOrNull()
        .map((row) => row?.lastPulledAt);
  }

  /// بند 4 — يُقرأ ويُكتب محلياً فقط، لا اعتماد على مؤشّر الخادم.
  Future<int> _lastPulledSeq() async {
    final row = await (_db.select(_db.syncState)
          ..where((t) => t.deviceUuid.equals(_deviceUuid)))
        .getSingleOrNull();

    return row?.lastPulledSeq ?? 0;
  }

  Future<void> _saveLastPulledSeq(int seq) async {
    await _db.into(_db.syncState).insertOnConflictUpdate(SyncStateCompanion.insert(
          deviceUuid: _deviceUuid,
          lastPulledSeq: Value(seq),
        ));
  }

  /// يُختَم بعد **اكتمال** السحب (الصفحة الفارغة) لا بعد كل صفحة: «آخر سحب ناجح»
  /// وعدٌ بأن الجهاز رأى كل ما عند الخادم، لا بأنه رأى بعضه.
  Future<void> _stampLastPulledAt() async {
    final now = Value(DateTime.now());

    // إدراجٌ لا تحديث: جهازٌ لم يجد شيئاً ليسحبه لم يكتب صفَّ sync_state أصلاً،
    // فالتحديث وحده يترك «آخر سحب» فارغاً إلى الأبد على معهدٍ هادئ.
    await _db.into(_db.syncState).insert(
          SyncStateCompanion.insert(deviceUuid: _deviceUuid, lastPulledAt: now),
          onConflict: DoUpdate((_) => SyncStateCompanion(lastPulledAt: now)),
        );
  }

  /// بند 10 — قفل الحساب: يمسح المخزن المحلي كاملاً ويصفّر `sync_state`.
  Future<void> handleAccountLocked() => _db.clearAll();
}
