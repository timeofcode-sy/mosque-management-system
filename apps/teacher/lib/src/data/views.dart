import 'package:mousqe_core/mousqe_core.dart';

/// حلقةٌ في الدورة الجارية مسنَدةٌ إلى صاحب الجهاز، مجموعةً من خمسة جداول
/// (`course_circles` + `circles` + `shifts` + `course_circle_teachers` + `enrollments`).
class CircleView {
  const CircleView({
    required this.id,
    required this.uuid,
    required this.circleName,
    required this.shiftName,
    required this.shiftStartsAt,
    required this.room,
    required this.capacity,
    required this.status,
    required this.studentsCount,
  });

  final int id;
  final String uuid;
  final String circleName;
  final String shiftName;

  /// `HH:MM:SS` — مرجعُ حساب دقائق التأخير، لا زمنُ فتح الجلسة (§0 البند 1).
  final String shiftStartsAt;

  final String? room;
  final int? capacity;
  final String status;
  final int studentsCount;

  /// `08:00:00` ⇒ `08:00` — ما يُعرَض لا ما يُحسب به.
  String get shiftStartsAtLabel => shiftStartsAt.split(':').take(2).join(':');
}

/// من أين جاءت الحالة المعروضة أمام الطالب — تمييزٌ يراه الأستاذ فيعرف ما التزم
/// به الخادمُ فعلاً وما لم يغادر جهازه بعد.
enum AttendanceOrigin {
  /// قيمةٌ اقترحها التطبيق ولم يقلها أحد: «حاضر» افتراضاً، أو «مأذون» لمن يغطّيه
  /// إذنٌ مقبول — نظير ما يزرعه `OpenAttendanceSession` على الخادم.
  suggested,

  /// سجّلها الأستاذ على هذا الجهاز وما زالت في الطابور.
  pending,

  /// وصلت من الخادم في `sync/pull`.
  synced,
}

/// صفٌّ في كشف التفقّد: الطالب، وحالتُه، ومصدرُ تلك الحالة.
class RosterEntry {
  const RosterEntry({
    required this.studentId,
    required this.studentUuid,
    required this.fullName,
    required this.status,
    required this.origin,
    required this.lateMinutes,
    this.lateMinutesOverride,
    required this.note,
    required this.recordedAt,
  });

  final int studentId;
  final String studentUuid;
  final String fullName;
  final AttendanceStatus status;
  final AttendanceOrigin origin;

  /// الرقم المعروض: محسوباً محلياً بـ[LateMinutes]، أو مصحَّحاً بيد الأستاذ.
  /// `null` لحالةٍ غير «متأخر».
  final int? lateMinutes;

  /// الرقم الذي كتبه الأستاذ بيده — و`null` يعني «احسبه أنت».
  ///
  /// التمييز عن [lateMinutes] هو العقد نفسه: `late_minutes` حقلٌ **اختياري
  /// ومقصودٌ تركُه فارغاً** ليحسبه `TakeAttendance` من بداية الدوام، والقيمةُ
  /// المرسَلة صراحةً تغلب المحسوبة ([API.md §6](../../../../../docs/API.md)).
  /// فإرسالُ الرقم المعروض دائماً يعني تجميدَ حسابٍ محليٍّ محلَّ حساب الخادم.
  final int? lateMinutesOverride;

  final String? note;
  final DateTime? recordedAt;

  RosterEntry copyWith({
    AttendanceStatus? status,
    AttendanceOrigin? origin,
    int? lateMinutes,
    int? lateMinutesOverride,
    bool clearLateMinutes = false,
    String? note,
    bool clearNote = false,
    DateTime? recordedAt,
  }) {
    return RosterEntry(
      studentId: studentId,
      studentUuid: studentUuid,
      fullName: fullName,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      lateMinutes: clearLateMinutes ? null : (lateMinutes ?? this.lateMinutes),
      lateMinutesOverride: clearLateMinutes
          ? null
          : (lateMinutesOverride ?? this.lateMinutesOverride),
      note: clearNote ? null : (note ?? this.note),
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}

/// حالةُ جلسةِ يومٍ واحد لحلقة واحدة، مركَّبةً من الصفوف المتزامنة فوقها المسودّة المحلية.
class SessionView {
  const SessionView({
    required this.circle,
    required this.date,
    required this.serverUuid,
    required this.localUuid,
    required this.status,
    required this.roster,
  });

  final CircleView circle;
  final DateTime date;

  /// معرّف الجلسة كما يعرفه الخادم — `null` ما لم تصل بعد في `sync/pull`.
  final String? serverUuid;

  /// المعرّف الذي ولّده هذا الجهاز حين فتحها بلا شبكة.
  final String? localUuid;

  /// `draft` \| `completed` \| `locked` \| `null` لجلسةٍ لم تُفتح بعد.
  final String? status;

  final List<RosterEntry> roster;

  bool get exists => status != null;

  /// نظير `AttendanceSession::isEditable()` حرفياً: المسوّدة وحدها تقبل التحرير.
  ///
  /// والأستاذ **لا يملك** `attendance.amend`، فجلسةٌ أُقفلت لا يصحّحها من جهازه
  /// ([SYNC-PROTOCOL.md §6](../../../../../docs/SYNC-PROTOCOL.md)). منعُ التحرير هنا
  /// ليس تجميلاً: بدونه يجمع الطابورُ عملياتٍ مصيرُها الرفض بعد ساعات.
  bool get editable => status == null || status == 'draft';

  bool get hasPendingRows =>
      roster.any((entry) => entry.origin == AttendanceOrigin.pending);

  int countOf(AttendanceStatus status) =>
      roster.where((entry) => entry.status == status).length;
}

/// سطرٌ في سجل الجلسات.
class SessionLogEntry {
  const SessionLogEntry({
    required this.uuid,
    required this.circleName,
    required this.date,
    required this.status,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
  });

  final String uuid;
  final String circleName;
  final DateTime date;
  final String status;
  final int present;
  final int absent;
  final int late;
  final int excused;

  int get total => present + absent + late + excused;
}

/// ملفّ الطالب كما يبنيه العميل محلياً — الإحصاءات مشتقّة تُحسب هنا لا تُنقل
/// عبر الشبكة ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md)).
class StudentProfile {
  const StudentProfile({
    required this.studentId,
    required this.uuid,
    required this.fullName,
    required this.registrationNo,
    required this.attendance,
    required this.recitations,
    required this.points,
  });

  final int studentId;
  final String uuid;
  final String fullName;
  final String? registrationNo;
  final List<StudentAttendanceEntry> attendance;
  final List<RecitationRow> recitations;
  final List<StudentPointRow> points;

  int countOf(AttendanceStatus status) =>
      attendance.where((entry) => entry.status == status).length;

  double get totalPoints =>
      points.fold<double>(0, (sum, row) => sum + row.points) +
      recitations.fold<double>(0, (sum, row) => sum + row.points);

  /// نظير `App\Support\AttendanceRate`: المأذون خارج المقام، والحاضر والمتأخر في البسط.
  double? get attendanceRate {
    final counted = attendance.length - countOf(AttendanceStatus.excused);
    if (counted <= 0) {
      return null;
    }

    final attended =
        countOf(AttendanceStatus.present) + countOf(AttendanceStatus.late);

    return attended / counted * 100;
  }
}

class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.date,
    required this.status,
    required this.lateMinutes,
    required this.note,
  });

  final DateTime date;
  final AttendanceStatus status;
  final int? lateMinutes;
  final String? note;
}
