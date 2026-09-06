import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/src/support/late_minutes.dart';

/// أمثلة مطابقة لـ `backend/tests/Feature/Actions/LateMinutesTest.php` — نفس
/// المدخلات، نفس المخرجات.
void main() {
  group('LateMinutes.forSession', () {
    test('computes minutes from the shift start when the student arrives late', () {
      // الدوام يبدأ 08:00 والطالب سُجّل 08:17 ⇒ سبع عشرة دقيقة.
      final minutes = LateMinutes.forSession(
        shiftStartsAt: '08:00:00',
        sessionDate: DateTime(2026, 9, 8),
        recordedAt: DateTime(2026, 9, 8, 8, 17),
      );

      expect(minutes, 17);
    });

    test('arriving before the shift starts is zero not negative', () {
      final minutes = LateMinutes.forSession(
        shiftStartsAt: '08:00:00',
        sessionDate: DateTime(2026, 9, 8),
        recordedAt: DateTime(2026, 9, 8, 7, 40),
      );

      expect(minutes, 0);
    });

    test('a backdated take records no phantom lateness', () {
      // الجلسة ليوم مضى والتسجيل اليوم — الفرق أيامٌ لا دقائق.
      final minutes = LateMinutes.forSession(
        shiftStartsAt: '08:00:00',
        sessionDate: DateTime(2026, 9, 8),
        recordedAt: DateTime(2026, 9, 10, 20, 0),
      );

      expect(minutes, isNull);
    });

    test('a session with no shift behind it yields no reference', () {
      final minutes = LateMinutes.forSession(
        shiftStartsAt: null,
        sessionDate: DateTime(2026, 9, 8),
        recordedAt: DateTime(2026, 9, 8, 9, 0),
      );

      expect(minutes, isNull);
    });
  });

  group('LateMinutes.afterGrace', () {
    test('subtracts the grace period', () {
      expect(LateMinutes.afterGrace(17, 10), 7);
    });

    test('null minutes stay null', () {
      expect(LateMinutes.afterGrace(null, 10), isNull);
    });

    test('never goes negative', () {
      expect(LateMinutes.afterGrace(5, 10), 0);
    });
  });
}
