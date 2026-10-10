import '../api/api_client.dart';
import '../db/database.dart';
import '../models/announcement.dart';
import 'snapshot_store.dart';

/// إعلاناتُ الأستاذ — ومصدرُها REST وحده، بلقطةٍ محفوظة تُقرأ دون اتصال.
///
/// الأستاذ يعمل على `sync/pull` لما يكتبه (التفقّدُ والتسميع)، أما الإعلاناتُ فتُقرأ ولا تُكتب، وهي **موجَّهةٌ
/// إليه بفئته وبحلقاته**: فالخادمُ يرشّحها (المعهدُ كلُّه، وحلقاتُه التي أُسندت إليه) ولا يصل جهازَه إعلانٌ
/// لحلقةِ زميل. فلا حاجةَ إلى بثّ جدول `announcements` في التيّار ولا إلى متجرٍ محلّيٍّ له.
class TeacherAnnouncementsRepository {
  TeacherAnnouncementsRepository({
    required AppDatabase db,
    required ApiClient apiClient,
  }) : _snapshots = SnapshotStore(db),
       _apiClient = apiClient;

  final SnapshotStore _snapshots;
  final ApiClient _apiClient;

  static const String _key = 'teacher_announcements';

  Future<Snapshot<List<Announcement>>> announcements() {
    return _snapshots.read(
      key: _key,
      fetch: () async => (await _apiClient.teacherAnnouncements()).data,
      decode: (json) => [
        for (final row in json['data'] as List<dynamic>? ?? const [])
          Announcement.fromJson((row as Map).cast<String, dynamic>()),
      ],
    );
  }
}
