import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

/// إعلانٌ منشور — استجابةُ `GET /student/me/announcements` ✅ م.8.1.
///
/// **ولا `scopeIds` فيه**: الترشيحُ وقع في الخادم، ومعرّفاتُ الحلقات الأخرى
/// المشمولة ليست من شأن قارئه ([PHASE-8-STAGES.MD §1.3](../../../../../docs/PHASE-8-STAGES.MD)).
@freezed
abstract class Announcement with _$Announcement {
  const Announcement._();

  const factory Announcement({
    required String uuid,
    required String title,
    required String body,
    @Default('all') String scope,
    String? publishedAt,
  }) = _Announcement;

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);

  /// هل وُجِّه إلى حلقته وحدها؟ — تُعرض شارةً، فيقدّر القارئُ خصوصيّتَه.
  bool get isForMyCircle => scope == 'circle';
}
