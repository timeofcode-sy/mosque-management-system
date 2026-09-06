import 'package:freezed_annotation/freezed_annotation.dart';

import 'attendance_settings.dart';
import 'institute_theme.dart';

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
  }) = _Institute;

  factory Institute.fromJson(Map<String, dynamic> json) =>
      _$InstituteFromJson(json);
}
