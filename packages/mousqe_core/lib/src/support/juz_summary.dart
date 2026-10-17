import '../models/curriculum_progress_entry.dart';
import '../models/enums.dart';

/// الأجزاءُ الثلاثون كما يرسمها شريطُ الأجزاء (`NzJuzProgress`): المحفوظُ منها، والذي يُحفظ الآن.
///
/// بنودُ القرآن في المنهج رموزُها `juz-N` — وما عداها (الأربعون النووية، التحفة…) خارج الشريط.
class JuzSummary {
  const JuzSummary({this.memorized = const {}, this.current});

  /// من محفوظات طالبٍ كما تصل نقاطُ ولي الأمر والطالب: المحفوظُ والمتقَنُ محفوظ، والجاري
  /// الأكثرُ تقدّماً هو الحالي.
  factory JuzSummary.fromEntries(Iterable<CurriculumProgressEntry> entries) {
    final memorized = <int>{};
    int? current;
    var currentPercent = -1;

    for (final entry in entries) {
      final juz = juzOf(entry.itemCode);

      if (juz == null) {
        continue;
      }

      switch (entry.status) {
        case ProgressStatus.memorized || ProgressStatus.mastered:
          memorized.add(juz);
        case ProgressStatus.inProgress when (entry.percent ?? 0) > currentPercent:
          current = juz;
          currentPercent = entry.percent ?? 0;
        default:
          break;
      }
    }

    return JuzSummary(
      memorized: memorized,
      current: memorized.contains(current) ? null : current,
    );
  }

  final Set<int> memorized;
  final int? current;

  bool get isEmpty => memorized.isEmpty && current == null;

  /// رقمُ الجزء من رمز البند (`juz-18` ← 18)، أو `null` لغير الأجزاء.
  static int? juzOf(String? code) {
    if (code == null || !code.startsWith('juz-')) {
      return null;
    }

    final number = int.tryParse(code.substring(4));

    return number != null && number >= 1 && number <= 30 ? number : null;
  }
}
