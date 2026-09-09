import '../models/enums.dart';
import '../db/database.dart';
import '../support/quran.dart';

/// أستاذٌ مسنَدٌ إلى حلقةٍ في الدورة الجارية — يُعرَض في كشف الحلقات، وهو صفٌّ في
/// كشف **تفقّد الأساتذة** الذي يملكه الديسكتوب وحده (م.6.4).
class TeacherView {
  const TeacherView({
    required this.id,
    required this.uuid,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String uuid;
  final String fullName;

  /// `main` \| `assistant` — كما في `course_circle_teachers.role`.
  final String role;

  String get roleLabel => role == 'assistant' ? 'مساعد' : 'أساسي';
}

/// حلقةٌ في الدورة الجارية، مجموعةً من خمسة جداول
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
    this.teachers = const [],
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

  /// أساتذةُ الحلقة — فارغةٌ في كشف الأستاذ (يعرف نفسَه)، ومملوءةٌ في كشف المشرف.
  final List<TeacherView> teachers;

  /// `08:00:00` ⇒ `08:00` — ما يُعرَض لا ما يُحسب به.
  String get shiftStartsAtLabel => shiftStartsAt.split(':').take(2).join(':');

  String get teachersLabel =>
      teachers.map((teacher) => teacher.fullName).join(' · ');
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

/// تسميعٌ مسجَّل في الجلسة كما يُعرض ويُصحَّح — متزامناً كان أو مسودّةً محلية.
///
/// [uuid] هو ما يُصحَّح به ويُحذف: يولّده هذا الجهاز عند التسجيل، فيبقى المرجع
/// نفسه قبل المزامنة وبعدها ([API.md §6](../../../../../docs/API.md)).
class RecitationEntry {
  const RecitationEntry({
    required this.uuid,
    required this.type,
    required this.grade,
    required this.fromSurah,
    required this.fromAyah,
    required this.toSurah,
    required this.toAyah,
    required this.juz,
    required this.notes,
    required this.points,
    required this.pending,
  });

  final String uuid;
  final RecitationType type;
  final RecitationGrade? grade;
  final int fromSurah;
  final int fromAyah;
  final int toSurah;
  final int toAyah;
  final int? juz;
  final String? notes;

  /// النقاط كما جمّدها الخادم — و`null` لمسودّةٍ لم تصله بعد، فهو من يحسبها.
  final double? points;

  /// مسودّةٌ في الطابور لم يؤكّدها الخادم.
  final bool pending;

  /// «الملك 1–30» أو «الملك 20 – القلم 5».
  String get rangeLabel => fromSurah == toSurah
      ? '${Quran.name(fromSurah)} $fromAyah–$toAyah'
      : '${Quran.name(fromSurah)} $fromAyah – ${Quran.name(toSurah)} $toAyah';
}

/// منحةُ نقاطٍ في الجلسة كما تُعرض وتُصحَّح — نظير [RecitationEntry].
class PointEntry {
  const PointEntry({
    required this.uuid,
    required this.points,
    required this.reason,
    required this.note,
    required this.pending,
  });

  final String uuid;
  final double points;
  final PointsReason reason;
  final String? note;
  final bool pending;
}

/// صفٌّ في كشف التفقّد: الطالب، وحالتُه، ومصدرُ تلك الحالة، وما سُجّل له في الجلسة.
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
    this.recitations = const [],
    this.points = const [],
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

  /// تسميعات الطالب ونقاطه في هذه الجلسة — تُعرض تحت اسمه ويُنقر عليها لتصحيحها.
  final List<RecitationEntry> recitations;

  final List<PointEntry> points;

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
      recitations: recitations,
      points: points,
    );
  }
}

/// صفُّ أستاذٍ في كشف تفقّد الأساتذة — نظير [RosterEntry] وأخصرُ منه.
///
/// وأقصرُ بثلاثة أشياء عمداً: لا تسميعَ ولا نقاطَ (هي للطالب)، ولا `recordedAt`
/// يُرسَل (العقدُ لا يحمله فلا حسمَ تعارض)، ولا حالةً «مقترحة» — الأستاذُ الذي لم
/// يُسجَّل حضورُه لا يُفترض حاضراً، بخلاف الطالب: الخادمُ يزرع صفوفَ الطلاب عند
/// فتح الجلسة ولا يزرع صفوفَ الأساتذة.
class TeacherRosterEntry {
  const TeacherRosterEntry({
    required this.teacherId,
    required this.teacherUuid,
    required this.fullName,
    required this.roleLabel,
    required this.status,
    required this.recorded,
    required this.pending,
    this.lateMinutes,
    this.note,
  });

  final int teacherId;
  final String teacherUuid;
  final String fullName;
  final String roleLabel;
  final AttendanceStatus status;

  /// هل سُجّل له حضورٌ فعلاً؟ — و`false` تعني أن [status] قيمةُ نموذجٍ لا حكمٌ وقع.
  final bool recorded;

  /// كتابةٌ على هذا الجهاز لم يؤكّدها الخادم بعد.
  final bool pending;

  final int? lateMinutes;
  final String? note;

  TeacherRosterEntry copyWith({
    AttendanceStatus? status,
    int? lateMinutes,
    bool clearLateMinutes = false,
    String? note,
    bool clearNote = false,
  }) {
    return TeacherRosterEntry(
      teacherId: teacherId,
      teacherUuid: teacherUuid,
      fullName: fullName,
      roleLabel: roleLabel,
      status: status ?? this.status,
      recorded: true,
      pending: true,
      lateMinutes: clearLateMinutes ? null : (lateMinutes ?? this.lateMinutes),
      note: clearNote ? null : (note ?? this.note),
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
    this.teacherRoster = const [],
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

  /// كشفُ أساتذة الحلقة — فارغٌ في تطبيق الأستاذ، فهو لا يتفقّدهم.
  final List<TeacherRosterEntry> teacherRoster;

  bool get exists => status != null;

  bool get completed => status == 'completed';

  /// المقفلةُ نهائيّةٌ لا يعدّلها أحد — ولا يعيد فتحَها أحد.
  bool get locked => status == 'locked';

  /// هل يقبل هذا الكشفُ تحريراً **من هذا المستخدم**؟
  ///
  /// نقلٌ حرفيّ لِـ`editable()` في شاشة اللوحة، وبنفس الترتيب:
  ///
  /// | الحالة | الحكم |
  /// |---|---|
  /// | مقفلة | **لا** لأحد — القفل قرارٌ نهائي |
  /// | مكتملة | لحاملِ `attendance.amend` وحده |
  /// | مسودّة أو لم تُفتح | نعم |
  ///
  /// 🔄 **م.6.4: صارت تقرأ الصلاحية بدل أن تفترض الأستاذ.** كانت `editable` تحرّم
  /// المكتملةَ على الجميع لأن التطبيق الوحيد كان تطبيقَ الأستاذ وهو لا يملك
  /// `attendance.amend`. والآن الفرقُ بين السطحين **ما يملكه فاتحُهما** لا نسخةُ
  /// البرنامج: المشرفُ يصحّح المكتملةَ من الديسكتوب، والأستاذُ لا — لا لأن شيفرةً
  /// تمنعه بل لأن الصلاحيةَ ليست في لقطته. وهو نفسُ الحكم الذي يطبّقه الخادم في
  /// `SyncPush::assertPermitted`، فما يُصفّ هنا لا يُرفض بعد ساعات
  /// ([SYNC-PROTOCOL.md §6](../../../../../docs/SYNC-PROTOCOL.md)).
  bool editableBy({required bool canAmend}) => switch (status) {
    'locked' => false,
    'completed' => canAmend,
    _ => true,
  };

  /// هل هذا الحفظُ **تصحيحٌ رجعي**؟ — أي: يقع على جلسةٍ أُكملت.
  ///
  /// وهو ما يُرفع في `amend` إلى `sync/push`، فيحرسه الخادمُ بالصلاحية نفسِها.
  bool get isAmendment => completed;

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
