import 'package:freezed_annotation/freezed_annotation.dart';

part 'course.freezed.dart';
part 'course.g.dart';

/// `course` في `GET /bootstrap` — لا Resource مخصّص، شكلٌ ثابتٌ بحقلين فقط.
@freezed
abstract class Course with _$Course {
  const factory Course({
    required String uuid,
    required String name,
  }) = _Course;

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
}
