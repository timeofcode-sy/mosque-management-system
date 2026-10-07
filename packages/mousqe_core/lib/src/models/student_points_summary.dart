import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_points_summary.freezed.dart';
part 'student_points_summary.g.dart';

/// نقاطُ الطالب بمصادرها — استجابةُ `GET /student/me/points` ✅ م.8.1.
///
/// المصادرُ الخمسة كما بناها نظامُ النقاط في م.4.5: القرآنُ والحديثُ والمتونُ
/// تأتي من صفوفٍ **يجمّدها الخادم**، والحضورُ يُحسب بقيم المعهد، واليدويّة منحُ
/// الأستاذ.
///
/// وكلُّها `num` لا `double`: `json_encode(10.0) === '10'` فيصل العددُ الصحيح
/// صحيحاً ([API.md §3.4](../../../../../docs/API.md)).
@freezed
abstract class StudentPointsSummary with _$StudentPointsSummary {
  const factory StudentPointsSummary({
    @Default(0) num quran,
    @Default(0) num hadith,
    @Default(0) num mutun,
    @Default(0) num attendance,
    @Default(0) num manual,
    @Default(0) num total,
  }) = _StudentPointsSummary;

  factory StudentPointsSummary.fromJson(Map<String, dynamic> json) =>
      _$StudentPointsSummaryFromJson(json);
}
