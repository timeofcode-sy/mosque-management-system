import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'guardian_excuse.freezed.dart';
part 'guardian_excuse.g.dart';

/// إذنُ غيابٍ كما يقرؤه مقدِّمُه في `GET /guardian/excuses` — نظيرُ
/// `AbsenceExcuseResource` ([API.md §3.6](../../../../../docs/API.md)).
///
/// **وهو غيرُ [AbsenceExcuse]**: ذاك استجابةُ `POST` بحقلين (المعرّفُ والحالة)،
/// وهذا صفُّ متابعةٍ كامل. أُبقيا منفصلين لأن الأوّل عقدُ كتابةٍ والثاني عقدُ
/// قراءة، ودمجُهما كان يجعل كلَّ حقلٍ فيه اختيارياً فيضيع ما يضمنه العقد.
///
/// [statusLabel] يأتي من الخادم لا يُترجَم ههنا: ثلاثُ حالاتٍ تُكتب مرّتين
/// تفترقان عند إضافة رابعة، والنصُّ عربيٌّ في الـenum الخادمي أصلاً.
@freezed
abstract class GuardianExcuse with _$GuardianExcuse {
  const GuardianExcuse._();

  const factory GuardianExcuse({
    required String uuid,
    required ExcuseStatus status,
    required String statusLabel,
    required String fromDate,
    required String toDate,
    String? studentUuid,
    String? studentName,
    String? reason,
    String? reviewedAt,
    String? reviewNote,
    String? submittedAt,
  }) = _GuardianExcuse;

  factory GuardianExcuse.fromJson(Map<String, dynamic> json) =>
      _$GuardianExcuseFromJson(json);

  /// هل ما زال ينتظر جوابَ الطاقم؟ — عليه تُبنى نبرةُ البطاقة في الشاشة، فلا
  /// يقرأ وليُّ الأمر تقديمَه قبولاً.
  bool get isPending => status == ExcuseStatus.pending;
}
