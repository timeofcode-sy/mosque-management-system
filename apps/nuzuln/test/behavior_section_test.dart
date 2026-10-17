import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:nuzuln/src/widgets/behavior_section.dart';

Future<void> _pump(WidgetTester tester, StudentBehavior behavior) =>
    tester.pumpWidget(
      MousqeApp(
        theme: MousqeTheme.light(),
        home: Scaffold(
          body: ListView(children: [BehaviorSection(behavior: behavior)]),
        ),
      ),
    );

void main() {
  testWidgets('a note is shown whole, with its kind, date and circle', (
    tester,
  ) async {
    const long =
        'تأخّر عن الحلقة ربع ساعة، ثم تحدّث مع زميله أثناء التسميع '
        'فنُبّه مرّتين، ونرجو من الأهل متابعته في البيت.';

    await _pump(
      tester,
      StudentBehavior(
        positive: 1,
        negative: 1,
        behaviorPoints: -3,
        notes: [
          BehaviorNote(
            note: long,
            polarity: 'negative',
            date: DateTime(2026, 10, 5),
            circle: 'الإمام النووي',
          ),
          BehaviorNote(
            note: 'يساعد زملاءه',
            polarity: 'positive',
            date: DateTime(2026, 10, 1),
          ),
        ],
        traits: const [
          BehaviorTrait(name: 'هادئ', polarity: 'positive', note: 'في الحلقة'),
        ],
        points: [
          BehaviorPoint(points: -3, date: DateTime(2026, 10, 6), note: 'شاغب'),
        ],
      ),
    );

    expect(find.text(long), findsOneWidget);
    expect(find.text('5 تشرين الأول 2026م · الإمام النووي'), findsOneWidget);
    expect(find.text('ملاحظات الأساتذة'), findsOneWidget);
    expect(find.text('نقاط السلوك · -3'), findsOneWidget);
    expect(find.textContaining('هادئ'), findsOneWidget);
  });

  testWidgets('nothing written yet says so', (tester) async {
    await _pump(tester, const StudentBehavior());

    expect(find.text('لم يكتب الأساتذة ملاحظاتٍ سلوكية بعد.'), findsOneWidget);
  });
}
