import 'package:freezed_annotation/freezed_annotation.dart';

part 'institute_theme.freezed.dart';
part 'institute_theme.g.dart';

/// الألوان الثلاثة التي يبثّها `/bootstrap` — نظير `App\Support\InstituteTheme::toArray()`.
@freezed
abstract class InstituteTheme with _$InstituteTheme {
  const factory InstituteTheme({
    required String primary,
    required String secondary,
    required String surface,
  }) = _InstituteTheme;

  factory InstituteTheme.fromJson(Map<String, dynamic> json) =>
      _$InstituteThemeFromJson(json);
}
