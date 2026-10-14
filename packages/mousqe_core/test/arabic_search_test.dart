import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';

/// القواعدُ نفسُها في الخادم (tests/Unit/ArabicSearchTest.php): ما يتغيّر هنا يتغيّر هناك.
void main() {
  test('similar letters and marks are folded', () {
    expect(ArabicSearch.normalize('أحمد'), 'احمد');
    expect(ArabicSearch.normalize('أَحْـمَد'), 'احمد');
    expect(ArabicSearch.normalize('عائشة'), 'عايشه');
    expect(ArabicSearch.normalize('مصطفى'), 'مصطفي');
    expect(ArabicSearch.normalize('عبد الرحمن  الزغلول'), 'عبدالرحمن الزغلول');
    expect(ArabicSearch.normalize('٠٩٤٤'), '0944');
  });

  const cases = <String, (String, List<String>, bool)>{
    'hamza forms': ('احمد', ['أحمد', 'محمد', 'الزغلول'], true),
    'two words, any order': ('الزغلول جابر', ['جابر', 'فواز', 'الزغلول'], true),
    'no definite article': ('زغلول', ['جابر', 'فواز', 'الزغلول'], true),
    'start of a word': ('الزغ', ['جابر', 'فواز', 'الزغلول'], true),
    'compound name': ('عبدالرحمن', ['عبد الرحمن', 'فواز', 'الزغلول'], true),
    'part of a phone': ('4994', ['جابر', '0944994123'], true),
    'one letter off is not a match': (
      'الزغلوم',
      ['جابر', 'فواز', 'الزغلول'],
      false,
    ),
    'unrelated': ('يوسف', ['جابر', 'فواز', 'الزغلول'], false),
  };

  for (final MapEntry(key: name, value: (query, fields, expected))
      in cases.entries) {
    test(
      name,
      () => expect(ArabicSearch.match(query, fields).complete, expected),
    );
  }

  test('a miss falls back to the closest names, flagged approximate', () {
    final result = ArabicSearch.rank<String>(
      ['محمد أسامة عبد العال', 'يوسف خالد الطير'],
      'محمود عبدالعال',
      (name) => [name],
    );

    expect(result.items, ['محمد أسامة عبد العال']);
    expect(result.approximate, isTrue);
  });

  test('the closer match ranks first', () {
    final result = ArabicSearch.rank<String>(
      ['محمدنور سامر', 'محمد سامر'],
      'محمد',
      (name) => [name],
    );

    expect(result.items.first, 'محمد سامر');
    expect(result.approximate, isFalse);
  });

  group('student filters', () {
    const orphan = StudentListEntry(
      id: 1,
      uuid: 'a',
      fullName: 'عدنان محمد فتحي يونس',
      status: 'active',
      fatherAlive: false,
      address: 'شارع زملكا مقابل المولدة',
      customFields: {
        'housing': ['أجار'],
      },
      memorizedJuz: 3,
      gradeLevel: 'حادي عشر',
      birthDate: null,
    );
    final other = StudentListEntry(
      id: 2,
      uuid: 'b',
      fullName: 'بلال محمد الزغلول',
      status: 'active',
      circleName: 'الإمام النووي',
      fatherAlive: true,
      address: 'العسقلاني',
      customFields: const {
        'housing': ['ملك'],
      },
      birthDate: DateTime(2011),
    );

    List<String> pick(StudentFilters filters) =>
        [orphan, other].where(filters.accepts).map((s) => s.uuid).toList();

    test('father deceased, housing, address, juz and no circle', () {
      expect(pick(const StudentFilters(father: 'deceased')), ['a']);
      expect(pick(const StudentFilters(fields: {'housing': 'اجار'})), ['a']);
      expect(pick(const StudentFilters(address: 'زملكا')), ['a']);
      expect(pick(const StudentFilters(juzMin: 2)), ['a']);
      expect(pick(const StudentFilters(circle: StudentFilters.noCircle)), [
        'a',
      ]);
      expect(pick(const StudentFilters(circle: 'الإمام النووي')), ['b']);
      expect(pick(const StudentFilters(bornFrom: 2010, bornTo: 2012)), ['b']);
    });

    test('the advanced count leaves status and circle out', () {
      expect(const StudentFilters(status: 'all', circle: 'x').advancedCount, 0);
      expect(
        const StudentFilters(
          father: 'alive',
          juzMin: 2,
          fields: {'f': 'v'},
        ).advancedCount,
        3,
      );
    });
  });
}
