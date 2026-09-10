import '../api/api_client.dart';
import '../db/database.dart';
import '../models/announcement.dart';
import '../models/child_attendance.dart';
import '../models/curriculum_progress_entry.dart';
import '../models/student_points_summary.dart';
import '../models/student_standing.dart';
import 'snapshot_store.dart';

/// ما يقرؤه الطالبُ **عن نفسه** — ومصدرُه REST وحده ✅ م.8.1.
///
/// ⚠️ **الاسمُ `StudentSelfRepository` لا `StudentRepository`**: الثاني مأخوذٌ
/// منذ م.6.5 لمستودعٍ آخرَ تماماً — إدارةُ الطلاب في الديسكتوب، يكتب في الطابور
/// ويقرأ من drift. والاسمان يتشابهان والوظيفتان لا تلتقيان، فالتمييزُ في الاسم
/// أرخصُ من اكتشافه في مراجعة. **ونظيرُه الخادميُّ `StudentSelfController`**
/// فالتسميةُ متّسقةٌ عبر السطحين.
///
/// ## الطالبُ خارجَ `sync/pull` كوليّ الأمر — وحجّتُه أقوى
///
/// وليُّ الأمر يقرأ عن أبنائه وهم أكثرُ من واحد، **والطالبُ يقرأ عن نفسه
/// وحدها**. فبثُّ معهدٍ كامل إلى هاتفه أوسعُ تسريباً وأقلُّ مبرِّراً
/// ([PHASE-8-STAGES.MD §1.1](../../../../../docs/PHASE-8-STAGES.MD)).
///
/// **وما كان يمنع** أن ميزةً واحدة تحتاج بيانَ غيره: ترتيبُه في الحلقة. فقُلب
/// الاتجاه — الخادمُ يحسب الرتبة ويعيد الرقمَ وحده، ولا يصل الجهازَ صفٌّ عن
/// زميل.
///
/// ## ولا كتابةَ إطلاقاً
///
/// أفقرُ المستودعات صلاحيةً: قراءةٌ صرف. لا `SyncEngine` ولا طابور ولا حتى
/// كتابةٌ متّصلة كتقديم إذن ولي الأمر — والطالبُ لا يملك `sync.push` في كتالوج
/// الأدوار أصلاً.
class StudentSelfRepository {
  StudentSelfRepository({required AppDatabase db, required ApiClient apiClient})
      : _snapshots = SnapshotStore(db),
        _apiClient = apiClient;

  final SnapshotStore _snapshots;
  final ApiClient _apiClient;

  static const String _attendanceKey = 'student_attendance';
  static const String _progressKey = 'student_progress';
  static const String _standingKey = 'student_standing';
  static const String _pointsKey = 'student_points';
  static const String _announcementsKey = 'student_announcements';

  /// حضورُه: الملخّصُ والمنحنى والسجلّ — نفسُ شكل نقطة ولي الأمر (م.7.1).
  Future<Snapshot<ChildAttendance>> attendance() {
    return _snapshots.read(
      key: _attendanceKey,
      fetch: () async => (await _apiClient.studentAttendance()).data,
      decode: ChildAttendance.fromJson,
    );
  }

  /// محفوظاتُه مجمَّعةً باسم المنهج.
  Future<Snapshot<CurriculumProgressReport>> progress() {
    return _snapshots.read(
      key: _progressKey,
      fetch: () async => (await _apiClient.studentProgress()).data,
      // خريطةٌ فارغة تخرج من PHP مصفوفةً `[]` لا كائناً — أُصلح العقدُ في م.7.4
      // ويبقى القارئُ متسامحاً، فعميلٌ يتحدّث خادماً أقدم لا يسقط.
      decode: (json) => CurriculumProgressReport.fromJson(
        json['data'] is Map
            ? (json['data'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{},
      ),
    );
  }

  /// موقعُه بين زملائه — **رقمٌ لا كشف**.
  Future<Snapshot<StudentStanding>> standing() {
    return _snapshots.read(
      key: _standingKey,
      fetch: () async => (await _apiClient.studentStanding()).data,
      decode: (json) => StudentStanding.fromJson(
        (json['data'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  Future<Snapshot<StudentPointsSummary>> points() {
    return _snapshots.read(
      key: _pointsKey,
      fetch: () async => (await _apiClient.studentPoints()).data,
      decode: (json) => StudentPointsSummary.fromJson(
        (json['data'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  /// إعلاناتُ معهده وحلقته — **والترشيحُ وقع في الخادم**.
  Future<Snapshot<List<Announcement>>> announcements() {
    return _snapshots.read(
      key: _announcementsKey,
      fetch: () async => (await _apiClient.studentAnnouncements()).data,
      decode: (json) => [
        for (final row in json['data'] as List<dynamic>? ?? const [])
          Announcement.fromJson((row as Map).cast<String, dynamic>()),
      ],
    );
  }
}
