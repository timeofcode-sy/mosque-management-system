import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'course_circle.freezed.dart';
part 'course_circle.g.dart';

/// `CourseCircleResource` — [API.md §3.4](../../../../docs/API.md).
@freezed
abstract class CourseCircle with _$CourseCircle {
  const factory CourseCircle({
    required String uuid,
    String? circleName,
    String? shiftName,
    String? room,
    int? capacity,
    required EntityStatus status,
    int? studentsCount,
  }) = _CourseCircle;

  factory CourseCircle.fromJson(Map<String, dynamic> json) =>
      _$CourseCircleFromJson(json);
}
