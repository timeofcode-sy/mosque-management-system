import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_settings.freezed.dart';
part 'attendance_settings.g.dart';

/// `institute.attendance` في `/bootstrap` — نظير `App\Support\AttendanceSettings::toArray()`.
@freezed
abstract class AttendanceSettings with _$AttendanceSettings {
  const factory AttendanceSettings({
    @Default(0) int lateGraceMinutes,
  }) = _AttendanceSettings;

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSettingsFromJson(json);
}
