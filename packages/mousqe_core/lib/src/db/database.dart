import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/absence_excuses_table.dart';
import 'tables/app_state_table.dart';
import 'tables/attendance_sessions_table.dart';
import 'tables/attendances_table.dart';
import 'tables/circles_table.dart';
import 'tables/course_circle_teachers_table.dart';
import 'tables/course_circles_table.dart';
import 'tables/courses_table.dart';
import 'tables/curricula_table.dart';
import 'tables/curriculum_items_table.dart';
import 'tables/custom_field_values_table.dart';
import 'tables/custom_fields_table.dart';
import 'tables/enrollments_table.dart';
import 'tables/guardian_student_table.dart';
import 'tables/guardians_table.dart';
import 'tables/institutes_table.dart';
import 'tables/local_attendances_table.dart';
import 'tables/local_points_table.dart';
import 'tables/local_recitations_table.dart';
import 'tables/local_sessions_table.dart';
import 'tables/local_teacher_attendances_table.dart';
import 'tables/pending_operations_table.dart';
import 'tables/personal_traits_table.dart';
import 'tables/recitations_table.dart';
import 'tables/shift_days_table.dart';
import 'tables/shifts_table.dart';
import 'tables/student_curriculum_progress_table.dart';
import 'tables/student_points_table.dart';
import 'tables/student_trait_table.dart';
import 'tables/students_table.dart';
import 'tables/sync_state_table.dart';
import 'tables/teacher_attendances_table.dart';
import 'tables/teachers_table.dart';

part 'database.g.dart';

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'mousqe.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [
  Institutes,
  Courses,
  Circles,
  Shifts,
  ShiftDays,
  CourseCircles,
  Teachers,
  CourseCircleTeachers,
  Students,
  Guardians,
  GuardianStudentTable,
  PersonalTraits,
  StudentTraitTable,
  Curricula,
  CurriculumItems,
  StudentCurriculumProgressTable,
  CustomFields,
  CustomFieldValues,
  Enrollments,
  AttendanceSessions,
  Attendances,
  TeacherAttendances,
  Recitations,
  AbsenceExcusesTable,
  StudentPoints,
  LocalSessions,
  LocalAttendances,
  LocalTeacherAttendances,
  LocalRecitations,
  LocalPoints,
  PendingOperations,
  SyncState,
  AppState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  /// 5 ⇒ 6 (م.6.5): **الاستمارةُ والكتالوج** — عشرةُ جداول كان `sync/pull`
  /// يُسقطها على الأرض منذ م.4 لأن لا صفَّ drift يستقبلها (`guardians` ·
  /// `guardian_student` · `traits` · `student_trait` · `curricula` ·
  /// `curriculum_items` · `student_curriculum_progress` · `custom_fields` ·
  /// `custom_field_values` · `shift_days`)، وخمسةَ عشرَ عموداً على `students`.
  ///
  /// وهي عمودٌ في حجّة المرحلة كلِّها: استمارةُ التسجيل تُكتب **أوف-لاين**، فلا
  /// يكفي أن تصل حقولُها في الحمولة — لا بدّ أن تُخزَّن، وإلا فُتحت الاستمارةُ
  /// نصفَ فارغة وحُفظت فمحت ما لم تعرضه.
  ///
  /// 4 ⇒ 5 (م.6.4): تفقّدُ الأساتذة — `teacher_attendances` المتزامن ومسودّتُه
  /// المحلية، وعمودُ `locked` على المسودّة. الجدولُ الخادمي يُبثّ في `change_log`
  /// منذ م.4 وكان `SyncPayloadApplier` **يُسقطه على الأرض** لأن لا صفَّ يستقبله؛
  /// والديسكتوبُ أوّلُ عميلٍ يتفقّد الأساتذة، فهو أوّلُ من يحتاجه.
  ///
  /// 3 ⇒ 4 (م.6.2): عمودا عزل العملية المرفوضة — `failed_reason` و`failed_at`.
  /// الخادم صار يردّ المرفوضةَ في `failed[]` بدل أن تُسقط الدفعة معها (م.6.1)،
  /// وهذا شقُّها في العميل: تُعزَل في الطابور بلا حذفٍ ولا إعادةِ إرسال، وتُعرض
  /// لصاحب الجهاز — [SYNC-PROTOCOL.md §10] البند 10.
  ///
  /// 2 ⇒ 3 (م.5.4): مسودّتا التسميع والنقاط — بهما يرى الأستاذ ما سجّله قبل أن
  /// يؤكّده الخادم، فيملك تصحيحَه وحذفَه أوف-لاين.
  ///
  /// 1 ⇒ 2 (م.5.3): الجداول الخمسة التي كان `sync/pull` يُسقطها على الأرض —
  /// `circles` و`shifts` و`teachers` و`course_circle_teachers` و`enrollments` —
  /// زائداً `app_state` للقطة `/bootstrap`، وجدولَي المسودّة المحلية، وعمودَ
  /// `last_pulled_at` في `sync_state`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(circles);
            await m.createTable(shifts);
            await m.createTable(teachers);
            await m.createTable(courseCircleTeachers);
            await m.createTable(enrollments);
            await m.createTable(appState);
            await m.createTable(localSessions);
            await m.createTable(localAttendances);
            await m.addColumn(pendingOperations, pendingOperations.sequence);
            await m.addColumn(syncState, syncState.lastPulledAt);
          }

          if (from < 3) {
            await m.createTable(localRecitations);
            await m.createTable(localPoints);
          }

          if (from < 4) {
            await m.addColumn(pendingOperations, pendingOperations.failedReason);
            await m.addColumn(pendingOperations, pendingOperations.failedAt);
          }

          if (from < 5) {
            await m.createTable(teacherAttendances);
            await m.createTable(localTeacherAttendances);
            await m.addColumn(localSessions, localSessions.locked);
          }

          if (from < 6) {
            await m.createTable(guardians);
            await m.createTable(guardianStudentTable);
            await m.createTable(personalTraits);
            await m.createTable(studentTraitTable);
            await m.createTable(curricula);
            await m.createTable(curriculumItems);
            await m.createTable(studentCurriculumProgressTable);
            await m.createTable(customFields);
            await m.createTable(customFieldValues);
            await m.createTable(shiftDays);

            for (final GeneratedColumn<Object> column in <GeneratedColumn<Object>>[
              students.registrationDate,
              students.registrationDateHijri,
              students.birthDate,
              students.birthPlace,
              students.gender,
              students.nationalId,
              students.gradeLevel,
              students.studentJob,
              students.phone,
              students.permanentAddress,
              students.currentAddress,
              students.familyMembersCount,
              students.studentHealthStatus,
              students.familyHealthStatus,
              students.notes,
            ]) {
              await m.addColumn(students, column);
            }

            // الأعمدةُ الجديدة تُملأ بالسحب لا بالهجرة: صفوفُ الطلاب المخزَّنة
            // وصلت بحمولةٍ كاملة وحُفظ منها ثُمنُها، ولا سبيل إلى استرجاع ما
            // أُهمل إلا من الخادم. فيُصفَّر المؤشّرُ ليعيد السحبَ من أوّله —
            // نفسُ ما يفعله تبديلُ المعهد (م.6.3)، وثمنُه دورةٌ واحدة.
            await customStatement('DELETE FROM sync_state');
          }
        },
      );

  /// قيمةٌ محفوظة في [AppState]، أو `null` إن لم تُكتب بعد.
  Future<String?> readAppState(String key) async {
    final row = await (select(appState)..where((t) => t.key.equals(key))).getSingleOrNull();

    return row?.value;
  }

  Future<void> writeAppState(String key, String value) {
    return into(appState).insertOnConflictUpdate(AppStateRow(key: key, value: value));
  }

  /// تُستدعى عند `403 هذا الحساب مقفل` — تمسح كل الجداول المتزامنة وتصفّر
  /// `sync_state`، فيبدأ الجهاز من الصفر عند دخولٍ جديد.
  /// [SYNC-PROTOCOL.md §8](../../../../docs/SYNC-PROTOCOL.md) البند 10.
  Future<void> clearAll() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
