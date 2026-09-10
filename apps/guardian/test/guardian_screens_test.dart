import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_guardian/src/di/app_scope.dart';
import 'package:mousqe_guardian/src/screens/child_screen.dart';
import 'package:mousqe_guardian/src/screens/children_screen.dart';
import 'package:mousqe_guardian/src/screens/excuses_screen.dart';
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

Map<String, dynamic> _children() => {
      'data': [
        {
          'uuid': 'std-1',
          'registration_no': '1042',
          'full_name': 'محمد بن خالد',
          'photo_path': null,
          'status': 'active',
        },
      ],
    };

/// طالبٌ مواظب: يومان تفقُّدٍ بحضورٍ كامل، وبينهما وبعدهما أيامٌ بلا جلسة.
Map<String, dynamic> _attendance() => {
      'summary': {
        'present': 2,
        'absent': 0,
        'late': 0,
        'excused': 0,
        'total': 2,
        'rate': 100,
      },
      'trend': [
        {'date': '2026-09-07', 'rate': 100, 'sessions': 1},
        {'date': '2026-09-08', 'rate': null, 'sessions': 0},
        {'date': '2026-09-09', 'rate': 100, 'sessions': 1},
      ],
      'recent': [
        {
          'uuid': 'att-1',
          'student_uuid': 'std-1',
          'student_name': 'محمد بن خالد',
          'status': 'present',
          'late_minutes': null,
          'note': null,
          // تصحيحٌ رجعي: كُتب في العاشر عن جلسة التاسع.
          'recorded_at': '2026-09-10T09:00:00.000000Z',
          'session_date': '2026-09-09',
        },
      ],
    };

/// طالبٌ كلُّ سجلّاته أعذار — لا مقامَ له، فلا نسبةَ له.
Map<String, dynamic> _allExcused() => {
      'summary': {
        'present': 0,
        'absent': 0,
        'late': 0,
        'excused': 3,
        'total': 3,
        'rate': null,
      },
      'trend': <Map<String, dynamic>>[],
      'recent': <Map<String, dynamic>>[],
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

  testWidgets('the first screen lists the children of this account', (tester) async {
    when(api.guardianChildren).thenAnswer((_) async => _response(_children()));

    await tester.pumpWidget(_wrap(dependencies, const ChildrenScreen()));
    await tester.pumpAndSettle();

    expect(find.text('محمد بن خالد'), findsOneWidget);
    expect(find.text('رقم المعرف 1042'), findsOneWidget);
  });

  testWidgets('a guardian with no children is told so, not shown a blank screen', (tester) async {
    when(api.guardianChildren).thenAnswer((_) async => _response({'data': []}));

    await tester.pumpWidget(_wrap(dependencies, const ChildrenScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('لا أبناءَ مسجَّلون'), findsOneWidget);
  });

  /// 🔑 القاعدةُ الأولى: بيانٌ قديم يجب أن يُعلَن قِدَمُه.
  testWidgets('a snapshot served offline announces that it is stale', (tester) async {
    when(api.guardianChildren).thenAnswer((_) async => _response(_children()));

    await tester.pumpWidget(_wrap(dependencies, const ChildrenScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('لا اتصال'), findsNothing);

    when(api.guardianChildren).thenThrow(_offline());

    // مفتاحٌ جديد ⇒ حالةٌ جديدة ⇒ قراءةٌ ثانية: هو ما يماثل فتحَ الشاشة من جديد.
    // وبلا مفتاحٍ يُعاد استخدام العنصر نفسِه فلا يُستدعى `initState` أصلاً.
    await tester.pumpWidget(
      _wrap(dependencies, const ChildrenScreen(key: ValueKey('reopened'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('محمد بن خالد'), findsOneWidget);
    expect(find.textContaining('لا اتصال'), findsOneWidget);
    expect(find.textContaining('آخر تحديث'), findsOneWidget);
  });

  testWidgets('an outage with nothing saved shows the reason and a retry', (tester) async {
    when(api.guardianChildren).thenThrow(_offline());

    await tester.pumpWidget(_wrap(dependencies, const ChildrenScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('لا اتصال بالخادم'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  /// 🔑 القاعدةُ الثالثة على السطح الذي يقرؤه المستخدم.
  testWidgets('a rate that was never measured is shown as a dash, not a zero', (tester) async {
    when(() => api.guardianChildAttendance('std-1'))
        .thenAnswer((_) async => _response(_allExcused()));

    await tester.pumpWidget(_wrap(
      dependencies,
      const ChildScreen(
        child: GuardianChild(uuid: 'std-1', fullName: 'محمد بن خالد'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets);
    expect(find.text('0.0٪'), findsNothing);
    expect(find.text('٠٪'), findsNothing);
  });

  /// 🔴 الحاجبُ الذي فتح المرحلة: السجلُّ يُعرض بيوم الجلسة لا بيوم كتابته.
  testWidgets('an attendance row is dated by its session, not by when it was written', (tester) async {
    when(() => api.guardianChildAttendance('std-1'))
        .thenAnswer((_) async => _response(_attendance()));

    await tester.pumpWidget(_wrap(
      dependencies,
      const ChildScreen(
        child: GuardianChild(uuid: 'std-1', fullName: 'محمد بن خالد'),
      ),
    ));
    await tester.pumpAndSettle();

    // 2026-09-09 أربعاء، و2026-09-10 (يومُ الكتابة) خميس.
    expect(find.textContaining('الأربعاء'), findsOneWidget);
    expect(find.textContaining('الخميس'), findsNothing);
  });

  /// 🔑 القاعدةُ الثانية: إذنٌ «قيد المراجعة» ليس إذناً.
  testWidgets('a pending excuse says plainly that it is not an approval yet', (tester) async {
    when(api.guardianExcuses).thenAnswer(
      (_) async => _response({
        'data': [
          {
            'uuid': 'exc-1',
            'student_uuid': 'std-1',
            'student_name': 'محمد بن خالد',
            'from_date': '2026-09-12',
            'to_date': '2026-09-13',
            'reason': 'سفر عائلي',
            'status': 'pending',
            'status_label': 'قيد المراجعة',
            'reviewed_at': null,
            'review_note': null,
            'submitted_at': '2026-09-10T19:44:00.000000Z',
          },
        ],
      }),
    );

    await tester.pumpWidget(_wrap(dependencies, const ExcusesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.textContaining('لا يُحتسب مأذوناً قبل القبول'), findsOneWidget);
  });

  testWidgets('a rejected excuse carries the reason the staff gave', (tester) async {
    when(api.guardianExcuses).thenAnswer(
      (_) async => _response({
        'data': [
          {
            'uuid': 'exc-1',
            'student_uuid': 'std-1',
            'student_name': 'محمد بن خالد',
            'from_date': '2026-09-12',
            'to_date': '2026-09-13',
            'reason': 'سفر عائلي',
            'status': 'rejected',
            'status_label': 'مرفوض',
            'reviewed_at': '2026-09-11T07:10:00.000000Z',
            'review_note': 'الدورة في أيامها الأخيرة.',
            'submitted_at': '2026-09-10T19:44:00.000000Z',
          },
        ],
      }),
    );

    await tester.pumpWidget(_wrap(dependencies, const ExcusesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('مرفوض'), findsOneWidget);
    expect(find.text('الدورة في أيامها الأخيرة.'), findsOneWidget);
  });
}

