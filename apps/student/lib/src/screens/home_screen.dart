import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'announcements_screen.dart';
import 'attendance_screen.dart';
import 'progress_screen.dart';

/// الرئيسية: نسبتي · رتبتي · نقاطي — وأبوابُ الثلاثة الباقية.
///
/// غرضُ التطبيق كلِّه في هذه الشاشة: **أن يرى الطالبُ أثرَ انضباطه رقماً أمامه**
/// ([APPS-FEATURES.md §6.1](../../../../../docs/APPS-FEATURES.md)).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final snapshot = scope.session.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: Text(snapshot?.userName ?? 'حسابي'),
        actions: [
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: scope.session.signOut,
          ),
        ],
      ),
      body: SnapshotView<StudentStanding>(
        load: () async => (await scope.repository.standing()).ui,
        errorMessageBuilder: messageFor,
        builder: (context, standing) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot?.institute.name case final String name)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(name, style: Theme.of(context).textTheme.titleMedium),
              ),
            _StandingCard(standing: standing),
            const _Doors(),
          ],
        ),
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.standing});

  final StudentStanding standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (standing.circleName case final String circle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(circle, style: theme.textTheme.bodyMedium),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: StatCard(
                  // 🔑 نسبةٌ `null` تُكتب «—» لا «٠٪»: طالبٌ لم يُتفقَّد بعد لم
                  // يغب، وصفرٌ ههنا يقول إنه لم يحضر يوماً.
                  value: standing.rate == null
                      ? '—'
                      : '${standing.rate!.toStringAsFixed(1)}٪',
                  label: 'نسبة حضوري',
                  icon: Icons.percent,
                ),
              ),
              Expanded(
                child: StatCard(
                  value: '${standing.points}',
                  label: 'نقاطي',
                  icon: Icons.star_outline,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.leaderboard_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      // 🔑 **رقمٌ لا كشف.** الرتبةُ تُحسب في الخادم فلا يصل
                      // الجهازَ صفٌّ عن زميل، ولا كشفَ بأسماء الأوائل — وذاك
                      // يعيد التسريبَ من البابِ الذي أُغلق
                      // ([PHASE-8-STAGES.MD §1.2]).
                      standing.isRanked
                          ? 'ترتيبي في الحلقة: ${standing.rank} من ${standing.peers}'
                          : standing.peers > 0
                              ? 'لم يُقَس ترتيبي بعد — بين ${standing.peers} طالباً'
                              : 'لست مسجَّلاً في حلقةٍ جارية.',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Doors extends StatelessWidget {
  const _Doors();

  @override
  Widget build(BuildContext context) {
    final doors = <({IconData icon, String label, Widget screen})>[
      (icon: Icons.fact_check_outlined, label: 'حضوري', screen: const AttendanceScreen()),
      (icon: Icons.menu_book_outlined, label: 'حفظي', screen: const ProgressScreen()),
      (icon: Icons.campaign_outlined, label: 'الإعلانات', screen: const AnnouncementsScreen()),
    ];

    return Column(
      children: [
        const SizedBox(height: 8),
        for (final door in doors)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ListTile(
              leading: Icon(door.icon),
              title: Text(door.label),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => door.screen),
              ),
            ),
          ),
      ],
    );
  }
}
