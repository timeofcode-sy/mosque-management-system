import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/absence_excuses_table.dart';
import 'tables/attendance_sessions_table.dart';
import 'tables/attendances_table.dart';
import 'tables/course_circles_table.dart';
import 'tables/courses_table.dart';
import 'tables/institutes_table.dart';
import 'tables/pending_operations_table.dart';
import 'tables/recitations_table.dart';
import 'tables/student_points_table.dart';
import 'tables/students_table.dart';
import 'tables/sync_state_table.dart';

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
  CourseCircles,
  Students,
  AttendanceSessions,
  Attendances,
  Recitations,
  AbsenceExcusesTable,
  StudentPoints,
  PendingOperations,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

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
