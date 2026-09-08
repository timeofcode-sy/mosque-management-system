import 'package:freezed_annotation/freezed_annotation.dart';

part 'institute_option.freezed.dart';
part 'institute_option.g.dart';

/// عنصرٌ في `GET /institutes` — مصدرُ مبدّل المعاهد في الديسكتوب
/// ([API.md §4](../../../../../docs/API.md)).
///
/// حمولةٌ أفقرُ من [Institute] عمداً: المبدّلُ يعرض أسماءً ليُختار منها، وثيمُ
/// المعهد وإعداداتُه تصل في `/bootstrap` **بعد** أن يقع الاختيار.
@freezed
abstract class InstituteOption with _$InstituteOption {
  const factory InstituteOption({
    required String uuid,
    required String name,
    String? logoPath,
    @Default(true) bool isActive,
  }) = _InstituteOption;

  factory InstituteOption.fromJson(Map<String, dynamic> json) =>
      _$InstituteOptionFromJson(json);
}
