import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/sync_bar.dart';
import 'points_screen.dart';
import 'recitation_screen.dart';
import 'student_profile_screen.dart';

/// شاشة التفقّد: ضغطةٌ واحدة لكل طالب.
///
/// ثلاث قواعد ملزمة تسكن هنا:
/// 1. **الحالة قرارُ الأستاذ والرقم تلقائي** — «متأخر» تملأ الدقائق من بداية
///    الدوام، وتبقى قابلةً للتصحيح اليدوي (§0 البند 2).
/// 2. **`editable` يُحترم محلياً** — جلسةٌ مكتملة أو مقفلة لا تُحرَّر، لأن الأستاذ
///    لا يملك `attendance.amend` وسيُرفض دفعُه بعد ساعات
///    ([SYNC-PROTOCOL.md §6](../../../../../docs/SYNC-PROTOCOL.md)).
/// 3. **لا شبكة في المسار** — الحفظ يصفّ عملية ويعود، ولا ينتظر خادماً.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.circle, required this.date});

  final CircleView circle;
  final DateTime date;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late DateTime _date = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );

  /// تعديلاتٌ لم تُحفظ بعد، مفهرسةً بمعرّف الطالب — تعلو ما يعود من drift.
  final Map<int, RosterEntry> _edits = {};

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.circle.circleName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _DateBar(date: _date, onPick: _pickDate),
        ),
      ),
      body: Column(
        children: [
          const AppSyncBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<SessionView>(
              stream: deps.repository.watchSession(
                circle: widget.circle,
                date: _date,
                graceMinutes: deps.session.graceMinutes,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _body(context, snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, SessionView session) {
    // الأستاذُ لا يملك `attendance.amend` في البذرة، فالمكتملةُ لا تُحرَّر من جهازه.
    // والحكمُ يُقرأ من اللقطة لا يُفترض في الشيفرة: هو نفسُه الذي يطبّقه الخادم في
    // `SyncPush::assertPermitted`، فما يُصفّ هنا لا يُرفض بعد ساعات (م.6.4).
    final editable = session.editableBy(
      canAmend: AppScope.of(context).session.snapshot?.can('attendance.amend') ??
          false,
    );

    if (session.roster.isEmpty) {
      return const EmptyState(
        message: 'لا طلاب مسجَّلون في هذه الحلقة بهذا التاريخ.',
        icon: Icons.groups_outlined,
      );
    }

    final roster = [
      for (final entry in session.roster) _edits[entry.studentId] ?? entry,
    ];

    final dirty = _edits.isNotEmpty;

    return Column(
      children: [
        _Summary(roster: roster),
        if (!editable) _LockedBanner(status: session.status!),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: roster.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _StudentTile(
              entry: roster[index],
              editable: editable,
              onStatus: (status) =>
                  _setStatus(session, roster[index], status, editable),
              onMore: () => _showActions(session, roster[index], editable),
              onRecitation: (recitation) =>
                  _openRecitation(session, roster[index], recitation),
              onDeleteRecitation: (recitation) =>
                  _deleteRecitation(session, roster[index], recitation),
              onPoint: (award) => _openPoints(session, roster[index], award),
              onDeletePoint: (award) =>
                  _deletePoints(session, roster[index], award),
            ),
          ),
        ),
        if (editable)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: _saving || !(dirty || !session.exists)
                          ? null
                          : () => _save(session),
                      icon: const Icon(Icons.save_outlined),
                      // «فتح الجلسة» و«حفظ» فعلٌ واحد: الفتحُ يصفّ
                      // attendance.session.open وحدها، والحفظ يُتبعها
                      // attendance.take بنفس الطابور وبنفس الترتيب.
                      label: Text(
                        session.exists
                            ? 'حفظ التفقّد'
                            : 'فتح الجلسة وحفظ التفقّد',
                      ),
                    ),
                  ),
                  // 🔴 `Expanded` لا زرٌّ عارٍ: ثيمُ الهاتف يعطي كلَّ زرٍّ
                  // `minimumSize: Size.fromHeight(52)` — أي عرضاً **لا نهائياً**
                  // مقصوداً به «بعرض الشاشة». والصفُّ يقيس ابنَه غيرَ المرن بعرضٍ
                  // غير محدود، فتصير الحدُّ الأدنى تقييداً محكماً باللانهاية
                  // وينكسر التخطيط. كُشف بأوّل اختبار واجهةٍ لهذه الشاشة (م.6.4).
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _confirmComplete(session),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('إقفال'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmComplete(SessionView session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إقفال الجلسة'),
        // تحذيرٌ صريح: الأستاذ لا يملك attendance.amend، فالإقفال بابٌ لا يفتحه
        // إلا المشرف (SYNC-PROTOCOL §6).
        content: const Text(
          'بعد الإقفال لن تستطيع تعديل هذا التفقّد من التطبيق — التصحيح يحتاج صلاحية المشرف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إقفال'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      await _save(session, andComplete: true);
    }
  }

  /// ضغطةٌ على حالة: تُثبّت زمن الحدث فوراً وتحسب الدقائق محلياً إن كانت «متأخر».
  void _setStatus(
    SessionView session,
    RosterEntry entry,
    AttendanceStatus status,
    bool editable,
  ) {
    if (!editable) {
      return;
    }

    final now = DateTime.now();
    final computed = status == AttendanceStatus.late
        ? LateMinutes.afterGrace(
            LateMinutes.forSession(
              shiftStartsAt: widget.circle.shiftStartsAt,
              sessionDate: session.date,
              recordedAt: now,
            ),
            AppScope.of(context).session.graceMinutes,
          )
        : null;

    setState(() {
      _edits[entry.studentId] = entry.copyWith(
        status: status,
        origin: AttendanceOrigin.pending,
        // `recordedAt` زمنُ الضغط لا زمنُ الحفظ ولا زمنُ الإرسال — هو مفتاح حسم
        // التعارض على الخادم (SYNC-PROTOCOL §5).
        recordedAt: now,
        clearLateMinutes: true,
        lateMinutes: computed,
      );
    });
  }

  Future<void> _showActions(
    SessionView session,
    RosterEntry entry,
    bool editable,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                entry.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(_originLabel(entry.origin)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('ملف الطالب'),
              onTap: () => Navigator.of(context).pop('profile'),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('تسجيل تسميع'),
              onTap: () => Navigator.of(context).pop('recitation'),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('منح نقاط'),
              onTap: () => Navigator.of(context).pop('points'),
            ),
            if (editable) ...[
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('تعديل دقائق التأخير'),
                enabled: entry.status == AttendanceStatus.late,
                onTap: () => Navigator.of(context).pop('late'),
              ),
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('ملاحظة'),
                onTap: () => Navigator.of(context).pop('note'),
              ),
            ],
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'profile':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StudentProfileScreen(studentId: entry.studentId),
          ),
        );
      case 'recitation':
        await _openRecitation(session, entry, null);
      case 'points':
        await _openPoints(session, entry, null);
      case 'late':
        await _editLateMinutes(entry);
      case 'note':
        await _editNote(entry);
    }
  }

  /// شاشةُ التسميع واحدة للتسجيل وللتصحيح: [recitation] فارغاً تسجيلٌ جديد،
  /// ومملوءاً تصحيحُ ما سُجّل — والمعرّف هو ما يفرّق بينهما على الخادم.
  Future<void> _openRecitation(
    SessionView session,
    RosterEntry entry,
    RecitationEntry? recitation,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecitationScreen(
          session: session,
          entry: entry,
          recitation: recitation,
        ),
      ),
    );
  }

  Future<void> _openPoints(
    SessionView session,
    RosterEntry entry,
    PointEntry? award,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PointsScreen(session: session, entry: entry, award: award),
      ),
    );
  }

  Future<void> _deleteRecitation(
    SessionView session,
    RosterEntry entry,
    RecitationEntry recitation,
  ) async {
    // يُقرآن قبل الحوار: بعده قد يكون السياق زال، وهما لا يتغيّران بانتظاره.
    final deps = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!await _confirmDelete('حذف التسميع', recitation.rangeLabel)) {
      return;
    }

    await deps.repository.deleteRecitation(
      session: session,
      studentId: entry.studentId,
      recitation: recitation,
    );

    deps.sync.syncNow();
    messenger.showSnackBar(
      const SnackBar(content: Text('حُذف التسميع وصُفَّ الحذف للمزامنة.')),
    );
  }

  Future<void> _deletePoints(
    SessionView session,
    RosterEntry entry,
    PointEntry award,
  ) async {
    final deps = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!await _confirmDelete('حذف النقاط', _pointsLabel(award))) {
      return;
    }

    await deps.repository.deletePoints(
      session: session,
      studentId: entry.studentId,
      award: award,
    );

    deps.sync.syncNow();
    messenger.showSnackBar(
      const SnackBar(content: Text('حُذفت النقاط وصُفَّ الحذف للمزامنة.')),
    );
  }

  /// الحذف على شاشةٍ صغيرة ضغطةٌ واحدة قريبة من غيرها، فيُسأل عنه قبل وقوعه.
  Future<bool> _confirmDelete(String title, String what) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('سيُحذف «$what». لا يمكن التراجع بعد المزامنة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    return (confirmed ?? false) && mounted;
  }

  Future<void> _editLateMinutes(RosterEntry entry) async {
    final controller = TextEditingController(
      text: entry.lateMinutes?.toString() ?? '',
    );

    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دقائق التأخير'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            helperText: 'اتركها فارغة ليحسبها الخادم من بداية الدوام',
            suffixText: 'دقيقة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(-1),
            child: const Text('احسبها تلقائياً'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context)
                    .pop(int.tryParse(controller.text.trim()) ?? -1),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || value == null) {
      return;
    }

    setState(() {
      _edits[entry.studentId] = entry.copyWith(
        origin: AttendanceOrigin.pending,
        recordedAt: entry.recordedAt ?? DateTime.now(),
        clearLateMinutes: true,
        // `-1` علامةُ «اتركه للخادم»: التصحيح اليدوي وحده يُرسَل، فالقيمة المرسَلة
        // تغلب المحسوبة دائماً (API.md §6).
        lateMinutes: value < 0 ? null : value,
        lateMinutesOverride: value < 0 ? null : value,
      );
    });
  }

  Future<void> _editNote(RosterEntry entry) async {
    final controller = TextEditingController(text: entry.note ?? '');

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ملاحظة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || value == null) {
      return;
    }

    setState(() {
      _edits[entry.studentId] = entry.copyWith(
        origin: AttendanceOrigin.pending,
        recordedAt: entry.recordedAt ?? DateTime.now(),
        note: value.isEmpty ? null : value,
        clearNote: value.isEmpty,
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      // تعديلاتُ يومٍ لا تُنقل إلى يومٍ آخر.
      _edits.clear();
    });
  }

  Future<void> _save(SessionView session, {bool andComplete = false}) async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);
    final deps = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final roster = [
        for (final entry in session.roster) _edits[entry.studentId] ?? entry,
      ];

      await deps.repository.saveAttendance(session: session, entries: roster);

      if (andComplete) {
        // تُقرأ الجلسة من جديد: الحفظ قد يكون هو ما أنشأ صفَّ المسودّة المحلية،
        // فالمعرّف الذي تُقفل به لم يكن موجوداً قبل السطر السابق.
        final refreshed = await deps.repository.loadSession(
          circle: widget.circle,
          date: _date,
          graceMinutes: deps.session.graceMinutes,
        );
        await deps.repository.completeSession(refreshed);
      }

      _edits.clear();
      unawaitedSync(deps);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            andComplete
                ? 'أُقفلت الجلسة وصُفَّت للمزامنة.'
                : 'حُفظ التفقّد محلياً وصُفَّ للمزامنة.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// المزامنة محاولةٌ لا شرط: الحفظ تمّ في drift قبلها، وفشلُها لا يلغيه.
  void unawaitedSync(AppDependencies deps) {
    deps.sync.syncNow();
  }

  /// `+2 مشاركة` أو `-1.5 سلوك` — الإشارة جزءٌ من المعنى، فالخصم يُقرأ خصماً.
  static String _pointsLabel(PointEntry award) {
    final value = award.points == award.points.roundToDouble()
        ? '${award.points.round()}'
        : '${award.points}';

    return '${award.points > 0 ? '+' : ''}$value '
        '${pointsReasonLabels[award.reason] ?? ''}'.trim();
  }

  static String _originLabel(AttendanceOrigin origin) => switch (origin) {
    AttendanceOrigin.suggested => 'قيمة مقترحة — لم تُسجَّل بعد',
    AttendanceOrigin.pending => 'بانتظار المزامنة',
    AttendanceOrigin.synced => 'مؤكَّدة من الخادم',
  };
}

class _DateBar extends StatelessWidget {
  const _DateBar({required this.date, required this.onPick});

  final DateTime date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    // AppBar.bottom لا يورّث foregroundColor إلى أبنائه كما يفعل مع العنوان، فيقرؤه
    // هذا الشريط بنفسه — وإلا خرج نصُّه بلون النصّ العادي فوق ترويسةٍ ملوّنة.
    final onHeader =
        AppBarTheme.of(context).foregroundColor ??
        Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onPick,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IconTheme(
          data: IconThemeData(color: onHeader),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: onHeader),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd').format(date)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.roster});

  final List<RosterEntry> roster;

  @override
  Widget build(BuildContext context) {
    int count(AttendanceStatus status) =>
        roster.where((entry) => entry.status == status).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: StatCard(
              value: '${count(AttendanceStatus.present)}',
              label: 'حاضر',
            ),
          ),
          Expanded(
            child: StatCard(
              value: '${count(AttendanceStatus.absent)}',
              label: 'غائب',
            ),
          ),
          Expanded(
            child: StatCard(
              value: '${count(AttendanceStatus.late)}',
              label: 'متأخر',
            ),
          ),
          Expanded(
            child: StatCard(
              value: '${count(AttendanceStatus.excused)}',
              label: 'مأذون',
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondary.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        status == 'locked'
            ? 'الجلسة مقفلة — التصحيح من صلاحية المشرف.'
            : 'الجلسة مكتملة — تصحيحُها يحتاج صلاحية المشرف.',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.entry,
    required this.editable,
    required this.onStatus,
    required this.onMore,
    required this.onRecitation,
    required this.onDeleteRecitation,
    required this.onPoint,
    required this.onDeletePoint,
  });

  final RosterEntry entry;
  final bool editable;
  final ValueChanged<AttendanceStatus> onStatus;
  final VoidCallback onMore;
  final ValueChanged<RecitationEntry> onRecitation;
  final ValueChanged<RecitationEntry> onDeleteRecitation;
  final ValueChanged<PointEntry> onPoint;
  final ValueChanged<PointEntry> onDeletePoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.fullName, style: theme.textTheme.titleSmall),
              ),
              if (entry.origin == AttendanceOrigin.pending)
                const Icon(Icons.schedule, size: 16)
              else if (entry.origin == AttendanceOrigin.suggested)
                Icon(Icons.help_outline, size: 16, color: theme.disabledColor),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: onMore,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SegmentedButton<AttendanceStatus>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AttendanceStatus.present,
                label: Text('حاضر'),
              ),
              ButtonSegment(
                value: AttendanceStatus.absent,
                label: Text('غائب'),
              ),
              ButtonSegment(value: AttendanceStatus.late, label: Text('متأخر')),
              ButtonSegment(
                value: AttendanceStatus.excused,
                label: Text('مأذون'),
              ),
            ],
            selected: {entry.status},
            onSelectionChanged: editable
                ? (values) => onStatus(values.first)
                : null,
          ),
          if (entry.status == AttendanceStatus.late &&
              entry.lateMinutes != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                entry.lateMinutesOverride == null
                    ? 'تأخّر ${entry.lateMinutes} دقيقة (محسوبة من بداية الدوام)'
                    : 'تأخّر ${entry.lateMinutes} دقيقة (مُدخَلة يدوياً)',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (entry.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ملاحظة: ${entry.note}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          // ما سُجّل للطالب في هذه الجلسة، معروضاً تحت اسمه: الأستاذ يرى أثر ما
          // أدخله قبل أن يُزامَن، وينقر عليه فيصحّحه بدل أن يحذفه ويعيده.
          if (entry.recitations.isNotEmpty || entry.points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final recitation in entry.recitations)
                    _RecordChip(
                      label: _recitationLabel(recitation),
                      pending: recitation.pending,
                      editable: editable,
                      onTap: () => onRecitation(recitation),
                      onDelete: () => onDeleteRecitation(recitation),
                    ),
                  for (final award in entry.points)
                    _RecordChip(
                      label: _awardLabel(award),
                      pending: award.pending,
                      editable: editable,
                      color: award.points < 0
                          ? theme.colorScheme.error
                          : null,
                      onTap: () => onPoint(award),
                      onDelete: () => onDeletePoint(award),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// «الملك 1–30 · ممتاز · 20.67 نقطة» — والنقاط تُترك لمسودّةٍ لم يحسبها الخادم بعد.
  static String _recitationLabel(RecitationEntry recitation) {
    final parts = <String>[
      recitation.rangeLabel,
      ?recitationGradeLabels[recitation.grade],
      if (recitation.points != null) '${_number(recitation.points!)} نقطة',
    ];

    return parts.join(' · ');
  }

  static String _awardLabel(PointEntry award) {
    final reason = pointsReasonLabels[award.reason];
    final value = '${award.points > 0 ? '+' : ''}${_number(award.points)}';

    return reason == null ? value : '$value $reason';
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

/// شارةُ ما سُجّل: نقرةٌ تفتحه للتصحيح، وعلامةٌ تحذفه، وساعةٌ تقول إنه لم يُزامَن.
class _RecordChip extends StatelessWidget {
  const _RecordChip({
    required this.label,
    required this.pending,
    required this.editable,
    required this.onTap,
    required this.onDelete,
    this.color,
  });

  final String label;
  final bool pending;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InputChip(
      label: Text(label, style: TextStyle(color: color)),
      avatar: pending ? const Icon(Icons.schedule, size: 16) : null,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.bodySmall,
      // جلسةٌ مقفلة تُعرَض ولا تُحرَّر: الأستاذ لا يملك attendance.amend، وعمليةٌ
      // مصيرُها الرفض بعد ساعات لا تُصفّ من الأصل.
      onPressed: editable ? onTap : null,
      onDeleted: editable ? onDelete : null,
      deleteIcon: const Icon(Icons.close, size: 16),
      tooltip: editable ? 'اضغط للتعديل' : null,
    );
  }
}
