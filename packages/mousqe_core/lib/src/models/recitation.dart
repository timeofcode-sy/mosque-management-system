import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'recitation.freezed.dart';
part 'recitation.g.dart';

/// `RecitationResource` — [API.md §6](../../../../docs/API.md). الأسطر والنقاط تُحسب
/// على الخادم وتُجمَّد وقت التسجيل — لا تُعاد حسبتها في العميل.
@freezed
abstract class Recitation with _$Recitation {
  const factory Recitation({
    required String uuid,
    required String studentUuid,
    String? sessionUuid,
    required String date,
    required RecitationType type,
    RecitationGrade? grade,
    int? juz,
    int? fromSurah,
    String? fromSurahName,
    int? fromAyah,
    int? toSurah,
    String? toSurahName,
    int? toAyah,
    required double lines,
    required double newLines,
    required double points,
    String? notes,
  }) = _Recitation;

  factory Recitation.fromJson(Map<String, dynamic> json) =>
      _$RecitationFromJson(json);
}
