import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_errors.dart';
import '../api/api_exception.dart';
import '../db/database.dart';
import '../sync/sync_engine.dart';
import 'session_controller.dart';

/// يقود [SyncEngine] من الواجهة: دورةٌ عند الإقلاع، ودورةٌ دورية، وزرُّ «زامن الآن».
///
/// لا منطق مزامنة هنا — العشرة بنود كلّها في المحرّك. ما هنا هو **متى** تُشغَّل
/// الدورة، وكيف تُعرَض نتيجتُها، وماذا يحدث حين يُقفَل الحساب.
///
/// 🔄 م.6.3 — رُفع من `apps/teacher/` إلى الحزمة حين احتاجه الديسكتوب. وما كان
/// خاصّاً بالأستاذ — تنظيفُ المسودّة بعد استقرار الطابور — صار [onSettled]:
/// خطافاً يمرّره من يملك مسودّةً، ولا يعرف به المحرّك.
class SyncController extends ChangeNotifier {
  SyncController({
    required SyncEngine engine,
    required SessionController session,
    Future<void> Function()? onSettled,
    Duration interval = const Duration(minutes: 2),
  })  : _engine = engine,
        _session = session,
        _onSettled = onSettled,
        _interval = interval;

  final SyncEngine _engine;
  final SessionController _session;
  final Future<void> Function()? _onSettled;

  /// دورةٌ خلفية هادئة: أقصر منها يستنزف بطارية جهازٍ في حلقة، وأطول منها يجعل
  /// تعديلَ المشرف من اللوحة يتأخّر عن الأستاذ أكثر ممّا يحتمله درسٌ واحد.
  final Duration _interval;

  Timer? _timer;
  bool _disposed = false;
  bool _syncing = false;
  String? _error;
  bool _offline = false;

  bool get isSyncing => _syncing;

  /// هل الدورةُ الدورية قائمة؟ — يقرؤها مبدّلُ المعاهد ليتيقّن أنه أعادها بعد
  /// أن أوقفها، سواءٌ تمّ التبديل أو رُفض.
  bool get isRunning => _timer != null;

  /// آخر خطأ **من الخادم** — انقطاعُ الشبكة ليس خطأً، انظر [offline].
  String? get error => _error;

  bool get offline => _offline;

  Stream<int> get pendingCount => _engine.watchPendingCount();

  Stream<DateTime?> get lastPulledAt => _engine.watchLastPulledAt();

  /// العملياتُ التي رفضها الخادم فعُزلت — قرارُها بشريّ لا آليّ.
  Stream<List<PendingOperation>> get failedOperations =>
      _engine.watchFailedOperations();

  Future<void> retryFailed([String? opUuid]) async {
    await _engine.retryFailed(opUuid);
    await syncNow();
  }

  Future<void> discardFailed(String opUuid) => _engine.discardFailed(opUuid);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => syncNow());
    unawaited(syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// دفعٌ ثم سحبٌ ثم تنظيفُ المسودّة — بهذا الترتيب.
  ///
  /// استدعاءٌ ثانٍ أثناء دورةٍ جارية يُتجاهَل: دورتان متوازيتان تدفعان الطابور
  /// مرّتين، وحمايةُ `op_uuid` تجعل ذلك بلا ضرر لكنه بلا فائدة أيضاً.
  Future<void> syncNow() async {
    if (_syncing) {
      return;
    }

    _syncing = true;
    _notify();

    try {
      await _engine.sync();
      await _onSettled?.call();
      _error = null;
      _offline = false;
    } on Object catch (failure) {
      final api = apiExceptionOf(failure);

      if (api is AccountLockedException || api is UnauthenticatedException) {
        stop();
        await _session.handleAccountLocked(api!.message);
        return;
      }

      _offline = isOffline(failure);
      _error = _offline ? null : messageFor(failure);
    } finally {
      _syncing = false;
      _notify();
    }
  }

  /// دورةٌ جارية لحظةَ إغلاق النافذة تُنهي نفسَها بعد أن يُتخلّص من المتحكّم،
  /// و`ChangeNotifier` يرمي إن أُبلغ بعد التخلّص — فالإبلاغُ يُسقَط بلا ضجّة.
  void _notify() {
    if (_disposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
