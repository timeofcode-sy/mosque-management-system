import '../models/enums.dart';

/// أرقامُ الداشبورد والتقارير كما يبنيها [StatsRepository] من الصفوف المتزامنة
/// — ✅ م.6.6.
///
/// وكلُّها **مشتقّة**: `circle_daily_stats` و`circle_cumulative_stats` جدولان
/// خادميّان لا يُزامَنان ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md))،
/// لأن نقلَ ما يمكن حسابُه نقلٌ زائد. فما هنا نظيرُهما محسوباً على الجهاز من
/// `attendances` — يُقرأ والشبكةُ مقطوعة.

/// عدّاداتُ رأس الداشبورد.
class InstituteCounters {
  const InstituteCounters({
    required this.students,
    required this.teachers,
    required this.circles,
    required this.enrolled,
  });

  /// طلابُ المعهد كلُّهم — والمسجَّلون في الدورة الجارية [enrolled] وحدهم.
  final int students;
  final int teachers;
  final int circles;
  final int enrolled;
}

/// حصّةُ كل حالةٍ من صفوف الحضور في مدّةٍ ما.
class StatusBreakdown {
  const StatusBreakdown({
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.excused = 0,
  });

  final int present;
  final int absent;
  final int late;
  final int excused;

  int get total => present + absent + late + excused;

  int countOf(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => present,
        AttendanceStatus.absent => absent,
        AttendanceStatus.late => late,
        AttendanceStatus.excused => excused,
      };

  StatusBreakdown plus(StatusBreakdown other) => StatusBreakdown(
        present: present + other.present,
        absent: absent + other.absent,
        late: late + other.late,
        excused: excused + other.excused,
      );
}

/// نقطةٌ في منحنى الأيام — و[sessions] عددُ الجلسات التي قِيست فيها.
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.rate,
    required this.sessions,
  });

  final DateTime date;

  /// `null` ليومٍ **لا جلسةَ فيه** — وهو غيرُ `0` الذي يعني «قِيس فكان صفراً».
  final double? rate;

  final int sessions;
}

/// حلقةٌ في كشف الترتيب — يوماً واحداً أو تراكمياً عبر الدورة.
class CircleStanding {
  const CircleStanding({
    required this.courseCircleId,
    required this.circleName,
    required this.shiftName,
    required this.teachersLabel,
    required this.studentsCount,
    required this.breakdown,
    required this.rate,
    required this.sessionsCount,
    this.rank,
  });

  final int courseCircleId;
  final String circleName;
  final String shiftName;
  final String teachersLabel;
  final int studentsCount;
  final StatusBreakdown breakdown;

  /// `null` لحلقةٍ **بلا صفِّ حضورٍ واحد** في المدّة — لا تُرسم صفراً، وإلا بدت
  /// حلقةٌ لم تُفتح جلستُها بعد أسوأَ من حلقةٍ غاب طلابُها.
  final double? rate;

  final int sessionsCount;

  /// الترتيبُ في الدوام — و`null` لحلقةٍ بلا نسبةٍ تُرتَّب بها.
  final int? rank;

  /// الرتبةُ تُعرَف بعد الفرز لا عند البناء، فتُختم على صفٍّ قائم بدل أن يُبنى
  /// مرّتين.
  CircleStanding withRank(int? value) => CircleStanding(
        courseCircleId: courseCircleId,
        circleName: circleName,
        shiftName: shiftName,
        teachersLabel: teachersLabel,
        studentsCount: studentsCount,
        breakdown: breakdown,
        rate: rate,
        sessionsCount: sessionsCount,
        rank: value,
      );
}

/// كلُّ ما يعرضه الداشبورد في قراءةٍ واحدة.
class InstituteOverview {
  const InstituteOverview({
    required this.counters,
    required this.todayRate,
    required this.trend,
    required this.breakdown,
    required this.standings,
    required this.hasCurrentCourse,
  });

  final InstituteCounters counters;

  /// `null` حين **لا جلسةَ اليوم بعد** — «لم تُفتح» لا «صفر بالمئة».
  final double? todayRate;

  final List<TrendPoint> trend;
  final StatusBreakdown breakdown;
  final List<CircleStanding> standings;

  /// معهدٌ بلا دورةٍ جارية يعرض بابَ الدورات لا كشفاً فارغاً.
  final bool hasCurrentCourse;
}

/// تقريرُ يومٍ واحد لحلقةٍ واحدة — نظير `BuildCircleDailyReport` محسوباً محلياً.
class CircleDailyReport {
  const CircleDailyReport({
    required this.circleName,
    required this.shiftName,
    required this.room,
    required this.teachersLabel,
    required this.date,
    required this.sessionStatus,
    required this.names,
    required this.breakdown,
    required this.rate,
    required this.rank,
    required this.cumulativeRate,
    required this.sessionsCount,
  });

  final String circleName;
  final String shiftName;
  final String? room;
  final String teachersLabel;
  final DateTime date;

  /// `null` لجلسةٍ **لم تُفتح** في هذا اليوم.
  final String? sessionStatus;

  /// أسماءُ الطلاب في كل حالة — مرتَّبةً، فالتقريرُ يُقرأ ويُطبع.
  final Map<AttendanceStatus, List<String>> names;

  final StatusBreakdown breakdown;
  final double? rate;
  final int? rank;
  final double? cumulativeRate;
  final int sessionsCount;

  bool get exists => sessionStatus != null;
}

/// صفُّ طالبٍ في تقرير النقاط، مقسوماً على مصادره كما في اللوحة.
class PointsReportRow {
  const PointsReportRow({
    required this.studentId,
    required this.studentName,
    required this.quran,
    required this.hadith,
    required this.mutun,
    required this.attendance,
    required this.manual,
    required this.rank,
  });

  final int studentId;
  final String studentName;

  /// نقاطُ التسميع كما **جمّدها الخادم** في `memorization_logs.points` — لا
  /// يعيد الجهازُ حسابَها من الأسطر، وإلا صار له رأيٌ في رقمٍ حسمه غيرُه.
  final double quran;

  final double hadith;
  final double mutun;

  /// **الوحيدُ الذي يحسبه الجهاز**: صفوفُ الحضور × قيمِ المعهد من `/bootstrap`.
  /// وهو مشتقٌّ لا مخزَّن على الخادم أيضاً — تعديلُ حضورٍ يغيّره.
  final double attendance;

  final double manual;
  final int rank;

  /// نظير [CircleStanding.withRank] — لا معنى لرتبةٍ قبل أن يُعرف المجموع.
  PointsReportRow withRank(int value) => PointsReportRow(
        studentId: studentId,
        studentName: studentName,
        quran: quran,
        hadith: hadith,
        mutun: mutun,
        attendance: attendance,
        manual: manual,
        rank: value,
      );

  double get total =>
      _round(quran + hadith + mutun + attendance + manual);

  static double _round(double value) => (value * 100).round() / 100;
}

/// تقريرُ نقاطِ حلقةٍ في مدى تواريخ.
class PointsReport {
  const PointsReport({
    required this.circleName,
    required this.shiftName,
    required this.from,
    required this.to,
    required this.rows,
  });

  final String circleName;
  final String shiftName;
  final DateTime from;
  final DateTime to;
  final List<PointsReportRow> rows;

  double get total =>
      (rows.fold<double>(0, (sum, row) => sum + row.total) * 100).round() / 100;
}
