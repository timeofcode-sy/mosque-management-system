import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'absence_excuse.freezed.dart';
part 'absence_excuse.g.dart';

/// استجابة `POST /guardian/excuses` — [API.md §3.6](../../../../docs/API.md).
@freezed
abstract class AbsenceExcuse with _$AbsenceExcuse {
  const factory AbsenceExcuse({
    required String uuid,
    required ExcuseStatus status,
  }) = _AbsenceExcuse;

  factory AbsenceExcuse.fromJson(Map<String, dynamic> json) =>
      _$AbsenceExcuseFromJson(json);
}
