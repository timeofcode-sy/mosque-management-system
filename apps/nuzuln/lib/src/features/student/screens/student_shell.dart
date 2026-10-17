import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../../../config.dart';
import '../di/app_scope.dart';
import 'attendance_screen.dart';
import 'behavior_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';

/// سطحُ الطالب: خمسةُ ألسنةٍ في الشريط السفلي — الرئيسية · حضوري · حفظي · سلوكي · المزيد.
///
/// كانت الأبوابُ أزراراً تحت أرقام الرئيسية تُفتح فوقها؛ والألسنةُ تُبقي كلَّ بابٍ على حاله
/// حين يُترك ويُعاد إليه. **ويُبنى اللسانُ عند أوّل زيارة** لا عند الإقلاع: كلُّ لسانٍ طلبٌ
/// على الشبكة، وأربعةُ طلباتٍ معاً على شبكة المسجد تُبطئ الرئيسية التي فُتح التطبيقُ لها.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  static const _destinations = [
    (icon: NzIcons.home, label: 'الرئيسية'),
    (icon: NzIcons.attendance, label: 'حضوري'),
    (icon: NzIcons.mushaf, label: 'حفظي'),
    (icon: NzIcons.star, label: 'سلوكي'),
    (icon: NzIcons.more, label: 'المزيد'),
  ];

  void _open(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  Widget _tab(int index) => switch (index) {
        0 => HomeScreen(onOpenTab: _open),
        1 => const AttendanceScreen(),
        2 => const ProgressScreen(),
        3 => const BehaviorScreen(),
        _ => const _More(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _open,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: NzIcon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _More extends StatelessWidget {
  const _More();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final snapshot = session.snapshot;

    return MorePage(
      app: AppConfig.about,
      userName: snapshot?.userName ?? 'حسابي',
      subtitle: [?snapshot?.institute.name, 'طالب'].join(' · '),
      onSignOut: session.signOut,
    );
  }
}
