import 'dart:convert';

import 'package:drift/drift.dart';

import '../api/api_client.dart';
import '../db/database.dart';
import 'admin_views.dart';

/// بنيةُ المعهد: الدوراتُ والدواماتُ والحلقاتُ والمناهج — ✅ م.6.5.
///
/// **يقرأ من drift ويكتب بـREST** — وهو التركيبُ الذي لا يوجد في
/// [StudentRepository] ولا في [CircleRepository]، وله سببٌ مُعلَن:
///
/// | | لماذا |
/// |---|---|
/// | **القراءة من drift** | الجداولُ الستةُ كلُّها تُزامَن، فما يُكتب هنا يعود في `sync/pull` بلا نقطةِ قراءةٍ ثانية. ولذلك لا `GET` في `CatalogController` ولا في `CurriculumAdminController` أصلاً |
/// | **الكتابة بـREST** | بنيةٌ يُبنى عليها لا حدثٌ يُسجَّل: الجلسةُ والتسجيلُ والتفقّد تُعلَّق كلُّها على `course_circles`، ولو صُفَّت أوف-لاين لَصفَّ الجهازُ فوقها عشراتِ العمليات ثم رُفض أصلُها فسقط ما فوقه ([CHECKPOINT-PHASE-6.2.MD §4](../../../../../docs/CHECKPOINT-PHASE-6.2.MD)) |
///
/// **وأثرُ الكتابة لا يظهر فوراً.** الصفُّ يُكتب على الخادم ويعود في الدورة
/// التالية، فالشاشةُ تطلب مزامنةً بعد كل كتابة بدل أن تكتب في drift بيدها —
/// «الديسكتوب لا يصير مصدرَ الحقيقة»
/// ([APPS-FEATURES.md §4.3](../../../../../docs/APPS-FEATURES.md)).
class CatalogRepository {
  CatalogRepository({required AppDatabase db, required ApiClient apiClient})
      : _db = db,
        _api = apiClient;

  final AppDatabase _db;

  final ApiClient _api;

  // ---------------------------------------------------------------- قراءة

  Future<List<CourseView>> loadCourses() async {
    final courses = await (_db.select(_db.courses)
          ..orderBy([
            (t) => OrderingTerm(expression: t.startsOn, mode: OrderingMode.desc),
          ]))
        .get();

    final shifts = await _db.select(_db.shifts).get();
    final courseCircles = await _db.select(_db.courseCircles).get();

    return [
      for (final course in courses)
        CourseView(
          uuid: course.uuid,
          name: course.name,
          startsOn: course.startsOn,
          endsOn: course.endsOn,
          status: course.status,
          isCurrent: course.isCurrent,
          shiftsCount:
              shifts.where((shift) => shift.courseId == course.id).length,
          circlesCount: courseCircles
              .where((circle) => circle.courseId == course.id)
              .length,
        ),
    ];
  }

  Stream<List<CourseView>> watchCourses() => _watch(loadCourses);

  /// دواماتُ دورةٍ بعينها، أو دواماتُ الدورة الجارية حين يُترك [courseUuid].
  Future<List<ShiftView>> loadShifts([String? courseUuid]) async {
    final course = await _course(courseUuid);

    if (course == null) {
      return const [];
    }

    final shifts = await (_db.select(_db.shifts)
          ..where((t) => t.courseId.equals(course.id))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    final days = await _db.select(_db.shiftDays).get();
    final courseCircles = await _db.select(_db.courseCircles).get();

    return [
      for (final shift in shifts)
        ShiftView(
          uuid: shift.uuid,
          courseUuid: course.uuid,
          name: shift.name,
          startsAt: shift.startsAt,
          endsAt: shift.endsAt,
          weekdays: [
            for (final day in days)
              if (day.shiftId == shift.id) day.weekday,
          ]..sort(),
          isActive: shift.isActive,
          circlesCount: courseCircles
              .where((circle) => circle.shiftId == shift.id)
              .length,
        ),
    ];
  }

  Stream<List<ShiftView>> watchShifts([String? courseUuid]) =>
      _watch(() => loadShifts(courseUuid));

  /// هويّاتُ الحلقات في المعهد، ومعها الدواماتُ التي شُغّلت فيها في الدورة
  /// الجارية — فالحلقةُ ثابتةٌ عبر الدورات وتشغيلُها صفٌّ آخر.
  Future<List<CircleDefinitionView>> loadCircleDefinitions() async {
    final circles = await (_db.select(_db.circles)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    final course = await _course(null);

    final running = course == null
        ? const <int, List<String>>{}
        : await _runningShiftNames(course.id);

    return [
      for (final circle in circles)
        CircleDefinitionView(
          uuid: circle.uuid,
          name: circle.name,
          isActive: circle.isActive,
          level: circle.level,
          color: circle.color,
          runningIn: running[circle.id] ?? const [],
        ),
    ];
  }

  Stream<List<CircleDefinitionView>> watchCircleDefinitions() =>
      _watch(loadCircleDefinitions);

  /// المناهجُ ببنودها — العامّةُ ومناهجُ المعهد معاً.
  Future<List<CurriculumView>> loadCurricula() async {
    final curricula = await (_db.select(_db.curricula)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    final items = await (_db.select(_db.curriculumItems)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    return [
      for (final curriculum in curricula)
        CurriculumView(
          uuid: curriculum.uuid,
          name: curriculum.name,
          type: curriculum.type,
          isGlobal: curriculum.instituteId == null,
          isActive: curriculum.isActive,
          description: curriculum.description,
          items: [
            for (final item in items)
              if (item.curriculumId == curriculum.id)
                CurriculumItemView(
                  uuid: item.uuid,
                  name: item.name,
                  code: item.code,
                  sortOrder: item.sortOrder,
                  count: _countOf(item.meta, curriculum.type),
                ),
          ],
        ),
    ];
  }

  Stream<List<CurriculumView>> watchCurricula() => _watch(loadCurricula);

  // ---------------------------------------------------------------- كتابة

  Future<void> saveCourse({
    String? uuid,
    required String name,
    required DateTime startsOn,
    DateTime? endsOn,
    required String status,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'starts_on': _isoDate(startsOn),
      'ends_on': endsOn == null ? null : _isoDate(endsOn),
      'status': status,
      if (notes != null) 'notes': notes,
    };

    if (uuid == null) {
      await _api.createCourse(body);
    } else {
      await _api.updateCourse(uuid, body);
    }
  }

  Future<void> activateCourse(String uuid) => _api.activateCourse(uuid);

  Future<void> saveShift({
    String? uuid,
    String? courseUuid,
    required String name,
    required String startsAt,
    required String endsAt,
    required List<int> weekdays,
    bool isActive = true,
  }) async {
    final body = <String, dynamic>{
      if (courseUuid != null) 'course_uuid': courseUuid,
      'name': name,
      'starts_at': _hhmm(startsAt),
      'ends_at': _hhmm(endsAt),
      'weekdays': weekdays,
      'is_active': isActive,
    };

    if (uuid == null) {
      await _api.createShift(body);
    } else {
      await _api.updateShift(uuid, body);
    }
  }

  Future<void> saveCircle({
    String? uuid,
    required String name,
    String? level,
    String? color,
    bool isActive = true,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (level != null) 'level': level,
      if (color != null) 'color': color,
      'is_active': isActive,
    };

    if (uuid == null) {
      await _api.createCircle(body);
    } else {
      await _api.updateCircle(uuid, body);
    }
  }

  /// تشغيلُ حلقةٍ في دورةٍ ودوام — الصفُّ الذي تُعلَّق عليه الجلساتُ والتسجيلات.
  Future<void> runCircle({
    required String circleUuid,
    required String shiftUuid,
    String? courseUuid,
    String? room,
    int? capacity,
  }) {
    return _api.runCircleInCourse(circleUuid, {
      if (courseUuid != null) 'course_uuid': courseUuid,
      'shift_uuid': shiftUuid,
      if (room != null && room.trim().isNotEmpty) 'room': room.trim(),
      if (capacity != null) 'capacity': capacity,
    });
  }

  Future<void> saveCurriculum({
    String? uuid,
    required String name,
    required String type,
    String? description,
    bool isActive = true,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'type': type,
      if (description != null) 'description': description,
      'is_active': isActive,
    };

    if (uuid == null) {
      await _api.createCurriculum(body);
    } else {
      await _api.updateCurriculum(uuid, body);
    }
  }

  Future<void> saveCurriculumItem({
    String? uuid,
    required String curriculumUuid,
    required String name,
    String? code,
    int? count,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      if (count != null) 'count': count,
    };

    if (uuid == null) {
      await _api.createCurriculumItem(curriculumUuid, body);
    } else {
      await _api.updateCurriculumItem(uuid, body);
    }
  }

  Future<void> deleteCurriculumItem(String uuid) =>
      _api.deleteCurriculumItem(uuid);

  // ------------------------------------------------------------ الداخلية

  /// دورةٌ بمعرّفها، أو الجاريةُ حين لا يُذكر — نظيرُ `courseOrCurrent` خادمياً.
  Future<CourseRow?> _course(String? uuid) {
    final query = _db.select(_db.courses)
      ..where((t) => uuid == null ? t.isCurrent.equals(true) : t.uuid.equals(uuid))
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// أسماءُ الدوامات التي شُغّلت فيها كلُّ حلقةٍ ضمن هذه الدورة.
  Future<Map<int, List<String>>> _runningShiftNames(int courseId) async {
    final rows = await (_db.select(_db.courseCircles).join([
      innerJoin(
        _db.shifts,
        _db.shifts.id.equalsExp(_db.courseCircles.shiftId),
      ),
    ])
          ..where(_db.courseCircles.courseId.equals(courseId)))
        .get();

    final result = <int, List<String>>{};

    for (final row in rows) {
      result
          .putIfAbsent(row.readTable(_db.courseCircles).circleId, () => [])
          .add(row.readTable(_db.shifts).name);
    }

    return result;
  }

  /// عدّادُ البند من `meta` — مفتاحُه يتبع نوعَ المنهج، ولا عدّادَ لسواهما.
  static int? _countOf(String? meta, String type) {
    final key = switch (type) {
      'hadith' => 'hadiths',
      'mutun' => 'abyat',
      _ => null,
    };

    if (key == null || meta == null || meta.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(meta);

      if (decoded is Map && decoded[key] != null) {
        return int.tryParse(decoded[key].toString());
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();

    await for (final _ in _db.tableUpdates()) {
      yield await read();
    }
  }

  /// `08:00:00` ⇒ `08:00` — الخادم يتحقّق بـ`date_format:H:i`.
  static String _hhmm(String value) => value.split(':').take(2).join(':');

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
