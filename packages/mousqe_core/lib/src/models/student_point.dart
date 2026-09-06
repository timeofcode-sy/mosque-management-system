import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'student_point.freezed.dart';
part 'student_point.g.dart';

/// حقول عملية `points.award` — لا Resource خادمي اليوم، [API.md §6](../../../../docs/API.md).
@freezed
abstract class StudentPoint with _$StudentPoint {
  const factory StudentPoint({
    required String studentUuid,
    required double points,
    required PointsReason reason,
    String? note,
    String? awardedOn,
    String? sessionUuid,
  }) = _StudentPoint;

  factory StudentPoint.fromJson(Map<String, dynamic> json) =>
      _$StudentPointFromJson(json);
}
