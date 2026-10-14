import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/behavior_section.dart';
import '../di/app_scope.dart';

/// ملف الطالب عند أستاذه — ثلاثةُ ألسنة: **عنه** (من هو: عمرُه وصفُّه وأهلُه ووضعُه الصحي
/// ومحفوظاتُه)، و**سلوكه** (ما كُتب عنه، كما يراه وليُّ أمره)، و**سجلُّه** (تسميعٌ ونقاطٌ وحضور).
///
/// كلُّها من drift: الأستاذُ يسحب المعهدَ كاملاً، فيُفتح الملفُّ والشبكةُ مقطوعة. والنِّسَبُ
/// والمجاميعُ تُحسب هنا لا تُطلب من الخادم ([SYNC-PROTOCOL.md §7](../../../../../../../docs/SYNC-PROTOCOL.md)).
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return StreamBuilder<StudentProfile?>(
      stream: deps.repository.watchStudentProfile(studentId),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(profile?.fullName ?? 'ملف الطالب'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'عنه', icon: NzIcon(NzIcons.user)),
                  Tab(text: 'السلوك', icon: NzIcon(NzIcons.star)),
                  Tab(text: 'السجلّ', icon: NzIcon(NzIcons.list)),
                ],
              ),
            ),
            body: profile == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _About(profile: profile),
                      ListView(
                        children: [BehaviorSection(behavior: profile.behavior)],
                      ),
                      _Record(profile: profile),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// «عنه»: أرقامُ حضوره، ثم بطاقتُه.
class _About extends StatelessWidget {
  const _About({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final rate = profile.attendanceRate;
    final details = profile.details;
    final age = details.ageOn(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: StatCard(
                value: rate == null ? '—' : '${rate.toStringAsFixed(1)}%',
                label: 'نسبة الحضور',
                icon: NzIcons.percent,
              ),
            ),
            Expanded(
              child: StatCard(
                value: profile.totalPoints.toStringAsFixed(1),
                label: 'مجموع النقاط',
                icon: NzIcons.star,
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${details.memorizedJuz.length}',
                label: 'جزءاً محفوظاً',
                icon: NzIcons.mushaf,
              ),
            ),
          ],
        ),
        _Card(
          title: 'البيانات الشخصية',
          rows: [
            ('رقم التسجيل', profile.registrationNo),
            (
              'العمر',
              age == null
                  ? null
                  : '$age سنة · مواليد ${details.birthDate!.year}',
            ),
            ('الصف', details.gradeLevel),
            ('عمله', details.studentJob),
            ('العنوان', details.address),
            ('عدد أفراد العائلة', details.familyMembersCount?.toString()),
            (
              'تاريخ التسجيل',
              details.registrationDate == null
                  ? null
                  : formatLongDate(
                      details.registrationDate!,
                      withWeekday: false,
                    ),
            ),
            for (final MapEntry(key: label, value: value)
                in details.customFields.entries)
              (label, value),
          ],
          trailing: details.phone == null
              ? null
              : _PhoneButton(phone: details.phone!, label: 'جوال الطالب'),
        ),
        _ParentsCard(father: details.father, mother: details.mother),
        if (_filled(details.healthStatus) ||
            _filled(details.familyHealthStatus))
          _Card(
            title: 'الوضع الصحي',
            highlight: true,
            rows: [
              ('الطالب', details.healthStatus),
              ('العائلة', details.familyHealthStatus),
            ],
          ),
        _MemorizedCard(details: details),
        if (_filled(details.notes))
          _Card(title: 'ملاحظات', rows: [('', details.notes)]),
      ],
    );
  }
}

bool _filled(String? value) => value != null && value.trim().isNotEmpty;

/// بطاقةٌ بعنوانٍ وأسطرٍ «اسم: قيمة» — والسطرُ الفارغ لا يُكتب.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.rows,
    this.trailing,
    this.highlight = false,
  });

  final String title;
  final List<(String, String?)> rows;
  final Widget? trailing;

  /// بطاقةٌ يُنبَّه إليها (الوضع الصحي) — بحدٍّ تحذيري.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final filled = rows.where((row) => _filled(row.$2)).toList();

    if (filled.isEmpty && trailing == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: c.warning),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ?trailing,
              ],
            ),
            for (final (label, value) in filled)
              label.isEmpty
                  ? Text(value!, style: NzType.body.copyWith(color: c.ink))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            label,
                            style: NzType.label.copyWith(color: c.inkMuted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value!,
                            style: NzType.body.copyWith(color: c.ink),
                          ),
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }
}

class _ParentsCard extends StatelessWidget {
  const _ParentsCard({required this.father, required this.mother});

  final ParentInfo? father;
  final ParentInfo? mother;

  @override
  Widget build(BuildContext context) {
    if (father == null && mother == null) {
      return const SizedBox.shrink();
    }

    final c = context.nz;

    Widget parent(String relation, ParentInfo info) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('$relation: ${info.name}'),
        subtitle: Text(
          [
            if (!info.isAlive) 'متوفى رحمه الله',
            if (_filled(info.occupation)) info.occupation!,
            if (_filled(info.phone)) '\u2066${info.phone}\u2069',
          ].join(' · '),
          style: NzType.caption.copyWith(
            color: info.isAlive ? c.inkMuted : c.warning,
          ),
        ),
        trailing: info.isAlive && _filled(info.phone)
            ? _PhoneButton(phone: info.phone!, label: 'اتصال بـ$relation')
            : null,
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الأهل', style: Theme.of(context).textTheme.titleSmall),
            if (father case final f?) parent('الأب', f),
            if (mother case final m?) parent('الأم', m),
          ],
        ),
      ),
    );
  }
}

/// زرُّ اتصالٍ بنقرة — ورقمٌ لا يُتّصل به لا زرَّ له.
class _PhoneButton extends StatelessWidget {
  const _PhoneButton({required this.phone, required this.label});

  final String phone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      icon: const NzIcon(NzIcons.phone),
      onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
    );
  }
}

class _MemorizedCard extends StatelessWidget {
  const _MemorizedCard({required this.details});

  final StudentDetails details;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    final hasJuz = details.memorizedJuz.isNotEmpty || details.currentJuz != null;

    if (!hasJuz && details.otherMemorized.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.successSoft,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: NzType.label.copyWith(color: c.success)),
    );

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text('محفوظاته', style: Theme.of(context).textTheme.titleSmall),
            // الأجزاءُ ثلاثون خطّاً بنظرةٍ واحدة، وما عداها من المحفوظات شاراتٌ تحتها.
            if (hasJuz)
              NzJuzProgress(
                memorized: details.memorizedJuz.toSet(),
                current: details.currentJuz,
              ),
            if (details.otherMemorized.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in details.otherMemorized) chip(item),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// «السجلّ»: التسميعُ والنقاطُ اليدوية والحضور، كما كان الملفُّ قبلُ.
class _Record extends StatelessWidget {
  const _Record({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.present)}',
                label: 'حاضر',
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.absent)}',
                label: 'غائب',
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.late)}',
                label: 'متأخر',
              ),
            ),
            Expanded(
              child: StatCard(
                value: '${profile.countOf(AttendanceStatus.excused)}',
                label: 'غائب بعذر',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _Section(title: 'المحفوظات'),
        if (profile.recitations.isEmpty)
          const _Hint('لا تسميعَ مسجَّلاً بعد.')
        else
          for (final row in profile.recitations.take(20))
            ListTile(
              dense: true,
              title: Text(_range(row)),
              subtitle: Text(
                '${DateFormat('yyyy-MM-dd').format(row.date)} · '
                '${recitationTypeLabelOf(row.type)}${row.grade == null ? '' : ' · ${recitationGradeLabelOf(row.grade!)}'}',
              ),
              // الأسطر والنقاط محسوبةٌ على الخادم ومجمَّدة — تُعرض كما وصلت.
              trailing: Text('${row.points.toStringAsFixed(1)} ن'),
            ),
        const SizedBox(height: 8),
        const _Section(title: 'النقاط اليدوية'),
        if (profile.points.isEmpty)
          const _Hint('لا نقاطَ يدوية.')
        else
          for (final row in profile.points.take(20))
            ListTile(
              dense: true,
              title: Text(pointsReasonLabelOf(row.reason)),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(row.awardedOn)),
              trailing: Text('${row.points.toStringAsFixed(1)} ن'),
            ),
        const SizedBox(height: 8),
        const _Section(title: 'سجل الحضور'),
        if (profile.attendance.isEmpty)
          const _Hint('لا سجلَّ حضور بعد.')
        else
          for (final entry in profile.attendance.take(30))
            ListTile(
              dense: true,
              title: Text(DateFormat('yyyy-MM-dd').format(entry.date)),
              subtitle: entry.note == null ? null : Text(entry.note!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.lateMinutes != null)
                    Text('${entry.lateMinutes} د  '),
                  AttendanceStatusBadge(status: _badge(entry.status)),
                ],
              ),
            ),
      ],
    );
  }

  static String _range(RecitationRow row) {
    if (row.fromSurah == null || row.toSurah == null) {
      return 'تسميع';
    }

    return '${Quran.name(row.fromSurah!)} ${row.fromAyah ?? ''} '
        '← ${Quran.name(row.toSurah!)} ${row.toAyah ?? ''}';
  }

  static BadgeStatus _badge(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => BadgeStatus.present,
    AttendanceStatus.absent => BadgeStatus.absent,
    AttendanceStatus.late => BadgeStatus.late,
    AttendanceStatus.excused => BadgeStatus.excused,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
