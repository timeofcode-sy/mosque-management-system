import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'announcements_screen.dart';

/// ما تجمعه الرئيسية من ثلاث نقاط: الموقعُ، والأجزاءُ، وآخرُ إعلان.
typedef _HomeData = ({
  StudentStanding standing,
  JuzSummary juz,
  Announcement? latest,
});

/// الرئيسية: تحيّةٌ باسمه وحلقته، ثم أرقامُه الأربعة، وآخرُ إعلان، وحديثُ اليوم.
///
/// غرضُ التطبيق كلِّه في هذه الشاشة: **أن يرى الطالبُ أثرَ انضباطه رقماً أمامه**
/// ([APPS-FEATURES.md §6.1](../../../../../../../docs/APPS-FEATURES.md)). والأبوابُ التي
/// كانت أزراراً تحت الأرقام صارت ألسنةً في الشريط السفلي، والرقمُ نفسُه يفتح لسانَه.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenTab});

  /// يفتح لساناً من الشريط السفلي: 1 حضوري · 2 حفظي · 3 سلوكي.
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repository = scope.repository;
    final snapshot = scope.session.snapshot;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: const Center(child: BrandMark(size: 40)),
        title: const Text('الرئيسية'),
        actions: const [AnnouncementsAction()],
      ),
      body: SnapshotView<_HomeData>(
        load: () async {
          final (standing, progress, announcements) = await (
            repository.standing(),
            _optional(repository.progress()),
            _optional(repository.announcements()),
          ).wait;

          return (
            value: (
              standing: standing.value,
              juz: progress == null
                  ? const JuzSummary()
                  : JuzSummary.fromEntries(progress.value.byCurriculum.values.expand((rows) => rows)),
              latest: announcements?.value.firstOrNull,
            ),
            fetchedAt: standing.fetchedAt,
            isStale: standing.isStale,
          );
        },
        errorMessageBuilder: messageFor,
        builder: (context, data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Greeting(
              name: snapshot?.userName ?? 'حسابي',
              institute: snapshot?.institute.name,
              circle: data.standing.circleName,
            ),
            _Stats(data: data, onOpenTab: onOpenTab),
            if (data.latest case final Announcement latest) _Latest(announcement: latest),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: HomeHadith(),
            ),
          ],
        ),
      ),
    );
  }

  /// ما لا تقوم الرئيسيةُ عليه لا يُسقطها: الأرقامُ من `standing`، والباقي زينة.
  static Future<T?> _optional<T>(Future<T> future) async {
    try {
      return await future;
    } on Object {
      return null;
    }
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, this.institute, this.circle});

  final String name;
  final String? institute;
  final String? circle;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final scheme = Theme.of(context).colorScheme;
    final details = [?institute, ?circle].join(' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NzRadius.md),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [scheme.primary, Color.lerp(scheme.primary, Colors.black, 0.35)!],
        ),
      ),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  'السلام عليكم',
                  style: NzType.caption.copyWith(color: scheme.onPrimary.withValues(alpha: 0.8)),
                ),
                Text(
                  name,
                  style: NzType.title.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: NzType.caption.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
                  ),
              ],
            ),
          ),
          NzIcon(NzIcons.mushaf, size: 40, color: c.bronzeSoft),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data, this.onOpenTab});

  final _HomeData data;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final standing = data.standing;
    final juz = data.juz;

    Widget cell(Widget card, int tab) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(NzRadius.md),
            onTap: onOpenTab == null ? null : () => onOpenTab!(tab),
            child: card,
          ),
        );

    // الهامشُ بين البطاقات هنا لا فيها: بطاقاتُ الثيم بلا هامش.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        spacing: 8,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                cell(
                  StatCard(
                    // 🔑 نسبةٌ `null` تُكتب «—» لا «0%»: طالبٌ لم يُتفقَّد بعد لم
                    // يغب، وصفرٌ ههنا يقول إنه لم يحضر يوماً.
                    value: standing.rate == null ? '—' : '${standing.rate!.toStringAsFixed(1)}%',
                    label: 'نسبة حضوري',
                    icon: NzIcons.percent,
                  ),
                  1,
                ),
                cell(
                  StatCard(
                    value: '${standing.points}',
                    label: 'نقاطي',
                    icon: NzIcons.star,
                    hint: 'في الدورة الجارية',
                  ),
                  3,
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                cell(
                  StatCard(
                    // 🔑 **رقمٌ لا كشف.** الرتبةُ تُحسب في الخادم فلا يصل الجهازَ صفٌّ
                    // عن زميل ([PHASE-8-STAGES.MD §1.2]).
                    value: standing.isRanked ? '${standing.rank}' : '—',
                    label: 'ترتيبي في الحلقة',
                    icon: NzIcons.reports,
                    hint: standing.isRanked
                        ? 'من ${standing.peers} طالباً'
                        : standing.peers > 0
                            ? 'لم يُقَس بعد'
                            : 'لست في حلقةٍ جارية',
                  ),
                  1,
                ),
                cell(
                  StatCard(
                    value: '${juz.memorized.length}',
                    label: 'أجزائي المحفوظة',
                    icon: NzIcons.mushaf,
                    hint: juz.current == null ? 'من 30 جزءاً' : 'أحفظ الآن الجزء ${juz.current}',
                  ),
                  2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Latest extends StatelessWidget {
  const _Latest({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('آخر إعلان', style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AnnouncementsScreen()),
                ),
                child: const Text('كل الإعلانات'),
              ),
            ],
          ),
        ),
        AnnouncementCard(
          title: announcement.title,
          body: announcement.body,
          publishedAt: announcement.publishedAt,
          circleBadge: announcement.isForMyCircle ? 'لحلقتي' : null,
        ),
      ],
    );
  }
}
