import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';

/// جدول الأجزاء نقلٌ حرفي لـ`App\Support\Quran::JUZ_SURAHS`، وعليه تُبنى قائمتا
/// السور في استمارة التسميع. فاختلافُه عن الخادم يعني نموذجين لا واحداً.
void main() {
  group('surahsOfJuz', () {
    test('a juz lists exactly the surahs it passes through', () {
      // الجزء 29: من الملك إلى المرسلات، إحدى عشرة سورة بلا نقص ولا زيادة.
      expect(Quran.surahsOfJuz(29), [67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77]);
    });

    test('a surah split across juzs appears in every juz it touches', () {
      // البقرة تمتدّ على الأجزاء الثلاثة الأولى، فتظهر في كلٍّ منها ولو جزئياً —
      // وإلا اختفت من قائمة الجزء الذي يقع فيه نصفُها.
      expect(Quran.surahsOfJuz(1), contains(2));
      expect(Quran.surahsOfJuz(2), [2]);
      expect(Quran.surahsOfJuz(3), contains(2));
    });

    test('every juz is covered and every surah has one', () {
      final all = <int>{
        for (var juz = 1; juz <= 30; juz++) ...Quran.surahsOfJuz(juz),
      };

      expect(all.length, 114);
      expect(Quran.surahsOfJuz(31), isEmpty);
    });
  });

  group('surahsOfJuzFrom', () {
    test('the end of the range never precedes its start', () {
      expect(Quran.surahsOfJuzFrom(29, 74), [74, 75, 76, 77]);
    });

    test('a surah outside the juz falls back to the whole juz', () {
      expect(Quran.surahsOfJuzFrom(29, 2), Quran.surahsOfJuz(29));
    });
  });

  group('juzOfSurah and juzSpanning', () {
    test('a surah reports the first juz it falls in', () {
      expect(Quran.juzOfSurah(2), 1);
      expect(Quran.juzOfSurah(67), 29);
      expect(Quran.juzOfSurah(114), 30);
    });

    test('a range gets a juz wide enough to hold both ends', () {
      expect(Quran.juzSpanning(67, 68), 29);
      // الملك في 29 والنبأ في 30: لا جزء يسعهما، فيُفتح على جزء البداية.
      expect(Quran.juzSpanning(67, 78), 29);
    });
  });
}
