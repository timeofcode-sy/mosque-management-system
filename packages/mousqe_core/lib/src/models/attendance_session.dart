import 'package:freezed_annotation/freezed_annotation.dart';

import 'attendance.dart';
import 'enums.dart';

part 'attendance_session.freezed.dart';
part 'attendance_session.g.dart';

/// `AttendanceSessionResource` — [API.md §3.5](../../../../docs/API.md).
@freezed
abstract class AttendanceSession with _$AttendanceSession {
  const factory AttendanceSession({
    required String uuid,
    required String courseCircleUuid,
    required String sessionDate,
    required EntityStatus status,
    required bool editable,
    DateTime? completedAt,
    @Default(<Attendance>[]) List<Attendance> attendances,
  }) = _AttendanceSession;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSessionFromJson(json);
}
