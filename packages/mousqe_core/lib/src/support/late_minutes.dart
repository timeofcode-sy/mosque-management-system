/// نظير `backend/app/Support/LateMinutes.php` حرفياً — دقائق التأخير محسوبةً من
/// بداية الدوام لا من لحظة فتح الجلسة، فيعرض العميل الرقم فوراً أوف-لاين بنفس
/// الصيغة التي يؤكّدها الخادم لاحقاً. القرار في PHASE-5-STAGES.MD §0 البند 1.
class LateMinutes {
  const LateMinutes._();

  /// الدقائق، أو `null` حين لا مرجع يُقاس عليه.
  ///
  /// ثلاث حالات تعود `null` قصداً:
  /// 1. لا دوام للحلقة (`shiftStartsAt` فارغ) — لا مرجع أصلاً.
  /// 2. `recordedAt` من **يومٍ غير يوم الجلسة**: تفقّدٌ رجعي لتاريخ ماضٍ يُسجَّل
  ///    اليوم، فالفرق أيامٌ لا دقائق.
  /// 3. الطالب وصل قبل بداية الدوام أو معها ⇒ صفر لا سالب (تُرجَع كـ 0 لا null).
  static int? forSession({
    required String? shiftStartsAt,
    required DateTime sessionDate,
    DateTime? recordedAt,
  }) {
    if (shiftStartsAt == null || shiftStartsAt.isEmpty) {
      return null;
    }

    final effectiveRecordedAt = recordedAt ?? DateTime.now();

    if (!_isSameDate(effectiveRecordedAt, sessionDate)) {
      return null;
    }

    final start = _combine(sessionDate, shiftStartsAt);
    final diffMinutes = effectiveRecordedAt.difference(start).inMinutes;

    return diffMinutes < 0 ? 0 : diffMinutes;
  }

  /// الدقائق بعد خصم فترة السماح المضبوطة في إعدادات المعهد.
  static int? afterGrace(int? minutes, int graceMinutes) {
    if (minutes == null) {
      return null;
    }

    final result = minutes - graceMinutes;
    return result < 0 ? 0 : result;
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _combine(DateTime date, String timeOfDay) {
    final parts = timeOfDay.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    final second = parts.length > 2 ? int.parse(parts[2]) : 0;

    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }
}
