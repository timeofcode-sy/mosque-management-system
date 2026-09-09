import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../sync/sync_engine.dart';
import 'admin_views.dart';

/// الإدارةُ اليومية: الطلابُ والتسجيلُ والنقلُ ومراجعةُ الأعذار — ✅ م.6.5.
///
/// **كلُّها أوف-لاين**، وهذا هو ما يفصلها عن [CatalogRepository] المجاور: القاعدةُ
/// المُعلَنة في [PHASE-6-STAGES.MD §3.1](../../../../../docs/PHASE-6-STAGES.MD)
/// تقول إن ما يُكتب في المسجد بلا شبكة يمرّ بالطابور، وما هو متّصلٌ بطبعه REST.
/// وهذه الأربعةُ يكتبها المشرف وهو واقفٌ عند باب الحلقة: يسجّل طالباً وصل مع
/// أبيه، ويسجّله في حلقةٍ في نفس اللحظة، ويقبل إذناً ناوله إياه وليٌّ في يده.
///
/// **والقراءةُ من drift** كما في [CircleRepository]: ما يظهر هنا وصل في
/// `sync/pull`، فالكشفُ يُفتح والشبكةُ مقطوعة.
class StudentRepository {
  StudentRepository({required AppDatabase db, required SyncEngine syncEngine})
      : _db = db,
        _syncEngine = syncEngine;

  final AppDatabase _db;

  final SyncEngine _syncEngine;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------- الطلاب

  /// كشفُ طلاب المعهد، ومعه اسمُ حلقة كلٍّ في الدورة الجارية.
  Future<List<StudentListEntry>> loadStudents() async {
    final students = await (_db.select(_db.students)
          ..orderBy([
            (t) => OrderingTerm(expression: t.firstName),
            (t) => OrderingTerm(expression: t.familyName),
          ]))
        .get();

    final circles = await _currentCircleNames();
    final pending = await _pendingStudentUuids();

    return [
      for (final student in students)
        StudentListEntry(
          id: student.id,
          uuid: student.uuid,
          fullName: _fullName(student),
          status: student.status,
          registrationNo: student.registrationNo,
          phone: student.phone,
          circleName: circles[student.id],
          pending: pending.contains(student.uuid),
        ),
    ];
  }

  Stream<List<StudentListEntry>> watchStudents() => _watch(loadStudents);

  /// استمارةُ طالبٍ قائم، مجموعةً من ستة جداول — أو `null` لمعرّفٍ لا صفَّ له.
  Future<StudentForm?> loadStudentForm(String uuid) async {
    final student = await (_db.select(_db.students)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (student == null) {
      return null;
    }

    return StudentForm(
      uuid: student.uuid,
      registrationNo: student.registrationNo,
      registrationDate: student.registrationDate,
      registrationDateHijri: student.registrationDateHijri,
      status: student.status,
      firstName: student.firstName,
      fatherName: student.fatherName,
      familyName: student.familyName,
      birthDate: student.birthDate,
      birthPlace: student.birthPlace,
      gender: student.gender,
      nationalId: student.nationalId,
      gradeLevel: student.gradeLevel,
      studentJob: student.studentJob,
      phone: student.phone,
      permanentAddress: student.permanentAddress,
      currentAddress: student.currentAddress,
      familyMembersCount: student.familyMembersCount,
      studentHealthStatus: student.studentHealthStatus,
      familyHealthStatus: student.familyHealthStatus,
      notes: student.notes,
      father: await _guardian(student.id, 'father'),
      mother: await _guardian(student.id, 'mother'),
      traitUuids: await _traitUuidsOf(student.id),
      memorizedItemUuids: await _memorizedItemUuidsOf(student.id),
      customFields: await _customFieldValuesOf(student.id),
      courseCircleUuid: await _currentCircleUuid(student.id),
    );
  }

  /// حفظُ الاستمارة — نوعُ `student.save` في الطابور، ويعود بـ`uuid` الطالب.
  ///
  /// **ومعرّفُ الطالب يولّده العميل** (م.5.4)، فيصفّ الجهازُ تسجيلَ الطالب ثم
  /// تسجيلَه في حلقةٍ **في نفس الدفعة** بلا انتظار معرّفٍ من الخادم. وهذا هو
  /// الفرقُ بين استمارةٍ تعمل أوف-لاين وأخرى تحتاج شبكةً في منتصفها.
  Future<String> saveStudent(StudentForm form) async {
    final uuid = form.uuid ?? _uuid.v4();

    await _syncEngine.enqueue('student.save', {
      'uuid': uuid,
      'student': _studentAttributes(form),
      'guardians': {
        if (!form.father.isEmpty) 'father': form.father.toPayload(),
        if (!form.mother.isEmpty) 'mother': form.mother.toPayload(),
      },
      'trait_uuids': form.traitUuids.toList(),
      'memorized_item_uuids': form.memorizedItemUuids.toList(),
      'custom_fields': form.customFields,
      // الحلقةُ في نفس العملية لا في ثانيةٍ بعدها: `SaveStudentRegistration`
      // يسجّل الطالبَ فيها داخل معاملته، فلا يبقى طالبٌ محفوظٌ بلا حلقةٍ لو
      // رُفضت العمليةُ الثانية وحدها.
      if (form.courseCircleUuid != null)
        'course_circle_uuid': form.courseCircleUuid,
    });

    return uuid;
  }

  // ------------------------------------------------------ التسجيل والنقل

  /// تسجيلُ طالبٍ في حلقةٍ ضمن الدورة الجارية — `enrollment.save`.
  Future<void> enrollStudent({
    required String studentUuid,
    required String courseCircleUuid,
    DateTime? enrolledOn,
  }) {
    return _syncEngine.enqueue('enrollment.save', {
      'student_uuid': studentUuid,
      'course_circle_uuid': courseCircleUuid,
      if (enrolledOn != null) 'enrolled_on': _isoDate(enrolledOn),
    });
  }

  /// نقلُ طالبٍ بين حلقتين — `student.transfer`.
  ///
  /// والتسجيلُ القديم **يُغلق «منقولاً» ولا يُحذف** (`TransferStudent`)، فيبقى
  /// حضورُه في حلقته الأولى مقروءاً — وهو الفرقُ بين نقلٍ وحذفٍ ثم تسجيل.
  Future<void> transferStudent({
    required String studentUuid,
    required String toCourseCircleUuid,
    String? reason,
    DateTime? transferredOn,
  }) {
    return _syncEngine.enqueue('student.transfer', {
      'student_uuid': studentUuid,
      'to_course_circle_uuid': toCourseCircleUuid,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (transferredOn != null) 'transferred_on': _isoDate(transferredOn),
    });
  }

  // ------------------------------------------------------------- الأعذار

  /// أعذارُ الغياب الواردة، الأحدثُ أوّلاً.
  Future<List<ExcuseView>> loadExcuses() async {
    final rows = await (_db.select(_db.absenceExcusesTable).join([
      innerJoin(
        _db.students,
        _db.students.id.equalsExp(_db.absenceExcusesTable.studentId),
      ),
    ])
          ..orderBy([
            OrderingTerm(
              expression: _db.absenceExcusesTable.fromDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();

    final pending = await _pendingExcuseDecisions();

    return [
      for (final row in rows)
        () {
          final excuse = row.readTable(_db.absenceExcusesTable);
          final decision = pending[excuse.uuid];

          return ExcuseView(
            uuid: excuse.uuid,
            studentName: _fullName(row.readTable(_db.students)),
            fromDate: excuse.fromDate,
            toDate: excuse.toDate,
            reason: excuse.reason,
            // الحكمُ المصفوف يُعرض فوراً وإن لم يصل الخادمَ بعد — وإلا بدا
            // للمشرف أن ضغطتَه ضاعت فأعادها، فصُفَّ حكمان على إذنٍ واحد.
            status: decision ?? excuse.status,
            reviewNote: excuse.reviewNote,
            pending: decision != null,
          );
        }(),
    ];
  }

  Stream<List<ExcuseView>> watchExcuses() => _watch(loadExcuses);

  /// البتُّ في إذن غياب — `excuse.review`.
  ///
  /// وقبولُ الإذن يحوّل غيابَ الجلسات **غيرِ المقفلة** إلى «مأذون» داخل الفعل
  /// نفسِه على الخادم (`ReviewAbsenceExcuse`)، فلا يصحّح المشرفُ جلساتٍ بيده.
  Future<void> reviewExcuse({
    required String excuseUuid,
    required bool approve,
    String? note,
  }) {
    return _syncEngine.enqueue('excuse.review', {
      'excuse_uuid': excuseUuid,
      'decision': approve ? 'approved' : 'rejected',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  // ------------------------------------------------- كتالوجُ الاستمارة

  /// الصفاتُ الشخصية — العامّةُ ومعهدُ صاحب الجهاز معاً.
  Future<List<TraitOption>> loadTraits() async {
    final rows = await (_db.select(_db.personalTraits)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    return [
      for (final row in rows)
        TraitOption(uuid: row.uuid, name: row.name, polarity: row.polarity),
    ];
  }

  /// واصفاتُ الطالب المخصّصة — تُقرأ صفوفاً وتُرسَم حقولاً.
  Future<List<CustomFieldView>> loadStudentCustomFields() async {
    final rows = await (_db.select(_db.customFields)
          ..where((t) => t.entity.equals('student') & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    return [
      for (final row in rows)
        CustomFieldView(
          uuid: row.uuid,
          label: row.label,
          type: row.type,
          isRequired: row.isRequired,
          group: row.group,
          options: CustomFieldView.parseOptions(row.options),
        ),
    ];
  }

  // ------------------------------------------------------------ الداخلية

  /// أعمدةُ `students` وحدها — والقائمةُ بيضاءُ **هنا كما على الخادم**
  /// (`SyncPush::STUDENT_ATTRIBUTES`): حمولةٌ تحمل ما ليس عموداً لا تُطبَّق، فلا
  /// معنى لإرسالها.
  static Map<String, dynamic> _studentAttributes(StudentForm form) {
    return {
      'registration_no': form.registrationNo,
      'registration_date': _isoDateOrNull(form.registrationDate),
      'registration_date_hijri': form.registrationDateHijri,
      'status': form.status,
      'first_name': form.firstName,
      'father_name': form.fatherName,
      'family_name': form.familyName,
      'birth_date': _isoDateOrNull(form.birthDate),
      'birth_place': form.birthPlace,
      'gender': form.gender,
      'national_id': form.nationalId,
      'grade_level': form.gradeLevel,
      'student_job': form.studentJob,
      'phone': form.phone,
      'permanent_address': form.permanentAddress,
      'current_address': form.currentAddress,
      'family_members_count': form.familyMembersCount,
      'student_health_status': form.studentHealthStatus,
      'family_health_status': form.familyHealthStatus,
      'notes': form.notes,
    };
  }

  Future<GuardianDraft> _guardian(int studentId, String relation) async {
    final row = await (_db.select(_db.guardianStudentTable).join([
      innerJoin(
        _db.guardians,
        _db.guardians.id.equalsExp(_db.guardianStudentTable.guardianId),
      ),
    ])
          ..where(
            _db.guardianStudentTable.studentId.equals(studentId) &
                _db.guardianStudentTable.relation.equals(relation),
          ))
        .getSingleOrNull();

    if (row == null) {
      return const GuardianDraft();
    }

    final guardian = row.readTable(_db.guardians);

    return GuardianDraft(
      fullName: guardian.fullName,
      occupation: guardian.occupation,
      phone: guardian.phone,
    );
  }

  Future<Set<String>> _traitUuidsOf(int studentId) async {
    final rows = await (_db.select(_db.studentTraitTable).join([
      innerJoin(
        _db.personalTraits,
        _db.personalTraits.id.equalsExp(_db.studentTraitTable.traitId),
      ),
    ])
          ..where(_db.studentTraitTable.studentId.equals(studentId)))
        .get();

    return {for (final row in rows) row.readTable(_db.personalTraits).uuid};
  }

  /// «محفوظاتُ الطالب» = صفُّ تقدّمٍ حالتُه `memorized` أو `mastered`. وما عداهما
  /// صفٌّ باقٍ بحالة `not_started` — لا غيابُ صفّ.
  Future<Set<String>> _memorizedItemUuidsOf(int studentId) async {
    final rows = await (_db.select(_db.studentCurriculumProgressTable).join([
      innerJoin(
        _db.curriculumItems,
        _db.curriculumItems.id
            .equalsExp(_db.studentCurriculumProgressTable.curriculumItemId),
      ),
    ])
          ..where(
            _db.studentCurriculumProgressTable.studentId.equals(studentId) &
                _db.studentCurriculumProgressTable.status
                    .isIn(['memorized', 'mastered']),
          ))
        .get();

    return {for (final row in rows) row.readTable(_db.curriculumItems).uuid};
  }

  Future<Map<String, String>> _customFieldValuesOf(int studentId) async {
    final rows = await (_db.select(_db.customFieldValues).join([
      innerJoin(
        _db.customFields,
        _db.customFields.id.equalsExp(_db.customFieldValues.customFieldId),
      ),
    ])
          ..where(
            _db.customFieldValues.entityId.equals(studentId) &
                _db.customFieldValues.entityType.like('%Student'),
          ))
        .get();

    return {
      for (final row in rows)
        row.readTable(_db.customFields).uuid:
            _plainValue(row.readTable(_db.customFieldValues).value),
    };
  }

  /// قيمةُ الواصفة تصل نصَّ JSON (`"نصّ"` أو `12` أو `true`) — والمعروضُ في الحقل
  /// ما بداخلها لا ترميزُها.
  static String _plainValue(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }

    try {
      final decoded = jsonDecode(raw);

      return decoded == null ? '' : decoded.toString();
    } on FormatException {
      return raw;
    }
  }

  /// اسمُ حلقة كل طالبٍ في الدورة الجارية — تسجيلٌ واحد فعّال لكل طالب.
  Future<Map<int, String>> _currentCircleNames() async {
    final rows = await (_db.select(_db.enrollments).join([
      innerJoin(
        _db.courseCircles,
        _db.courseCircles.id.equalsExp(_db.enrollments.courseCircleId),
      ),
      innerJoin(
        _db.circles,
        _db.circles.id.equalsExp(_db.courseCircles.circleId),
      ),
      innerJoin(
        _db.courses,
        _db.courses.id.equalsExp(_db.courseCircles.courseId),
      ),
    ])
          ..where(
            _db.enrollments.status.equals('active') &
                _db.courses.isCurrent.equals(true),
          ))
        .get();

    return {
      for (final row in rows)
        row.readTable(_db.enrollments).studentId:
            row.readTable(_db.circles).name,
    };
  }

  Future<String?> _currentCircleUuid(int studentId) async {
    final row = await (_db.select(_db.enrollments).join([
      innerJoin(
        _db.courseCircles,
        _db.courseCircles.id.equalsExp(_db.enrollments.courseCircleId),
      ),
      innerJoin(
        _db.courses,
        _db.courses.id.equalsExp(_db.courseCircles.courseId),
      ),
    ])
          ..where(
            _db.enrollments.studentId.equals(studentId) &
                _db.enrollments.status.equals('active') &
                _db.courses.isCurrent.equals(true),
          ))
        .getSingleOrNull();

    return row?.readTable(_db.courseCircles).uuid;
  }

  /// معرّفاتُ الطلاب المكتوبين على هذا الجهاز ولم تصل عملياتُهم الخادمَ.
  ///
  /// وتُقرأ من الطابور لا من جدولِ مسوّدةٍ محلي — على خلاف التفقّد والتسميع
  /// (م.5.4). والسبب أن الاستمارة **تُحفظ مرّةً وتُقرأ من الخادم بعدها**، ولا
  /// تُعاد قراءتُها في الشاشة قبل أن تصل؛ فجدولُ مسوّدةٍ كامل لصفٍّ ذي عشرين
  /// عموداً وستّة جداولَ فرعية كان يضاعف المخطط ليخدم دقائقَ الانتظار.
  Future<Set<String>> _pendingStudentUuids() async {
    final rows = await (_db.select(_db.pendingOperations)
          ..where((t) => t.type.equals('student.save')))
        .get();

    return {
      for (final row in rows)
        if (_payloadOf(row.payload)['uuid'] case final String uuid) uuid,
    };
  }

  /// قراراتُ الأعذار المصفوفة — مفتاحُها `uuid` الإذن وقيمتُها القرار.
  Future<Map<String, String>> _pendingExcuseDecisions() async {
    final rows = await (_db.select(_db.pendingOperations)
          ..where((t) => t.type.equals('excuse.review'))
          ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .get();

    return {
      for (final row in rows)
        if (_payloadOf(row.payload) case {
          'excuse_uuid': final String uuid,
          'decision': final String decision,
        })
          uuid: decision,
    };
  }

  static Map<String, dynamic> _payloadOf(String raw) {
    try {
      final decoded = jsonDecode(raw);

      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  /// نفسُ [CircleRepository._watch]: التغييرُ إشارة، والقراءةُ كاملةٌ بعده.
  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();

    await for (final _ in _db.tableUpdates()) {
      yield await read();
    }
  }

  static String _fullName(StudentRow student) =>
      [student.firstName, student.fatherName, student.familyName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ');

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String? _isoDateOrNull(DateTime? value) =>
      value == null ? null : _isoDate(value);
}
