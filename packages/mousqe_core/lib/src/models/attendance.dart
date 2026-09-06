import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'attendance.freezed.dart';
part 'attendance.g.dart';

/// `AttendanceResource` — [API.md §3.5](../../../../docs/API.md).
@freezed
abstract class Attendance with _$Attendance {
  const factory Attendance({
    required String uuid,
    required String studentUuid,
    String? studentName,
    required AttendanceStatus status,
    int? lateMinutes,
    String? note,
    required DateTime recordedAt,
  }) = _Attendance;

  factory Attendance.fromJson(Map<String, dynamic> json) =>
      _$AttendanceFromJson(json);
}
