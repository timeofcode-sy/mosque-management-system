import 'dart:convert';

import '../api/api_client.dart';
import '../api/api_errors.dart';
import '../db/database.dart';
import '../models/absence_excuse.dart';
import '../models/child_attendance.dart';
import '../models/curriculum_progress_entry.dart';
import '../models/guardian_child.dart';
import '../models/guardian_excuse.dart';

/// ما يقرؤه وليُّ الأمر عن أبنائه — **ومصدرُه REST وحده**.
///
/// ## القرارُ الحاكم: قناةُ القراءة تحدّد المستودع
///
/// وليُّ الأمر خارجَ `sync/pull` كلِّه ([CHECKPOINT-PHASE-7.1.MD §2](../../../../../docs/CHECKPOINT-PHASE-7.1.MD)):
/// التيّارُ يبثّ معهداً كاملاً لكل الأدوار، وذاك على جهاز الأستاذ حِملٌ وعلى
/// جهاز الأب **تسريب** — ولا يحتاجه لأنه لا يكتب في الطابور.
///
/// فما يصل عبر نقطةٍ مخصّصة **لا يسكن جداولَ الدومين**: لا يُستعلَم عليه ولا
/// يُوصَل بغيره، بل يُعرض كما وصل. فمخزنُه `app_state` — نفسُ مخزن لقطة
/// `/bootstrap`، وهو يُمسح في `clearAll()` عند قفل الحساب أو الخروج، فلا تبقى
/// بياناتُ أبناءٍ على جهازٍ خرج صاحبُه منه.
///
/// **ولا `SyncEngine` ولا `SyncController` في تطبيق ولي الأمر**: الطابورُ بنيةٌ
/// لمن يكتب أوف-لاين، وكتابتُه الوحيدة (تقديمُ الإذن) متّصلةٌ بطبعها — من يقدّم
/// إذناً ينتظر جواباً.
///
/// ## وكلُّ قراءةٍ ههنا محاولتان
///
/// الشبكةُ أوّلاً، فإن نجحت كُتبت اللقطةُ وعادت طازجة؛ وإن انقطعت عادت اللقطةُ
/// المحفوظة **ومعها تاريخُها** — فالشاشةُ تقول للأب متى قرأت آخرَ مرّة بدل أن
/// تعرض حضورَ الأسبوع الماضي حاضراً.
class GuardianRepository {
  GuardianRepository({required AppDatabase db, required ApiClient apiClient})
      : _db = db,
        _apiClient = apiClient;

  final AppDatabase _db;
  final ApiClient _apiClient;

  static const String _childrenKey = 'guardian_children';
  static const String _excusesKey = 'guardian_excuses';

  /// مفاتيحُ اللقطات المعلَّقة بابنٍ بعينه — لكلِّ ابنٍ لقطتُه، فتبديلُ الابن
  /// المعروض لا يمحو ما قُرئ عن أخيه.
  static String attendanceKey(String childUuid) => 'guardian_attendance:$childUuid';

  static String progressKey(String childUuid) => 'guardian_progress:$childUuid';

  Future<Snapshot<List<GuardianChild>>> children() {
    return _read(
      key: _childrenKey,
      fetch: () async => (await _apiClient.guardianChildren()).data,
      decode: (json) => [
        for (final row in json['data'] as List<dynamic>? ?? const [])
          GuardianChild.fromJson((row as Map).cast<String, dynamic>()),
      ],
    );
  }

  Future<Snapshot<ChildAttendance>> attendanceOf(String childUuid) {
    return _read(
      key: attendanceKey(childUuid),
      fetch: () async => (await _apiClient.guardianChildAttendance(childUuid)).data,
      decode: ChildAttendance.fromJson,
    );
  }

  Future<Snapshot<CurriculumProgressReport>> progressOf(String childUuid) {
    return _read(
      key: progressKey(childUuid),
      fetch: () async => (await _apiClient.guardianChildProgress(childUuid)).data,
      decode: (json) => CurriculumProgressReport.fromJson(
        (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Future<Snapshot<List<GuardianExcuse>>> excuses() {
    return _read(
      key: _excusesKey,
      fetch: () async => (await _apiClient.guardianExcuses()).data,
      decode: (json) => [
        for (final row in json['data'] as List<dynamic>? ?? const [])
          GuardianExcuse.fromJson((row as Map).cast<String, dynamic>()),
      ],
    );
  }

  /// تقديمُ إذن غياب — **الكتابةُ الوحيدة، وهي متّصلة**.
  ///
  /// لا تُبتلع أخطاؤها ولا تدخل طابوراً: من يقدّم إذناً ينتظر جواباً، وطابورٌ
  /// صامتٌ كان سيعِد وليَّ الأمر بأن الطلبَ وصل وهو لم يغادر الجهاز
  /// ([API.md §3.6](../../../../../docs/API.md)).
  ///
  /// ويُمسح مفتاحُ الأعذار بعدها **لا يُحدَّث**: الاستجابةُ حقلان (المعرّفُ
  /// والحالة) لا صفٌّ كامل، وحقنُها في اللقطة كان يضع فيها صفّاً ناقصاً بلا
  /// اسمِ ابنٍ ولا تاريخ. فالقائمةُ تُقرأ من الخادم في الطلب التالي.
  Future<AbsenceExcuse> submitExcuse({
    required String childUuid,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    final response = await _apiClient.submitGuardianExcuse({
      'student_uuid': childUuid,
      'from_date': fromDate,
      'to_date': toDate,
      'reason': reason,
    });

    await _db.writeAppState(_excusesKey, '');

    return AbsenceExcuse.fromJson((response.data as Map).cast<String, dynamic>());
  }

  /// الشبكةُ أوّلاً، واللقطةُ **عند انقطاعها وحده**.
  ///
  /// الشرطُ [isOffline] لا «أيُّ خطأ»: انقطاعُ الشبكة يعني أن الحالة **مجهولة**
  /// فآخرُ ما عُرف أصدقُ ما يُعرض؛ أمّا خطأٌ ردّه الخادم فحالةٌ **معروفة** —
  /// و403 «الحساب مقفل» و401 يجب أن تصلا `SessionController` فتُخرجا صاحبَ
  /// الجهاز، ولو ابتلعناهما ههنا لَبقي يقرأ لقطةَ أبنائه بحسابٍ أُبطل توكنُه.
  Future<Snapshot<T>> _read<T>({
    required String key,
    required Future<dynamic> Function() fetch,
    required T Function(Map<String, dynamic> json) decode,
  }) async {
    try {
      final body = await fetch();

      await _db.writeAppState(key, _stamp(body));

      return Snapshot(
        decode((body as Map).cast<String, dynamic>()),
        fetchedAt: DateTime.now(),
      );
    } on Object catch (error) {
      if (!isOffline(error)) {
        rethrow;
      }

      // ولا لقطةَ محفوظة ⇒ يُرمى الانقطاعُ نفسُه: «لا اتصال» رسالةٌ صحيحة،
      // وشاشةٌ فارغةٌ بلا سبب ليست كذلك.
      final cached = await _cached(key, decode);

      if (cached == null) {
        rethrow;
      }

      return cached;
    }
  }

  Future<Snapshot<T>?> _cached<T>(
    String key,
    T Function(Map<String, dynamic> json) decode,
  ) async {
    final stored = await _db.readAppState(key);

    if (stored == null || stored.isEmpty) {
      return null;
    }

    final envelope = (jsonDecode(stored) as Map).cast<String, dynamic>();
    final body = (envelope['body'] as Map).cast<String, dynamic>();

    return Snapshot(
      decode(body),
      fetchedAt: DateTime.tryParse(envelope['fetched_at'] as String? ?? ''),
      isStale: true,
    );
  }

  /// اللقطةُ تُختم بوقتها في نفس السطر الذي تُكتب فيه — قيمةٌ واحدة في
  /// `app_state` لا مفتاحان يفترقان إن نجحت كتابةُ أحدهما وفشلت الأخرى.
  String _stamp(dynamic body) => jsonEncode({
        'fetched_at': DateTime.now().toIso8601String(),
        'body': body,
      });
}

/// قراءةٌ ومعها **متى قُرئت وهل هي طازجة** — لا القيمةُ وحدها.
///
/// [isStale] `true` تعني «هذه لقطةٌ محفوظة، والشبكةُ لم تُجب». والشاشةُ ملزمةٌ
/// بأن تقول ذلك: بيانٌ قديم يُعرض بلا إعلانِ قِدَمه يقرؤه صاحبُه حاضراً
/// ([PHASE-7-STAGES.MD §4](../../../../../docs/PHASE-7-STAGES.MD)).
class Snapshot<T> {
  const Snapshot(this.value, {this.fetchedAt, this.isStale = false});

  final T value;
  final DateTime? fetchedAt;
  final bool isStale;
}
