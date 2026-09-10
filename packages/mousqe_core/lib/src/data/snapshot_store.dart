import 'dart:convert';

import '../api/api_errors.dart';
import '../db/database.dart';

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

  /// اللقطةُ سجلّاً جاهزاً لطبقة العرض — ✅ م.8.2.
  ///
  /// 🔑 **سجلٌّ لا صنف**، لأن `mousqe_ui` لا تعتمد `mousqe_core` عمداً. وسجلّاتُ
  /// Dart بنيويّةُ المطابقة لا اسميّة، فما يعيده هذا يطابق `Loaded<T>` في
  /// `SnapshotView` **بلا أن يستورد أحدُ الطرفين الآخر** — فيُعبَر الحدُّ بلا أن
  /// يُنقَض.
  ({T value, DateTime? fetchedAt, bool isStale}) get ui =>
      (value: value, fetchedAt: fetchedAt, isStale: isStale);
}

/// آلةُ «اقرأ من الشبكة واحفظ لقطةً، وقدّمها حين تنقطع» — ✅ م.8.1.
///
/// 🔁 **رُفعت من `GuardianRepository`** حين احتاجها `StudentRepository`: هي
/// ستّون سطراً كانت ستُنسخ نسخةً ثانية، والتطبيقان يقرآن REST ويخزّنان لقطاتٍ
/// بالمنطق نفسِه. وقاعدةُ المشروع أن ما يحتاجه اثنان يُرفَع لا يُنسَخ
/// ([PLAN.md §7](../../../../../docs/PLAN.md)).
///
/// **وهي في `mousqe_core` لا `mousqe_ui`** لأنها تعرف [AppDatabase] و[ApiClient]
/// — أي أنها طبقةُ بياناتٍ لا عرض، فلا تُقلَب اتجاهاتُ الاعتماد.
///
/// ## قناةُ القراءة تحدّد المستودع
///
/// ما يصل عبر `sync/pull` يسكن جداولَ الدومين المطابقةَ لمخطط الخادم؛ وما يصل
/// عبر نقطةٍ مخصّصة يسكن **مخزنَ لقطاتٍ** بشكل تلك النقطة، لأنه لا يُستعلَم عليه
/// بل يُعرض كما وصل ([CHECKPOINT-PHASE-7.2.MD §2](../../../../../docs/CHECKPOINT-PHASE-7.2.MD)).
///
/// والمخزنُ `app_state` — نفسُ ما تسكنه لقطةُ `/bootstrap`، **ويُمسح في
/// `clearAll()`** عند الخروج أو قفل الحساب.
class SnapshotStore {
  const SnapshotStore(this._db);

  final AppDatabase _db;

  /// الشبكةُ أوّلاً، واللقطةُ **عند انقطاعها وحده**.
  ///
  /// الشرطُ [isOffline] لا «أيُّ خطأ»: انقطاعُ الشبكة يعني أن الحالة **مجهولة**
  /// فآخرُ ما عُرف أصدقُ ما يُعرض؛ أمّا خطأٌ ردّه الخادم فحالةٌ **معروفة** —
  /// و403 «الحساب مقفل» و401 يجب أن تصلا `SessionController` فتُخرجا صاحبَ
  /// الجهاز، ولو ابتلعناهما ههنا لَبقي يقرأ لقطتَه بحسابٍ أُبطل توكنُه.
  Future<Snapshot<T>> read<T>({
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

  /// يُبطل لقطةً بعد كتابةٍ غيّرت ما تحتها.
  ///
  /// **إبطالٌ لا تحديث**: استجابةُ الكتابة ليست صفَّ القراءة عادةً، وحقنُها في
  /// اللقطة يضع فيها صفّاً ناقصاً يبدو كاملاً.
  Future<void> invalidate(String key) => _db.writeAppState(key, '');

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
