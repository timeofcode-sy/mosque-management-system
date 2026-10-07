import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'guardian_child.freezed.dart';
part 'guardian_child.g.dart';

/// ابنٌ في `GET /guardian/children` — [API.md §3.6](../../../../../docs/API.md).
///
/// نظيرُ `StudentResource` الخادمي، وهو **أفقرُ من [Student] عمداً**: ذاك صفُّ
/// drift بعشرين عموداً يستقبل ما يبثّه `sync/pull` للاستمارة، وهذا حمولةُ نقطةٍ
/// من خمسة حقول. ووليُّ الأمر خارجَ التيّار ([CHECKPOINT-PHASE-7.1.MD §2]) فلا
/// يصله الصفُّ الكامل أصلاً.
@freezed
abstract class GuardianChild with _$GuardianChild {
  const factory GuardianChild({
    required String uuid,
    required String fullName,
    String? registrationNo,
    String? photoPath,
    @Default(EntityStatus.active) EntityStatus status,
  }) = _GuardianChild;

  factory GuardianChild.fromJson(Map<String, dynamic> json) =>
      _$GuardianChildFromJson(json);
}
