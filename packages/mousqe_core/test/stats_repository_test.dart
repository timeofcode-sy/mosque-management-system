import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';

import 'support/test_institute.dart';

/// الداشبورد والتقارير — ✅ م.6.6، **محسوبةً على الجهاز** من الصفوف المتزامنة.
///
/// وما يُقاس هنا ليس «هل يجمع الأرقام؟» بل ثلاثةُ أحكامٍ يسهل أن تُخالَف بلا أن
/// يشكوَ أحد:
///
/// 1. **ما لم يُسجَّل لا يُفترض** — جلسةٌ فُتحت بلا تفقّدٍ ليست ١٠٠٪.
/// 2. **`null` ليست صفراً** — «لم تُقَس» خبرٌ غيرُ «قِيست فكانت صفراً».
/// 3. **رقمُ الجهاز يساوي رقمَ اللوحة** — نفسُ المعادلة ونفسُ قيم المعهد.
void main() {
  late AppDatabase db;
  late TestInstitute fixture;
  late StatsRepository stats;

  final today = DateTime(2026, 9, 15);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fixture = await TestInstitute.seed(db);
    stats = StatsRepository(db: db);
  });

  tearDown(() => db.close());

  group('the dashboard', () {
    test('counters read the store, and "enrolled" is the current course alone',
        () async {
      final overview = await stats.loadOverview(today: today);

      expect(overview.hasCurrentCourse, isTrue);
      expect(overview.counters.students, 3);
      expect(overview.counters.teachers, 2);
      // ثلاثُ حلقاتٍ مشغَّلة في الدورة الجارية — ومنها واحدةٌ بلا أستاذ.
      expect(overview.counters.circles, 3);
      expect(overview.counters.enrolled, 3);
    });

    test('a session opened with nobody marked is not a hundred percent',
        () async {
      // 🔑 الحكمُ الأوّل: الخادمُ يزرع صفوفَ الطلاب عند الفتح، وقبل أن تصل
      // الجهازَ يعرض `CircleRepository` حالةً **مقترحة** لكل طالب. ولو دخلت
      // الإحصاءَ لَقرأ المشرفُ ١٠٠٪ عن يومٍ لم يُتفقَّد فيه أحد.
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);

      final overview = await stats.loadOverview(today: today);

      expect(overview.todayRate, isNull);
      expect(overview.breakdown.total, 0);
    });

    test('the rate leaves the excused out of the denominator', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-2',
        sessionId: 1,
        studentId: TestInstitute.badr,
        status: 'absent',
      );
      await fixture.syncAttendance(
        uuid: 'att-3',
        sessionId: 1,
        studentId: TestInstitute.jamil,
        status: 'excused',
      );

      final overview = await stats.loadOverview(today: today);

      // حاضرٌ واحد من اثنين يُقاسان — والمأذونُ خارج المقام، وإلا عوقبت الحلقةُ
      // على إذنٍ منحته هي.
      expect(overview.todayRate, 50.0);
      expect(overview.breakdown.excused, 1);
      expect(overview.breakdown.total, 3);
    });

    test('this device\'s draft counts, and overrides the synced row under it',
        () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'absent',
      );

      // المشرفُ صحّحها «حاضر» وهو بلا شبكة — فالداشبورد يقرأ ما يقرؤه هو في
      // الشاشة التي كتب فيها قبل لحظة، لا ما يقوله الخادم بعدُ.
      await db.into(db.localAttendances).insert(
            LocalAttendancesCompanion.insert(
              courseCircleId: 1,
              sessionDate: today,
              studentId: TestInstitute.ali,
              status: 'present',
              recordedAt: DateTime(2026, 9, 15, 8, 20),
            ),
          );

      final overview = await stats.loadOverview(today: today);

      expect(overview.todayRate, 100.0);
      // ولا يُحسب الطالبُ مرّتين: المفتاحُ (حلقة، يوم، طالب) واحد.
      expect(overview.breakdown.total, 1);
    });

    test('a day with no session reads null, which is not zero', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );

      final overview = await stats.loadOverview(today: today, trendDays: 3);

      expect(overview.trend, hasLength(3));
      expect(overview.trend.last.date, today);
      expect(overview.trend.last.rate, 100.0);
      expect(overview.trend.last.sessions, 1);

      // 🔑 الحكمُ الثاني: يومٌ لم تُفتح فيه جلسةٌ ليس يوماً نسبتُه صفر — ولو
      // رُسم صفراً لَبدا المنحنى هابطاً في كل عطلة.
      expect(overview.trend.first.rate, isNull);
      expect(overview.trend.first.sessions, 0);
    });
  });

  group('the standings', () {
    setUp(() async {
      // الفرقان: حاضرٌ من حاضرَين ⇒ ١٠٠٪ · النهار: حاضرٌ من اثنين ⇒ ٥٠٪ ·
      // العصر: بلا جلسةٍ أصلاً.
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await fixture.syncSession(
        id: 2,
        uuid: 'ses-2',
        day: today,
        courseCircleId: 2,
      );

      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-2',
        sessionId: 2,
        studentId: TestInstitute.badr,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-3',
        sessionId: 2,
        studentId: TestInstitute.jamil,
        status: 'absent',
      );
    });

    test('circles rank inside their shift, best first', () async {
      final overview = await stats.loadOverview(today: today);

      final ranked = overview.standings.where((row) => row.rank != null).toList();

      expect(ranked.map((row) => row.circleName), ['حلقة الفرقان', 'حلقة النهار']);
      expect(ranked.map((row) => row.rank), [1, 2]);
      expect(ranked.first.rate, 100.0);
      expect(ranked.last.rate, 50.0);
    });

    test('a circle with no attendance row at all is not ranked zero', () async {
      final overview = await stats.loadOverview(today: today);

      final idle =
          overview.standings.firstWhere((row) => row.circleName == 'حلقة العصر');

      // لو رُتّبت صفراً لَبدت حلقةٌ لم يفتح أحدٌ جلستَها أسوأَ من حلقةٍ غاب
      // طلابُها كلُّهم — وهما ليسا خبراً واحداً.
      expect(idle.rate, isNull);
      expect(idle.rank, isNull);
      expect(idle.sessionsCount, 0);
    });

    test('a tie takes the same rank, and the order holds between two reads',
        () async {
      // النهار يصير ١٠٠٪ أيضاً: تعادلٌ يأخذ الرتبةَ نفسَها.
      await (db.update(db.attendances)
            ..where((t) => t.uuid.equals('att-3')))
          .write(const AttendancesCompanion(status: Value('present')));

      final first = await stats.loadOverview(today: today);
      final second = await stats.loadOverview(today: today);

      expect(first.standings.map((row) => row.rank), [1, 1, null]);
      expect(
        first.standings.map((row) => row.circleName),
        second.standings.map((row) => row.circleName),
      );
    });
  });

  group('the daily report', () {
    test('names are listed under their status and sorted', () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.jamil,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-2',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-3',
        sessionId: 1,
        studentId: TestInstitute.badr,
        status: 'absent',
      );

      final report = await stats.loadDailyReport(
        courseCircleId: 1,
        date: today,
      );

      expect(report, isNotNull);
      expect(report!.exists, isTrue);
      expect(report.circleName, 'حلقة الفرقان');
      expect(report.room, 'قاعة 2');
      expect(report.teachersLabel, contains('أحمد'));
      expect(
        report.names[AttendanceStatus.present],
        ['جميل راشد الدمشقي', 'علي حسن الشامي'],
      );
      expect(report.names[AttendanceStatus.absent], ['بدر سالم الحلبي']);
      expect(report.rate, closeTo(66.7, 0.05));
      expect(report.rank, 1);
    });

    test('a circle whose session was never opened still reports — as "unopened"',
        () async {
      final report = await stats.loadDailyReport(
        courseCircleId: 1,
        date: today,
      );

      // تقريرٌ صحيحٌ يقول «لم تُفتح» — وهو خبرٌ يعني صاحبَه، لا فشلٌ يُخفى.
      expect(report, isNotNull);
      expect(report!.exists, isFalse);
      expect(report.sessionStatus, isNull);
      expect(report.rate, isNull);
      expect(report.breakdown.total, 0);
    });

    test('a lock this device wrote offline shows locked, not the stale status',
        () async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await db.into(db.localSessions).insert(
            LocalSessionsCompanion.insert(
              courseCircleId: 1,
              sessionDate: today,
              uuid: 'ses-1',
              completed: const Value(true),
              locked: const Value(true),
            ),
          );

      final report = await stats.loadDailyReport(
        courseCircleId: 1,
        date: today,
      );

      expect(report!.sessionStatus, 'locked');
    });

    test('the cumulative rate runs to the report date, not to the present day',
        () async {
      // أمسِ: حاضرٌ واحد. واليوم: غائبٌ واحد. فتقريرُ أمسِ يجب أن يقرأ ١٠٠٪
      // مهما طُبع بعده — وإلا تغيّر تقريرٌ مطبوع بعد أن طُبع.
      await fixture.syncSession(
        id: 1,
        uuid: 'ses-1',
        day: today.subtract(const Duration(days: 1)),
      );
      await fixture.syncSession(id: 2, uuid: 'ses-2', day: today);

      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-2',
        sessionId: 2,
        studentId: TestInstitute.ali,
        status: 'absent',
      );

      final yesterday = await stats.loadDailyReport(
        courseCircleId: 1,
        date: today.subtract(const Duration(days: 1)),
      );

      expect(yesterday!.cumulativeRate, 100.0);
      expect(yesterday.sessionsCount, 1);

      final now = await stats.loadDailyReport(courseCircleId: 1, date: today);

      expect(now!.cumulativeRate, 50.0);
      expect(now.sessionsCount, 2);
    });
  });

  group('the points report', () {
    setUp(() async {
      await fixture.syncSession(id: 1, uuid: 'ses-1', day: today);
      await fixture.syncAttendance(
        uuid: 'att-1',
        sessionId: 1,
        studentId: TestInstitute.ali,
        status: 'present',
      );
      await fixture.syncAttendance(
        uuid: 'att-2',
        sessionId: 1,
        studentId: TestInstitute.badr,
        status: 'late',
      );
    });

    test('attendance points use the institute\'s values, not the defaults',
        () async {
      // 🔑 الحكمُ الثالث: `institutes.settings` جدولٌ لا يُزامَن، فقيمُه تصل في
      // `/bootstrap` وحده. ولولا حملُها لَطبع الجهازُ رقماً يخالف رقمَ اللوحة في
      // كل معهدٍ عدّل نقاطَه — **بلا خطأ يُرمى**.
      final report = await stats.loadPointsReport(
        courseCircleId: 1,
        from: today,
        to: today,
        points: const PointsSettings(presentPoints: 7, latePoints: 3),
      );

      final ali = report!.rows.firstWhere((row) => row.studentName.startsWith('علي'));
      final badr = report.rows.firstWhere((row) => row.studentName.startsWith('بدر'));

      expect(ali.attendance, 7);
      expect(badr.attendance, 3);

      final byDefault = await stats.loadPointsReport(
        courseCircleId: 1,
        from: today,
        to: today,
      );

      expect(
        byDefault!.rows.firstWhere((row) => row.studentName.startsWith('علي')).attendance,
        2,
      );
    });

    test('recitation points come frozen from the server, not recomputed here',
        () async {
      await fixture.syncRecitation(
        uuid: 'rec-1',
        studentId: TestInstitute.ali,
        sessionId: 1,
        points: 12.5,
      );

      final report = await stats.loadPointsReport(
        courseCircleId: 1,
        from: today,
        to: today,
      );

      final ali = report!.rows.firstWhere((row) => row.studentName.startsWith('علي'));

      // السجلُّ بلا بندِ منهجٍ يُحسب قرآناً — فالتسميع في الجلسة قرآنيٌّ بطبعه.
      expect(ali.quran, 12.5);
      expect(ali.total, 14.5);
    });

    test('rows rank by total, and everyone enrolled appears even at zero',
        () async {
      final report = await stats.loadPointsReport(
        courseCircleId: 1,
        from: today,
        to: today,
      );

      expect(report!.rows, hasLength(3));
      expect(report.rows.first.rank, 1);
      expect(report.rows.first.studentName, startsWith('علي'));

      // جميلٌ لم يُسجَّل له شيء — يظهر بصفرٍ لا يُحذف من الكشف: من يقرأ الترتيب
      // يريد أن يعرف من في الذيل أيضاً.
      expect(report.rows.last.total, 0);
      expect(report.rows.last.rank, 3);
      // حاضرٌ (٢) ومتأخّرٌ (١) وصفرٌ — بافتراضيّات النقاط.
      expect(report.total, 3.0);
    });
  });

  group('the local backup', () {
    test('VACUUM INTO writes a snapshot that opens on its own', () async {
      final directory = Directory.systemTemp.createTempSync('mousqe-backup');

      addTearDown(() => directory.deleteSync(recursive: true));

      final file = await DatabaseBackup.write(
        db,
        directory: directory,
        at: DateTime(2026, 9, 15, 14, 30),
      );

      expect(file.existsSync(), isTrue);
      expect(file.path, endsWith('mousqe-2026-09-15-1430.mousqe-backup.sqlite'));

      // اللقطةُ تُفتح وحدها وفيها ما كان في الأصل — وهي كلُّ الفرق بين نسخةٍ
      // احتياطية ونسخةٍ يظنّها صاحبُها موجودة.
      final restored = AppDatabase(NativeDatabase(file));

      addTearDown(restored.close);

      expect(await restored.select(restored.students).get(), hasLength(3));
    });

    test('backups list newest first and ignore anything else in the folder',
        () async {
      final directory = Directory.systemTemp.createTempSync('mousqe-backup');

      addTearDown(() => directory.deleteSync(recursive: true));

      final older = await DatabaseBackup.write(
        db,
        directory: directory,
        at: DateTime(2026, 9, 14, 9),
      );
      final newer = await DatabaseBackup.write(
        db,
        directory: directory,
        at: DateTime(2026, 9, 15, 9),
      );

      File('${directory.path}/ملاحظات.txt').writeAsStringSync('ليست نسخة');

      final files = await DatabaseBackup.list(directory);

      expect(files.map((file) => file.path), [newer.path, older.path]);
    });
  });
}
