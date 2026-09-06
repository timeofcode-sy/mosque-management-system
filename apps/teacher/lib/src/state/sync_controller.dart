import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mousqe_core/mousqe_core.dart';

import '../data/teacher_repository.dart';
import 'api_errors.dart';
import 'session_controller.dart';

/// يقود [SyncEngine] من الواجهة: دورةٌ عند الإقلاع، ودورةٌ دورية، وزرُّ «زامن الآن».
///
/// لا منطق مزامنة هنا — العشرة بنود كلّها في المحرّك. ما هنا هو **متى** تُشغَّل
/// الدورة، وكيف تُعرَض نتيجتُها، وماذا يحدث حين يُقفَل الحساب.
class SyncController extends ChangeNotifier {
  SyncController({
    required SyncEngine engine,
    required TeacherRepository repository,
    required SessionController session,
  }) : _engine = engine,
       _repository = repository,
       _session = session;

  /// دورةٌ خلفية هادئة: أقصر منها يستنزف بطارية جهازٍ في حلقة، وأطول منها يجعل
  /// تعديلَ المشرف من اللوحة يتأخّر عن الأستاذ أكثر ممّا يحتمله درسٌ واحد.
  static const Duration _interval = Duration(minutes: 2);

  final SyncEngine _engine;
  final TeacherRepository _repository;
  final SessionController _session;

  Timer? _timer;
  bool _syncing = false;
  String? _error;
  bool _offline = false;

  bool get isSyncing => _syncing;

  /// آخر خطأ **من الخادم** — انقطاعُ الشبكة ليس خطأً، انظر [isOffline].
  String? get error => _error;

  bool get offline => _offline;

  Stream<int> get pendingCount => _engine.watchPendingCount();

  Stream<DateTime?> get lastPulledAt => _engine.watchLastPulledAt();

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
    notifyListeners();

    try {
      await _engine.sync();
      await _repository.clearSettledDrafts();
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
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
