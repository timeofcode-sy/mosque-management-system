import 'package:freezed_annotation/freezed_annotation.dart';

import 'attendance_settings.dart';
import 'institute_theme.dart';
import 'points_settings.dart';

part 'institute.freezed.dart';
part 'institute.g.dart';

/// `institute` في `GET /bootstrap` — [API.md §3.4](../../../../docs/API.md).
@freezed
abstract class Institute with _$Institute {
  const factory Institute({
    required String uuid,
    required String name,
    String? logoPath,
    required InstituteTheme theme,
    required AttendanceSettings attendance,

    /// 🔄 م.6.6 — ثوابتُ حساب النقاط. **بافتراضيّ** لا `required`: خادمٌ أقدم لا
    /// يبعث الحقل، وتقريرُ النقاط يبقى يُطبع بقيم `PointsSettings::DEFAULTS`
    /// نفسِها بدل أن تسقط اللقطةُ كلُّها ويفقد التطبيقُ ثيمَه معها.
    @Default(PointsSettings()) PointsSettings points,
  }) = _Institute;

  factory Institute.fromJson(Map<String, dynamic> json) =>
      _$InstituteFromJson(json);
}
