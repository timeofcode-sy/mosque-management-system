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
import 'tables/enrollments_table.dart';
import 'tables/institutes_table.dart';
import 'tables/local_attendances_table.dart';
import 'tables/local_points_table.dart';
import 'tables/local_recitations_table.dart';
import 'tables/local_sessions_table.dart';
import 'tables/pending_operations_table.dart';
import 'tables/recitations_table.dart';
import 'tables/shifts_table.dart';
import 'tables/student_points_table.dart';
import 'tables/students_table.dart';
import 'tables/sync_state_table.dart';
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
  CourseCircles,
  Teachers,
  CourseCircleTeachers,
  Students,
  Enrollments,
  AttendanceSessions,
  Attendances,
  Recitations,
  AbsenceExcusesTable,
  StudentPoints,
  LocalSessions,
  LocalAttendances,
  LocalRecitations,
  LocalPoints,
  PendingOperations,
  SyncState,
  AppState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

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
