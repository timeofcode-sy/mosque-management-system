import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'curriculum_progress_entry.freezed.dart';
part 'curriculum_progress_entry.g.dart';

/// بندٌ من محفوظات الطالب — نظيرُ `ProgressResource`
/// ([API.md §3.7](../../../../../docs/API.md)).
///
/// المورِدُ الخادميُّ بُني في م.7.1 وكان مؤجَّلاً إلى «ما قبل م.8»: كانت النقطةُ
/// تعيد نموذجاً خاماً بمفاتيحه الداخلية، فلم يكن لهذا الصنف شكلٌ يُبنى عليه.
///
/// و[points] `num` لا `double`: `json_encode(10.0) === '10'` فيصل العددُ الصحيح
/// صحيحاً — وهي قاعدةٌ عامّة في هذا العقد ([API.md §3.4](../../../../../docs/API.md)).
@freezed
abstract class CurriculumProgressEntry with _$CurriculumProgressEntry {
  const factory CurriculumProgressEntry({
    required String uuid,
    required ProgressStatus status,
    required String statusLabel,
    String? itemName,
    String? itemCode,
    int? sortOrder,
    int? percent,
    int? score,
    num? points,
    String? startedOn,
    String? completedOn,
    String? achievedOn,
    String? notes,
  }) = _CurriculumProgressEntry;

  factory CurriculumProgressEntry.fromJson(Map<String, dynamic> json) =>
      _$CurriculumProgressEntryFromJson(json);
}

/// محفوظاتُ ابنٍ مجمَّعةً باسم المنهج — شكلُ `{"data": {"<المنهج>": [ … ]}}`.
///
/// صنفٌ صغير لا `Map` عارية: التجميعُ باسمٍ عربيٍّ مفتاحاً هو **عقدُ النقطة**،
/// وحملُه في نوعٍ يجعل ترتيبَ المناهج وعدَّها في موضعٍ واحد بدل أن يتكرّر في كل
/// شاشة تقرؤه.
class CurriculumProgressReport {
  const CurriculumProgressReport(this.byCurriculum);

  const CurriculumProgressReport.empty()
      : byCurriculum = const <String, List<CurriculumProgressEntry>>{};

  factory CurriculumProgressReport.fromJson(Map<String, dynamic> json) {
    return CurriculumProgressReport({
      for (final entry in json.entries)
        entry.key: [
          for (final row in entry.value as List<dynamic>? ?? const [])
            CurriculumProgressEntry.fromJson((row as Map).cast<String, dynamic>()),
        ],
    });
  }

  final Map<String, List<CurriculumProgressEntry>> byCurriculum;

  bool get isEmpty => byCurriculum.values.every((entries) => entries.isEmpty);

  /// أسماءُ المناهج مرتَّبةً كما وصلت — الخادمُ يجمّع بـ`groupBy` على استعلامٍ
  /// مرتَّب، فترتيبُه ترتيبُ البنود لا ترتيبٌ عشوائي.
  List<String> get curricula => byCurriculum.keys.toList(growable: false);

  Map<String, dynamic> toJson() => {
        for (final entry in byCurriculum.entries)
          entry.key: [for (final row in entry.value) row.toJson()],
      };
}
