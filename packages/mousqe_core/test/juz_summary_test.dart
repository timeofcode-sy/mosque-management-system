import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';

CurriculumProgressEntry _entry(String? code, ProgressStatus status, {int? percent}) =>
    CurriculumProgressEntry(
      uuid: '$code-$status',
      status: status,
      statusLabel: '',
      itemCode: code,
      percent: percent,
    );

void main() {
  test('memorised and mastered juz fill the bar, the most advanced in-progress one is current', () {
    final summary = JuzSummary.fromEntries([
      _entry('juz-30', ProgressStatus.memorized),
      _entry('juz-29', ProgressStatus.mastered),
      _entry('juz-28', ProgressStatus.inProgress, percent: 20),
      _entry('juz-27', ProgressStatus.inProgress, percent: 60),
      _entry('juz-26', ProgressStatus.notStarted),
      _entry('nawawi-40', ProgressStatus.memorized),
      _entry(null, ProgressStatus.memorized),
    ]);

    expect(summary.memorized, {30, 29});
    expect(summary.current, 27);
    expect(summary.isEmpty, isFalse);
  });

  test('only juz codes from 1 to 30 count', () {
    expect(JuzSummary.juzOf('juz-1'), 1);
    expect(JuzSummary.juzOf('juz-30'), 30);
    expect(JuzSummary.juzOf('juz-31'), isNull);
    expect(JuzSummary.juzOf('juz-x'), isNull);
    expect(JuzSummary.juzOf('tuhfa'), isNull);
    expect(JuzSummary.fromEntries(const []).isEmpty, isTrue);
  });
}
