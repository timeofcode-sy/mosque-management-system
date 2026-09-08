import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_admin_desktop/src/shell/destinations.dart';

import 'support/snapshots.dart';

List<String> _ids(List<String> permissions) => [
      for (final section in visibleSections(snapshotOf(permissions))) section.id,
    ];

void main() {
  test('the developer opens every door', () {
    expect(_ids(SeededRoles.developer), hasLength(desktopSections.length));
  });

  test('the institute admin opens every door but the institutes one', () {
    final ids = _ids(SeededRoles.admin);

    // `institutes.manage` منزوعةٌ من `admin` عمداً: يدير معهدَه ولا ينشئ معاهد
    // ([APPS-FEATURES.md §4.3]).
    expect(ids, isNot(contains('institutes')));
    expect(ids, containsAll(['users', 'settings', 'credentials', 'catalog']));
  });

  test('the supervisor gets the daily doors, not the institute ones', () {
    final ids = _ids(SeededRoles.supervisor);

    expect(
      ids,
      containsAll([
        'attendance', 'circles', 'students', 'enrollments', 'excuses',
        'credentials', 'conflicts', 'dashboard', 'reports',
      ]),
    );
    // وهذا هو الفرقُ الذي يميّزه من مدير المعهد — صلاحياتٌ لا نسخةُ برنامج.
    expect(ids, isNot(contains('users')));
    expect(ids, isNot(contains('settings')));
    expect(ids, isNot(contains('institutes')));
    expect(ids, isNot(contains('catalog')));
  });

  test('a teacher account signing in here does not become an admin console', () {
    final ids = _ids(SeededRoles.teacher);

    expect(ids, containsAll(['attendance', 'circles', 'students']));
    expect(ids, isNot(contains('credentials')));
    expect(ids, isNot(contains('conflicts')));
    expect(ids, isNot(contains('users')));
  });

  test('a snapshot that never arrived opens nothing, not everything', () {
    // اللقطةُ الغائبة هي حالُ أوّل تشغيلٍ بلا شبكة — والواجهةُ تُخفي ما لا تتيقّن منه.
    expect(visibleSections(null), isEmpty);
  });

  test('one permission of the listed ones is enough to open a door', () {
    // «الطلاب» يفتحها القارئُ والكاتب معاً؛ والفرقُ بينهما داخلَ الشاشة.
    expect(_ids(['students.view']), contains('students'));
    expect(_ids(['students.manage']), contains('students'));
  });

  test('every door is guarded, and every guard is a real seeded permission', () {
    for (final section in desktopSections) {
      expect(
        section.permissions,
        isNotEmpty,
        reason: 'الباب «${section.label}» بلا حارس',
      );
      expect(
        SeededRoles.all,
        containsAll(section.permissions),
        reason: 'الباب «${section.label}» يحرسه اسمٌ ليس في كتالوج الخادم',
      );
    }
  });
}
