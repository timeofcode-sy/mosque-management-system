import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'student.freezed.dart';
part 'student.g.dart';

/// `StudentResource` — [API.md §3.6](../../../../docs/API.md).
@freezed
abstract class Student with _$Student {
  const factory Student({
    required String uuid,
    String? registrationNo,
    required String fullName,
    String? photoPath,
    required EntityStatus status,
  }) = _Student;

  factory Student.fromJson(Map<String, dynamic> json) =>
      _$StudentFromJson(json);
}
