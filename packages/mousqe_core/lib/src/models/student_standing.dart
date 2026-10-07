import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_standing.freezed.dart';
part 'student_standing.g.dart';

/// موقعُ الطالب بين زملائه — استجابةُ `GET /student/me/standing` ✅ م.8.1.
///
/// 🔑 **رقمٌ لا كشف.** الرتبةُ تُحسب في الخادم عمداً، فلا يصل جهازَ الطالب صفٌّ
/// عن زميلٍ واحد ([PHASE-8-STAGES.MD §1.1](../../../../../docs/PHASE-8-STAGES.MD)).
/// ولذلك ليس في هذا النموذج قائمةُ زملاء ولا أسماء — وغيابُها **قرارٌ لا نقص**.
@freezed
abstract class StudentStanding with _$StudentStanding {
  const StudentStanding._();

  const factory StudentStanding({
    String? circleName,
    int? rank,
    @Default(0) int peers,
    double? rate,
    @Default(0) num points,
  }) = _StudentStanding;

  factory StudentStanding.fromJson(Map<String, dynamic> json) =>
      _$StudentStandingFromJson(json);

  /// هل قِيس موقعُه أصلاً؟ — `null` تعني «لم يُقَس» لا «الأخير»، وهي قاعدةُ
  /// م.6.6 نفسُها. طالبٌ سُجِّل اليوم أو حلقةٌ لم تُفتح جلستُها لا رتبةَ لهما،
  /// **والعرضُ يقول ذلك ولا يكتب «الأخير»**.
  bool get isRanked => rank != null;
}
