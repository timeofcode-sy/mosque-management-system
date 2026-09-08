import 'package:flutter/foundation.dart';
import 'package:mousqe_core/mousqe_core.dart';

/// مبدّلُ المعاهد: قائمةُ ما يحقّ لصاحب الحساب، وفعلُ الانتقال إليه.
///
/// يظهر في الواجهة لمن له **أكثر من معهد** وحده ([PHASE-6-STAGES.MD §4] البند 4)
/// — وهم المبرمجُ والمشرفُ الأعلى عملياً، لأن `institutes.manage` منزوعةٌ من
/// `admin` عمداً ([APPS-FEATURES.md §4.3]).
class InstituteSwitcher extends ChangeNotifier {
  InstituteSwitcher({
    required SessionController session,
    required SyncController sync,
  })  : _session = session,
        _sync = sync;

  final SessionController _session;
  final SyncController _sync;

  List<InstituteOption> _options = const [];
  bool _loading = false;

  List<InstituteOption> get options => _options;

  bool get isLoading => _loading;

  /// معهدٌ واحد لا يحتاج مبدّلاً — والقائمةُ الفارغة حالُ جهازٍ بلا شبكة بعد.
  bool get hasChoice => _options.length > 1;

  /// تُستدعى مرّةً حين تجهز الجلسة، لا في كل بناء.
  ///
  /// وفشلُها صامت: هذه قائمةُ راحةٍ لا طريقٌ إلى البيانات، وجهازٌ بلا شبكة يبقى
  /// عاملاً في معهده — ولا يبدّل أصلاً، فالتبديل يمسح المخزن ويحتاج سحباً جديداً.
  Future<void> load() async {
    if (_loading) {
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      _options = await _session.institutes();
    } on Object {
      _options = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _options = const [];
    notifyListeners();
  }

  /// الانتقال إلى معهدٍ آخر — **توقيفُ المزامنة أوّلاً ثم تشغيلُها بعده**.
  ///
  /// لأن التبديل يمسح المخزن ويصفّر المؤشّر: دورةٌ جارية أثناء المسح تكتب صفوفَ
  /// المعهد القديم بعد أن مُحيت، فيخلط الجهازُ معهدين في مخزنٍ واحد.
  ///
  /// يرمي [PendingWorkBlocksSwitch] إن بقي في الطابور ما لم يصل الخادم.
  Future<void> switchTo(String instituteUuid) async {
    _sync.stop();

    try {
      await _session.switchInstitute(instituteUuid);
    } finally {
      _sync.start();
    }

    await load();
  }
}
