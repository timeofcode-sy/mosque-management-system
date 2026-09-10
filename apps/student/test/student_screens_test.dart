import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_student/src/di/app_scope.dart';
import 'package:mousqe_student/src/screens/announcements_screen.dart';
import 'package:mousqe_student/src/screens/attendance_screen.dart';
import 'package:mousqe_student/src/screens/home_screen.dart';
import 'package:mousqe_student/src/screens/progress_screen.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:retrofit/retrofit.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MemoryTokenStore implements TokenStore {
  String? token = '12|secret';

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String> deviceUuid() async => 'device-1';
}

HttpResponse<dynamic> _response(Object? data) =>
    HttpResponse(data, Response(requestOptions: RequestOptions(), data: data));

DioException _offline() => DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'no route to host',
    );

Map<String, dynamic> _standing({int? rank = 5, double? rate = 87.5, int peers = 20}) => {
      'data': {
        'circle_name': 'حلقة أبي بن كعب',
        'rank': rank,
        'peers': peers,
        'rate': rate,
        'points': 42,
      },
    };

Widget _wrap(AppDependencies dependencies, Widget home) => AppScope(
      dependencies: dependencies,
      child: MousqeApp(theme: MousqeTheme.fromHexes(), home: home),
    );

void main() {
  late AppDatabase db;
  late _MockApiClient api;
  late AppDependencies dependencies;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = _MockApiClient();
    dependencies = await AppDependencies.create(
      database: db,
      tokens: _MemoryTokenStore(),
      api: api,
    );
  });

  tearDown(() => db.close());

  group('الرئيسية', () {
    testWidgets('the rank is shown as a position out of a total', (tester) async {
      when(api.studentStanding).thenAnswer((_) async => _response(_standing()));

      await tester.pumpWidget(_wrap(dependencies, const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('ترتيبي في الحلقة: 5 من 20'), findsOneWidget);
      expect(find.text('87.5٪'), findsOneWidget);
      expect(find.text('حلقة أبي بن كعب'), findsOneWidget);
    });

    /// 🔑 قاعدةُ م.6.6 على السطح الذي يقرؤه صاحبُها.
    testWidgets('an unmeasured rank says so instead of calling him last', (tester) async {
      when(api.studentStanding)
          .thenAnswer((_) async => _response(_standing(rank: null, rate: null)));

      await tester.pumpWidget(_wrap(dependencies, const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('لم يُقَس ترتيبي بعد'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('0.0٪'), findsNothing);
    });

    testWidgets('a student in no circle is told so, not shown a rank of zero', (tester) async {
      when(api.studentStanding).thenAnswer(
        (_) async => _response({
          'data': {'circle_name': null, 'rank': null, 'peers': 0, 'rate': null, 'points': 0},
        }),
      );

      await tester.pumpWidget(_wrap(dependencies, const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('لست مسجَّلاً في حلقةٍ جارية'), findsOneWidget);
    });

    /// 🔑 القاعدةُ التي رُفعت إلى `mousqe_ui` في هذه المرحلة.
    testWidgets('a snapshot served offline announces that it is stale', (tester) async {
      when(api.studentStanding).thenAnswer((_) async => _response(_standing()));
      await tester.pumpWidget(_wrap(dependencies, const HomeScreen()));
      await tester.pumpAndSettle();

      when(api.studentStanding).thenThrow(_offline());

      await tester.pumpWidget(
        _wrap(dependencies, const HomeScreen(key: ValueKey('reopened'))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('لا اتصال'), findsOneWidget);
      expect(find.textContaining('آخر تحديث'), findsOneWidget);
    });
  });

  group('حضوري', () {
    testWidgets('a record is dated by its session, not by when it was written', (tester) async {
      when(api.studentAttendance).thenAnswer(
        (_) async => _response({
          'summary': {'present': 5, 'absent': 1, 'late': 0, 'excused': 0, 'total': 6, 'rate': 83.3},
          'trend': [
            {'date': '2026-09-07', 'rate': 100, 'sessions': 1},
            {'date': '2026-09-08', 'rate': null, 'sessions': 0},
          ],
          'recent': [
            {
              'uuid': 'att-1',
              'status': 'late',
              'late_minutes': 12,
              'note': null,
              'recorded_at': '2026-09-10T09:00:00.000000Z',
              'session_date': '2026-09-09',
            },
          ],
        }),
      );

      await tester.pumpWidget(_wrap(dependencies, const AttendanceScreen()));
      await tester.pumpAndSettle();

      // 2026-09-09 أربعاء، ويومُ الكتابة خميس.
      expect(find.textContaining('الأربعاء'), findsOneWidget);
      expect(find.textContaining('الخميس'), findsNothing);
      expect(find.text('متأخر'), findsOneWidget);
    });

    testWidgets('an empty record is explained, not left blank', (tester) async {
      when(api.studentAttendance).thenAnswer(
        (_) async => _response({
          'summary': {'present': 0, 'absent': 0, 'late': 0, 'excused': 0, 'total': 0, 'rate': null},
          'trend': <dynamic>[],
          'recent': <dynamic>[],
        }),
      );

      await tester.pumpWidget(_wrap(dependencies, const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('لا سجلَّ حضورٍ بعد'), findsOneWidget);
    });
  });

  group('حفظي', () {
    /// درسُ م.7.4: الخريطةُ الفارغة تخرج من PHP مصفوفةً، والشاشةُ تقول ذلك ولا
    /// تسقط.
    testWidgets('an empty progress map is explained, not thrown at', (tester) async {
      when(api.studentProgress).thenAnswer((_) async => _response({'data': <dynamic>[]}));

      await tester.pumpWidget(_wrap(dependencies, const ProgressScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('لم يُسجَّل تقدُّمٌ'), findsOneWidget);
    });
  });

  group('الإعلانات', () {
    testWidgets('an announcement aimed at the circle is badged as such', (tester) async {
      when(api.studentAnnouncements).thenAnswer(
        (_) async => _response({
          'data': [
            {
              'uuid': 'a1',
              'title': 'مسابقة حفظ',
              'body': 'التسجيل عند أستاذ الحلقة.',
              'scope': 'circle',
              'published_at': null,
            },
            {
              'uuid': 'a2',
              'title': 'انتظام الدوام',
              'body': 'الحضور قبل الحصّة بعشر دقائق.',
              'scope': 'all',
              'published_at': null,
            },
          ],
        }),
      );

      await tester.pumpWidget(_wrap(dependencies, const AnnouncementsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('مسابقة حفظ'), findsOneWidget);
      expect(find.text('انتظام الدوام'), findsOneWidget);
      // الشارةُ على إعلان الحلقة وحده.
      expect(find.text('لحلقتي'), findsOneWidget);
    });

    testWidgets('no announcements is a sentence, not a blank page', (tester) async {
      when(api.studentAnnouncements).thenAnswer((_) async => _response({'data': <dynamic>[]}));

      await tester.pumpWidget(_wrap(dependencies, const AnnouncementsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('لا إعلاناتٍ بعد'), findsOneWidget);
    });
  });
}
