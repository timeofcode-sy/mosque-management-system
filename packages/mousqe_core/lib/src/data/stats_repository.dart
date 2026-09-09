import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/enums.dart';
import '../models/points_settings.dart';
import '../support/attendance_rate.dart';
import 'stats_views.dart';

/// أرقامُ الداشبورد والتقارير، **محسوبةً على الجهاز** من الصفوف المتزامنة — ✅ م.6.6.
///
/// وهو المستودعُ الرابع، وقناتُه في جدول [PHASE-6-STAGES.MD §6.1] صفٌّ لم يكن
/// فيه: **يقرأ من drift ولا يكتب شيئاً**. ولذلك لا `SyncEngine` فيه ولا
/// `ApiClient` — كائنُ قراءةٍ صرف.
///
/// ### 🔑 لماذا يُحسب هنا ولا يُطلب من الخادم؟
///
/// لأن `circle_daily_stats` و`circle_cumulative_stats` جدولان **لا يُزامَنان**
/// ([SYNC-PROTOCOL.md §7](../../../../../docs/SYNC-PROTOCOL.md)): «نقلُ ما يمكن
/// حسابُه نقلٌ زائد». فلا سبيلَ إلى رقمِ الخادم إلا نقطةُ API جديدة تُطلَب في كل
/// فتحِ شاشة — وهي بالضبط ما يجعل الداشبورد بابَ الديسكتوب الوحيد الذي **لا
/// يُفتح والشبكةُ مقطوعة**. وشرطُ [APPS-FEATURES.md §4.2](../../../../../docs/APPS-FEATURES.md)
/// البندين 6 و7 أن يُقرأ ويُطبع أوف-لاين.
///
/// ### 🔑 والقاعدةُ الحاكمة: **ما لم يُسجَّل لا يُفترض**
///
/// `CircleRepository.loadSession` تعرض للطالب الذي لا صفَّ له حالةً `suggested`
/// — «حاضر» مقترحةً تنتظر من يؤكّدها، نظيرَ زرعِ `OpenAttendanceSession`. وهي
/// **قيمةُ استمارةٍ لا تفقُّدٌ وقع**، فلا تدخل إحصاءً هنا: لو دخلت لَصار عددُ
/// الحاضرين في حلقةٍ لم يفتح أحدٌ جلستَها **كاملَ كشفها**، ولَقرأ المشرفُ في
/// داشبوردِه ١٠٠٪ عن يومٍ لم يُتفقَّد فيه أحد.
///
/// وهي نفسُ القاعدة التي حسمت تفقّدَ الأساتذة في م.6.4: «الأستاذُ غيرُ المسجَّل
/// لا يُفترض حاضراً» ([CHECKPOINT-PHASE-6.4.MD §4](../../../../../docs/CHECKPOINT-PHASE-6.4.MD)).
///
/// **وما يُحسب إذن صفّان:** المتزامنُ من `attendances`، تعلوه مسودّةُ هذا الجهاز
/// من `local_attendances` — بنفس غلبةِ [CircleRepository.loadSession] حرفياً،
/// فلا يرى المشرفُ في داشبوردِه خلافَ ما يراه في الشاشة التي كتب فيها قبل لحظة.
class StatsRepository {
  StatsRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  // ------------------------------------------------------------ الداشبورد

  /// كلُّ ما يعرضه الداشبورد في قراءةٍ واحدة — نظير `DashboardOverviewQuery`
  /// الخادمي، وكلُّ رقمٍ فيه يمرّ بـ[AttendanceRate] لا بمعادلةٍ ثانية.
  ///
  /// [today] معاملٌ لا `DateTime.now()` مدفونة: اختبارٌ يقيس منحنى أسبوعين يحتاج
  /// أن يثبّت «اليوم»، وشاشةٌ تعرض تاريخاً غيرَ اليوم تمرّره.
  Future<InstituteOverview> loadOverview({
    DateTime? today,
    int trendDays = 14,
  }) async {
    final day = _dateOnly(today ?? DateTime.now());
    final course = await _currentCourse();

    final counters = await _counters(course);

    if (course == null) {
      return InstituteOverview(
        counters: counters,
        todayRate: null,
        trend: const [],
        breakdown: const StatusBreakdown(),
        standings: const [],
        hasCurrentCourse: false,
      );
    }

    final circles = await _circlesOf(course.id);
    final from = day.subtract(Duration(days: trendDays - 1));

    final records = await _records(
      courseCircleIds: [for (final circle in circles) circle.id],
      from: from,
      to: day,
    );

    // يومٌ يُقاس مرّةً واحدة: التجميعُ بالتاريخ ثم بالحلقة، لا استعلامٌ لكل يوم.
    final byDay = <DateTime, StatusBreakdown>{};

    for (final record in records) {
      byDay[record.date] =
          (byDay[record.date] ?? const StatusBreakdown()).plus(record.one);
    }

    return InstituteOverview(
      counters: counters,
      todayRate: _rateOf(byDay[day]),
      trend: [
        for (var offset = 0; offset < trendDays; offset++)
          _trendPointOn(from.add(Duration(days: offset)), byDay, records),
      ],
      breakdown: byDay.values.fold(
        const StatusBreakdown(),
        (sum, day) => sum.plus(day),
      ),
      standings: _rank(await _standings(circles, records)),
      hasCurrentCourse: true,
    );
  }

  Stream<InstituteOverview> watchOverview({
    DateTime? today,
    int trendDays = 14,
  }) => _watch(() => loadOverview(today: today, trendDays: trendDays));

  // -------------------------------------------------------- تقريرُ اليوم

  /// تقريرُ يومٍ واحد لحلقةٍ واحدة — نظير `BuildCircleDailyReport` محسوباً محلياً.
  ///
  /// و`null` لحلقةٍ لا وجودَ لها في المخزن، لا لحلقةٍ بلا جلسة: الأخيرةُ تقريرٌ
  /// صحيحٌ يقول **«لم تُفتح»**، وهو خبرٌ يعني صاحبَه.
  Future<CircleDailyReport?> loadDailyReport({
    required int courseCircleId,
    required DateTime date,
  }) async {
    final day = _dateOnly(date);
    final circle = await _circleOf(courseCircleId);

    if (circle == null) {
      return null;
    }

    // الترتيبُ في **الدوام** لا في المعهد: حلقةُ الفجر لا تُقاس بحلقة العصر،
    // وهو نفسُ حصر `daily_rank_in_shift` خادمياً.
    final peers = await _circlesOf(circle.courseId, shiftId: circle.shiftId);

    final ofDay = await _records(
      courseCircleIds: [for (final peer in peers) peer.id],
      from: day,
      to: day,
    );

    final standings = _rank(await _standings(peers, ofDay));
    final mine = standings.where((row) => row.courseCircleId == courseCircleId);

    // التراكميُّ من أوّل الدورة إلى هذا اليوم — لا إلى اليوم الحاضر: تقريرُ
    // أمسِ يجب أن يقرأ كما قُرئ أمس مهما طُبع متأخّراً.
    final cumulative = await _records(
      courseCircleIds: [courseCircleId],
      to: day,
    );

    final status = await _sessionStatus(courseCircleId, day);
    final names = <AttendanceStatus, List<String>>{
      for (final status in AttendanceStatus.values) status: [],
    };

    final students = await _studentNames({
      for (final record in ofDay)
        if (record.courseCircleId == courseCircleId) record.studentId,
    });

    for (final record in ofDay) {
      if (record.courseCircleId != courseCircleId) {
        continue;
      }

      names[record.status]!.add(students[record.studentId] ?? '—');
    }

    for (final list in names.values) {
      list.sort();
    }

    final breakdown = _breakdownOf(
      ofDay.where((record) => record.courseCircleId == courseCircleId),
    );

    return CircleDailyReport(
      circleName: circle.circleName,
      shiftName: circle.shiftName,
      room: circle.room,
      teachersLabel: circle.teachersLabel,
      date: day,
      sessionStatus: status,
      names: names,
      breakdown: breakdown,
      rate: breakdown.total == 0 ? null : _rateOf(breakdown),
      rank: mine.isEmpty ? null : mine.first.rank,
      cumulativeRate: _rateOf(_breakdownOf(cumulative)),
      sessionsCount: _sessionsIn(cumulative),
    );
  }

  // ------------------------------------------------------- تقريرُ النقاط

  /// نقاطُ طلاب حلقةٍ في مدى تواريخ — نظير `BuildCirclePointsReport`.
  ///
  /// و[points] تصل من `/bootstrap` لا من ثوابتِ الحزمة: `institutes.settings`
  /// جدولٌ لا يُزامَن، فلولا حملُها في اللقطة لَحسب الجهازُ أعمدةَ الحضور
  /// بافتراضياتٍ تخالف قيمَ المعهد — واختلافُ رقمٍ مطبوعٍ عن رقم اللوحة أسوأُ
  /// من غيابه.
  Future<PointsReport?> loadPointsReport({
    required int courseCircleId,
    required DateTime from,
    required DateTime to,
    PointsSettings points = const PointsSettings(),
  }) async {
    final circle = await _circleOf(courseCircleId);

    if (circle == null) {
      return null;
    }

    final start = _dateOnly(from);
    final end = _dateOnly(to);

    final studentIds = await _activeStudentIds(courseCircleId);
    final names = await _studentNames(studentIds);

    final attendance = <int, double>{};

    for (final record in await _records(
      courseCircleIds: [courseCircleId],
      from: start,
      to: end,
    )) {
      attendance[record.studentId] =
          (attendance[record.studentId] ?? 0) + points.attendance(record.status);
    }

    final recited = await _recitationPoints(studentIds, start, end);
    final progressed = await _progressPoints(studentIds, start, end);
    final manual = await _manualPoints(studentIds, start, end);

    double sourceOf(Map<int, Map<String, double>> bag, int id, String type) =>
        bag[id]?[type] ?? 0;

    final rows = [
      for (final id in studentIds)
        PointsReportRow(
          studentId: id,
          studentName: names[id] ?? '—',
          quran: sourceOf(recited, id, 'quran') + sourceOf(progressed, id, 'quran'),
          hadith:
              sourceOf(recited, id, 'hadith') + sourceOf(progressed, id, 'hadith'),
          mutun: sourceOf(recited, id, 'mutun') + sourceOf(progressed, id, 'mutun'),
          attendance: attendance[id] ?? 0,
          manual: manual[id] ?? 0,
          // تُملأ في [_rankPoints] بعد الفرز — لا معنى لرتبةٍ قبل أن يُعرف المجموع.
          rank: 0,
        ),
    ];

    return PointsReport(
      circleName: circle.circleName,
      shiftName: circle.shiftName,
      from: start,
      to: end,
      rows: _rankPoints(rows),
    );
  }

  /// حلقاتُ الدورة الجارية — مدخلُ قائمةِ اختيار الحلقة في شاشة التقارير.
  Future<List<CircleStanding>> loadReportableCircles() async {
    final course = await _currentCourse();

    if (course == null) {
      return const [];
    }

    return _standings(await _circlesOf(course.id), const []);
  }

  // ------------------------------------------------------ جمعُ ما سُجِّل

  /// صفوفُ الحضور **المسجَّلة** في المدّة: المتزامنُ تعلوه مسودّةُ هذا الجهاز.
  ///
  /// استعلاماتٌ أربعة مهما بلغ عددُ الحلقات والأيام — لا استعلامٌ لكل حلقة ولا
  /// لكل يوم. وحدُّ المدّة مفتوحُ الطرفين: [from] فارغةً تعني «من أوّل الدورة»
  /// وهو ما يحتاجه التراكميّ.
  Future<List<_Record>> _records({
    required List<int> courseCircleIds,
    DateTime? from,
    DateTime? to,
  }) async {
    if (courseCircleIds.isEmpty) {
      return const [];
    }

    final sessionsQuery = _db.select(_db.attendanceSessions)
      ..where((t) {
        var filter = t.courseCircleId.isIn(courseCircleIds);

        if (from != null) {
          filter = filter & t.sessionDate.isBiggerOrEqualValue(from);
        }

        if (to != null) {
          filter = filter & t.sessionDate.isSmallerOrEqualValue(to);
        }

        return filter;
      });

    final sessions = {
      for (final row in await sessionsQuery.get()) row.id: row,
    };

    final records = <(int, DateTime, int), _Record>{};

    if (sessions.isNotEmpty) {
      final rows = await (_db.select(_db.attendances)
            ..where((t) => t.attendanceSessionId.isIn(sessions.keys.toList())))
          .get();

      for (final row in rows) {
        final session = sessions[row.attendanceSessionId]!;
        final date = _dateOnly(session.sessionDate);

        records[(session.courseCircleId, date, row.studentId)] = _Record(
          courseCircleId: session.courseCircleId,
          date: date,
          studentId: row.studentId,
          status: _status(row.status),
          pending: false,
        );
      }
    }

    final draftsQuery = _db.select(_db.localAttendances)
      ..where((t) {
        var filter = t.courseCircleId.isIn(courseCircleIds);

        if (from != null) {
          filter = filter & t.sessionDate.isBiggerOrEqualValue(from);
        }

        if (to != null) {
          filter = filter & t.sessionDate.isSmallerOrEqualValue(to);
        }

        return filter;
      });

    for (final row in await draftsQuery.get()) {
      final date = _dateOnly(row.sessionDate);

      records[(row.courseCircleId, date, row.studentId)] = _Record(
        courseCircleId: row.courseCircleId,
        date: date,
        studentId: row.studentId,
        status: _status(row.status),
        pending: true,
      );
    }

    return records.values.toList();
  }

  static StatusBreakdown _breakdownOf(Iterable<_Record> records) =>
      records.fold(const StatusBreakdown(), (sum, record) => sum.plus(record.one));

  /// عددُ الأيام التي سُجِّل فيها صفٌّ واحد على الأقل — «جلسةٌ قِيست».
  static int _sessionsIn(Iterable<_Record> records) =>
      {for (final record in records) (record.courseCircleId, record.date)}.length;

  /// `null` حين **لا صفَّ يُقاس** — وهو غيرُ الصفر الذي يعني «قِيس فكان صفراً».
  static double? _rateOf(StatusBreakdown? breakdown) {
    if (breakdown == null || breakdown.total == 0) {
      return null;
    }

    return AttendanceRate.percent(
      present: breakdown.present,
      late: breakdown.late,
      excused: breakdown.excused,
      total: breakdown.total,
    );
  }

  static TrendPoint _trendPointOn(
    DateTime date,
    Map<DateTime, StatusBreakdown> byDay,
    List<_Record> records,
  ) {
    final breakdown = byDay[date];

    return TrendPoint(
      date: date,
      rate: _rateOf(breakdown),
      sessions: _sessionsIn(records.where((record) => record.date == date)),
    );
  }

  // ------------------------------------------------------------ الترتيب

  Future<List<CircleStanding>> _standings(
    List<_Circle> circles,
    List<_Record> records,
  ) async {
    final standings = <CircleStanding>[];

    for (final circle in circles) {
      final mine = records.where(
        (record) => record.courseCircleId == circle.id,
      );

      final breakdown = _breakdownOf(mine);

      standings.add(
        CircleStanding(
          courseCircleId: circle.id,
          circleName: circle.circleName,
          shiftName: circle.shiftName,
          teachersLabel: circle.teachersLabel,
          studentsCount: await _activeEnrollmentCount(circle.id),
          breakdown: breakdown,
          rate: _rateOf(breakdown),
          sessionsCount: _sessionsIn(mine),
        ),
      );
    }

    return standings;
  }

  /// ترتيبٌ تنافسيّ داخلَ **كل دوامٍ على حدة** (1، 1، 3) — نقلٌ حرفي لـ
  /// `RecalculateCircleStats::assignRanks`: النسبةُ نازلاً، ويفصل التعادلَ عددُ
  /// الحاضرين ثم معرّفُ الحلقة لثبات النتيجة بين قراءتين.
  ///
  /// **وحلقةٌ بلا نسبة لا تُرتَّب.** لو رُتّبت صفراً لَبدت حلقةٌ لم تُفتح جلستُها
  /// أسوأَ من حلقةٍ غاب طلابُها كلُّهم — وهما ليسا خبراً واحداً.
  static List<CircleStanding> _rank(List<CircleStanding> standings) {
    final ranked = <CircleStanding>[];

    for (final shift in {for (final row in standings) row.shiftName}) {
      final peers =
          standings.where((row) => row.shiftName == shift && row.rate != null).toList()
            ..sort((a, b) {
              final byRate = b.rate!.compareTo(a.rate!);

              if (byRate != 0) {
                return byRate;
              }

              final byPresent = b.breakdown.present.compareTo(a.breakdown.present);

              return byPresent != 0
                  ? byPresent
                  : a.courseCircleId.compareTo(b.courseCircleId);
            });

      var rank = 0;
      var seen = 0;
      double? previous;

      for (final row in peers) {
        seen++;

        if (row.rate != previous) {
          rank = seen;
          previous = row.rate;
        }

        ranked.add(row.withRank(rank));
      }

      ranked.addAll(
        standings.where((row) => row.shiftName == shift && row.rate == null),
      );
    }

    return ranked
      ..sort((a, b) {
        final byShift = a.shiftName.compareTo(b.shiftName);

        if (byShift != 0) {
          return byShift;
        }

        return (a.rank ?? 1 << 30).compareTo(b.rank ?? 1 << 30);
      });
  }

  /// ترتيبُ تقرير النقاط — نقلُ `BuildCirclePointsReport::rank`: المتساوون
  /// يأخذون الرتبة نفسَها، ويفصل التعادلَ اسمُ الطالب لثبات الترتيب.
  static List<PointsReportRow> _rankPoints(List<PointsReportRow> rows) {
    final sorted = rows.toList()
      ..sort((a, b) {
        final byTotal = b.total.compareTo(a.total);

        return byTotal != 0 ? byTotal : a.studentName.compareTo(b.studentName);
      });

    final ranked = <PointsReportRow>[];

    var rank = 0;
    var seen = 0;
    double? previous;

    for (final row in sorted) {
      seen++;

      if (row.total != previous) {
        rank = seen;
        previous = row.total;
      }

      ranked.add(row.withRank(rank));
    }

    return ranked;
  }

  // ------------------------------------------------------------ الداخلية

  Future<CourseRow?> _currentCourse() =>
      (_db.select(_db.courses)..where((t) => t.isCurrent.equals(true))..limit(1))
          .getSingleOrNull();

  Future<InstituteCounters> _counters(CourseRow? course) async {
    // المخزنُ معهدٌ واحد بحكم البروتوكول — السحبُ يرشّح بـ`scope_key`، وتبديلُ
    // المعهد يمسحه كاملاً (م.6.3). فعدُّ الصفوف كلِّها هو عدُّ صفوف هذا المعهد.
    final students = await _count(_db.students);
    final teachers = await _count(_db.teachers);

    if (course == null) {
      return InstituteCounters(
        students: students,
        teachers: teachers,
        circles: 0,
        enrolled: 0,
      );
    }

    final circles = await (_db.select(_db.courseCircles)
          ..where((t) => t.courseId.equals(course.id)))
        .get();

    var enrolled = 0;

    for (final circle in circles) {
      enrolled += await _activeEnrollmentCount(circle.id);
    }

    return InstituteCounters(
      students: students,
      teachers: teachers,
      circles: circles.length,
      enrolled: enrolled,
    );
  }

  Future<int> _count(TableInfo<Table, dynamic> table) async {
    final rows = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM ${table.actualTableName}',
      readsFrom: {table},
    ).getSingle();

    return rows.read<int>('c');
  }

  Future<int> _activeEnrollmentCount(int courseCircleId) async {
    final total = _db.enrollments.id.count();

    final row = await (_db.selectOnly(_db.enrollments)
          ..addColumns([total])
          ..where(
            _db.enrollments.courseCircleId.equals(courseCircleId) &
                _db.enrollments.status.equals('active'),
          ))
        .getSingle();

    return row.read(total) ?? 0;
  }

  Future<List<int>> _activeStudentIds(int courseCircleId) async {
    final rows = await (_db.select(_db.enrollments)
          ..where(
            (t) =>
                t.courseCircleId.equals(courseCircleId) &
                t.status.equals('active'),
          ))
        .get();

    return [for (final row in rows) row.studentId];
  }

  Future<Map<int, String>> _studentNames(Iterable<int> ids) async {
    final unique = ids.toSet().toList();

    if (unique.isEmpty) {
      return const {};
    }

    final rows =
        await (_db.select(_db.students)..where((t) => t.id.isIn(unique))).get();

    return {
      for (final row in rows)
        row.id: '${row.firstName} ${row.fatherName} ${row.familyName}',
    };
  }

  /// حالةُ جلسةٍ بعينها — بنفس غلبةِ `CircleRepository.loadDayStatuses`:
  /// المحليُّ يعلو المتزامن حين يكون **أبعدَ في الطريق** لا لمجرّد أنه محلي.
  Future<String?> _sessionStatus(int courseCircleId, DateTime day) async {
    final session = await (_db.select(_db.attendanceSessions)
          ..where(
            (t) =>
                t.courseCircleId.equals(courseCircleId) &
                t.sessionDate.equals(day),
          ))
        .getSingleOrNull();

    final local = await (_db.select(_db.localSessions)
          ..where(
            (t) =>
                t.courseCircleId.equals(courseCircleId) &
                t.sessionDate.equals(day),
          ))
        .getSingleOrNull();

    if (local == null) {
      return session?.status;
    }

    final drafted = local.locked
        ? 'locked'
        : (local.completed ? 'completed' : 'draft');

    const rank = {'draft': 0, 'completed': 1, 'locked': 2};

    return (rank[drafted] ?? 0) >= (rank[session?.status] ?? -1)
        ? drafted
        : session!.status;
  }

  Future<List<_Circle>> _circlesOf(int courseId, {int? shiftId}) async {
    final query = _db.select(_db.courseCircles).join([
      innerJoin(_db.circles, _db.circles.id.equalsExp(_db.courseCircles.circleId)),
      innerJoin(_db.shifts, _db.shifts.id.equalsExp(_db.courseCircles.shiftId)),
    ]);

    query
      ..where(
        shiftId == null
            ? _db.courseCircles.courseId.equals(courseId)
            : _db.courseCircles.courseId.equals(courseId) &
                _db.courseCircles.shiftId.equals(shiftId),
      )
      ..orderBy([
        OrderingTerm.asc(_db.shifts.sortOrder),
        OrderingTerm.asc(_db.circles.name),
      ]);

    final circles = <_Circle>[];

    for (final row in await query.get()) {
      final courseCircle = row.readTable(_db.courseCircles);

      circles.add(
        _Circle(
          id: courseCircle.id,
          courseId: courseCircle.courseId,
          shiftId: courseCircle.shiftId,
          circleName: row.readTable(_db.circles).name,
          shiftName: row.readTable(_db.shifts).name,
          room: courseCircle.room,
          teachersLabel: await _teachersLabel(courseCircle.id),
        ),
      );
    }

    return circles;
  }

  Future<_Circle?> _circleOf(int courseCircleId) async {
    final courseCircle = await (_db.select(_db.courseCircles)
          ..where((t) => t.id.equals(courseCircleId)))
        .getSingleOrNull();

    if (courseCircle == null) {
      return null;
    }

    final circles = await _circlesOf(
      courseCircle.courseId,
      shiftId: courseCircle.shiftId,
    );

    return circles.where((circle) => circle.id == courseCircleId).firstOrNull;
  }

  Future<String> _teachersLabel(int courseCircleId) async {
    final query =
        _db.select(_db.courseCircleTeachers).join([
            innerJoin(
              _db.teachers,
              _db.teachers.id.equalsExp(_db.courseCircleTeachers.teacherId),
            ),
          ])
          ..where(_db.courseCircleTeachers.courseCircleId.equals(courseCircleId))
          ..orderBy([OrderingTerm.asc(_db.teachers.displayName)]);

    final names = [
      for (final row in await query.get()) row.readTable(_db.teachers).displayName,
    ];

    return names.isEmpty ? '—' : names.join('، ');
  }

  // --------------------------------------------------- مصادرُ نقاطٍ أخرى

  /// نقاطُ التسميع مقسومةً على نوع المنهج — والسجلُّ **بلا بندِ منهجٍ يُحسب
  /// قرآناً**، فالتسميع في الجلسة قرآنيٌّ بطبعه (نقلُ `StudentPointsQuery`).
  ///
  /// والمسودّةُ المحلية لا تدخل هنا، وليس ذلك استثناءً في القاعدة بل نتيجةً
  /// لها: `LocalRecitations` **بلا عمود نقاط أصلاً** — الأسطرُ والنقاطُ يحسبها
  /// الخادم ويجمّدها ([API.md §6](../../../../../docs/API.md))، فالمسودّةُ مدىً
  /// بلا رقم. ولو قدّر الجهازُ رقماً لَصار له رأيٌ في حسابٍ ليس له.
  Future<Map<int, Map<String, double>>> _recitationPoints(
    List<int> studentIds,
    DateTime from,
    DateTime to,
  ) async {
    if (studentIds.isEmpty) {
      return const {};
    }

    final types = await _curriculumTypes();

    final rows = await (_db.select(_db.recitations)
          ..where(
            (t) =>
                t.studentId.isIn(studentIds) &
                t.date.isBiggerOrEqualValue(from) &
                t.date.isSmallerOrEqualValue(to),
          ))
        .get();

    final points = <int, Map<String, double>>{};

    for (final row in rows) {
      final type = types[row.curriculumItemId] ?? 'quran';

      points.putIfAbsent(row.studentId, () => {});
      points[row.studentId]![type] =
          (points[row.studentId]![type] ?? 0) + row.points;
    }

    return points;
  }

  Future<Map<int, Map<String, double>>> _progressPoints(
    List<int> studentIds,
    DateTime from,
    DateTime to,
  ) async {
    if (studentIds.isEmpty) {
      return const {};
    }

    final types = await _curriculumTypes();

    final rows = await (_db.select(_db.studentCurriculumProgressTable)
          ..where(
            (t) =>
                t.studentId.isIn(studentIds) &
                t.achievedOn.isBiggerOrEqualValue(from) &
                t.achievedOn.isSmallerOrEqualValue(to),
          ))
        .get();

    final points = <int, Map<String, double>>{};

    for (final row in rows) {
      final type = types[row.curriculumItemId] ?? 'custom';

      points.putIfAbsent(row.studentId, () => {});
      points[row.studentId]![type] =
          (points[row.studentId]![type] ?? 0) + row.points;
    }

    return points;
  }

  /// نوعُ المنهج لكل بند — خريطةٌ واحدة بدل وصلٍ في كل استعلام.
  Future<Map<int, String>> _curriculumTypes() async {
    final query = _db.select(_db.curriculumItems).join([
      innerJoin(
        _db.curricula,
        _db.curricula.id.equalsExp(_db.curriculumItems.curriculumId),
      ),
    ]);

    return {
      for (final row in await query.get())
        row.readTable(_db.curriculumItems).id: row.readTable(_db.curricula).type,
    };
  }

  /// النقاطُ اليدوية — والمسودّةُ المحلية **تدخل** هنا خلافاً للتسميع، لأن
  /// رقمَها رقمُ صاحبِها لا رقمٌ يحسبه الخادم: هو ما كتبه المشرف بيده.
  Future<Map<int, double>> _manualPoints(
    List<int> studentIds,
    DateTime from,
    DateTime to,
  ) async {
    if (studentIds.isEmpty) {
      return const {};
    }

    final points = <int, double>{};
    final drafted = <String>{};

    for (final row in await (_db.select(_db.localPoints)
          ..where(
            (t) =>
                t.studentId.isIn(studentIds) &
                t.sessionDate.isBiggerOrEqualValue(from) &
                t.sessionDate.isSmallerOrEqualValue(to),
          ))
        .get()) {
      drafted.add(row.uuid);

      if (row.deleted) {
        continue;
      }

      points[row.studentId] = (points[row.studentId] ?? 0) + row.points;
    }

    for (final row in await (_db.select(_db.studentPoints)
          ..where(
            (t) =>
                t.studentId.isIn(studentIds) &
                t.awardedOn.isBiggerOrEqualValue(from) &
                t.awardedOn.isSmallerOrEqualValue(to),
          ))
        .get()) {
      // مسودّةٌ بنفس المعرّف تعلو المتزامن — وشاهدةُ الحذف تُسقطه، وإلا عاد
      // الصفُّ المتزامن إلى الحساب بين الحذف ونجاح الدفع.
      if (drafted.contains(row.uuid)) {
        continue;
      }

      points[row.studentId] = (points[row.studentId] ?? 0) + row.points;
    }

    return points;
  }

  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();

    await for (final _ in _db.tableUpdates()) {
      yield await read();
    }
  }

  static AttendanceStatus _status(String value) => AttendanceStatus.values
      .firstWhere(
        (status) => status.name == value,
        orElse: () => AttendanceStatus.present,
      );

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

/// حلقةٌ مشغَّلة بأسماءِ ما حولها — تُقرأ مرّةً وتُستعمل في الترتيب والتقرير.
class _Circle {
  const _Circle({
    required this.id,
    required this.courseId,
    required this.shiftId,
    required this.circleName,
    required this.shiftName,
    required this.room,
    required this.teachersLabel,
  });

  final int id;
  final int courseId;
  final int shiftId;
  final String circleName;
  final String shiftName;
  final String? room;
  final String teachersLabel;
}

/// صفُّ حضورٍ **سُجِّل فعلاً** — متزامناً كان أو مسودّةً على هذا الجهاز.
///
/// ولا وجودَ هنا لِما تسمّيه `CircleRepository` `suggested`: تلك قيمةُ استمارةٍ
/// تنتظر من يؤكّدها، وإحصاؤها اختراعُ تفقّدٍ لم يقع.
class _Record {
  const _Record({
    required this.courseCircleId,
    required this.date,
    required this.studentId,
    required this.status,
    required this.pending,
  });

  final int courseCircleId;
  final DateTime date;
  final int studentId;
  final AttendanceStatus status;

  /// لم يصل الخادمَ بعد — يُعرض وسماً على التقرير لا يُحذف من الحساب.
  final bool pending;

  StatusBreakdown get one => switch (status) {
        AttendanceStatus.present => const StatusBreakdown(present: 1),
        AttendanceStatus.absent => const StatusBreakdown(absent: 1),
        AttendanceStatus.late => const StatusBreakdown(late: 1),
        AttendanceStatus.excused => const StatusBreakdown(excused: 1),
      };
}
