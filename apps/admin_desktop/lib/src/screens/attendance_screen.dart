import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'points_dialog.dart';
import 'recitation_dialog.dart';
import 'student_profile_screen.dart';

/// شاشةُ التفقّد على الديسكتوب — نفسُ كشف الأستاذ **وثلاثُ سلطاتٍ فوقه**.
///
/// | السلطة | الحارس | ما يقع بها |
/// |---|---|---|
/// | تصحيحُ تفقّدٍ بعد الإقفال | `attendance.amend` | الجلسةُ المكتملة تُحرَّر، و`amend: true` يُرفع في الحمولة |
/// | القفلُ النهائي | `attendance.lock` | `attendance.session.lock` — وبعده لا تعديلَ ولا إعادةَ فتح |
/// | تفقّدُ الأساتذة | `teachers.view` | `attendance.teacher.take` — كشفٌ ثانٍ لا عمودٌ في الأول |
///
/// وكلُّها تُقرأ من `user.permissions` لا من اسم الدور، ويحرسها الخادمُ بنفسها في
/// `SyncPush::assertPermitted` — فما يُخفى هنا لا يُقبَل هناك، وما يُصفّ لا يُرفض
/// بعد ساعات ([SYNC-PROTOCOL.md §6](../../../../../docs/SYNC-PROTOCOL.md)).
///
/// **ولا شبكة في المسار:** الحفظ يصفّ عملية ويعود، والقفلُ كذلك.
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

  /// تعديلاتٌ لم تُحفظ بعد، مفهرسةً بالمعرّف — تعلو ما يعود من drift.
  final Map<int, RosterEntry> _edits = {};
  final Map<int, TeacherRosterEntry> _teacherEdits = {};

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final snapshot = deps.session.snapshot;
    final canSeeTeachers = snapshot?.can('teachers.view') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.circle.circleName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _DateBar(date: _date, onPick: _pickDate),
        ),
      ),
      body: StreamBuilder<SessionView>(
        stream: deps.circles.watchSession(
          circle: widget.circle,
          date: _date,
          graceMinutes: deps.session.graceMinutes,
          withTeachers: canSeeTeachers,
        ),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return _body(
            context,
            snap.data!,
            canAmend: snapshot?.can('attendance.amend') ?? false,
            canLock: snapshot?.can('attendance.lock') ?? false,
            canSeeTeachers: canSeeTeachers,
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SessionView session, {
    required bool canAmend,
    required bool canLock,
    required bool canSeeTeachers,
  }) {
    if (session.roster.isEmpty) {
      return const EmptyState(
        message: 'لا طلاب مسجَّلون في هذه الحلقة بهذا التاريخ.',
        icon: Icons.groups_outlined,
      );
    }

    final editable = session.editableBy(canAmend: canAmend);
    final roster = [
      for (final entry in session.roster) _edits[entry.studentId] ?? entry,
    ];
    final teacherRoster = [
      for (final entry in session.teacherRoster)
        _teacherEdits[entry.teacherId] ?? entry,
    ];

    final dirty = _edits.isNotEmpty || _teacherEdits.isNotEmpty;

    return Column(
      children: [
        _Header(
          session: session,
          roster: roster,
          editable: editable,
          canAmend: canAmend,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final entry in roster)
                _StudentRow(
                  entry: entry,
                  editable: editable,
                  onStatus: (status) => _setStatus(entry, status, editable),
                  onProfile: () => _openProfile(entry),
                  onRecitation: (recitation) =>
                      _openRecitation(session, entry, recitation),
                  onDeleteRecitation: (recitation) =>
                      _deleteRecitation(session, entry, recitation),
                  onPoint: (award) => _openPoints(session, entry, award),
                  onDeletePoint: (award) =>
                      _deletePoints(session, entry, award),
                  onLate: () => _editLateMinutes(entry),
                  onNote: () => _editNote(entry),
                ),
              if (canSeeTeachers) ...[
                const SizedBox(height: 12),
                _TeacherSection(
                  entries: teacherRoster,
                  // كشفُ الأساتذة يتبع حكمَ الجلسة نفسِه: `TakeTeacherAttendance`
                  // يرفض المقفلة كما يرفضها `TakeAttendance`.
                  editable: editable,
                  onStatus: (entry, status) =>
                      _setTeacherStatus(entry, status, editable),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        const Divider(height: 1),
        _ActionBar(
          session: session,
          editable: editable,
          canLock: canLock,
          dirty: dirty,
          saving: _saving,
          onSave: () => _save(session, canAmend: canAmend),
          onComplete: () => _confirmComplete(session, canAmend: canAmend),
          onLock: () => _confirmLock(session, canAmend: canAmend),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ التحرير

  void _setStatus(RosterEntry entry, AttendanceStatus status, bool editable) {
    if (!editable) {
      return;
    }

    final now = DateTime.now();
    final computed = status == AttendanceStatus.late
        ? LateMinutes.afterGrace(
            LateMinutes.forSession(
              shiftStartsAt: widget.circle.shiftStartsAt,
              sessionDate: _date,
              recordedAt: now,
            ),
            AppScope.of(context).session.graceMinutes,
          )
        : null;

    setState(() {
      _edits[entry.studentId] = entry.copyWith(
        status: status,
        origin: AttendanceOrigin.pending,
        // زمنُ الضغط لا زمنُ الحفظ ولا زمنُ الإرسال — به يحسم الخادمُ التعارض،
        // وهو ما تقيسه الخطوةُ 3 من السيناريو المرجعي حين يعدّل جهازان معاً.
        recordedAt: now,
        clearLateMinutes: true,
        lateMinutes: computed,
      );
    });
  }

  void _setTeacherStatus(
    TeacherRosterEntry entry,
    AttendanceStatus status,
    bool editable,
  ) {
    if (!editable) {
      return;
    }

    setState(() {
      _teacherEdits[entry.teacherId] = entry.copyWith(
        status: status,
        clearLateMinutes: status != AttendanceStatus.late,
      );
    });
  }

  Future<void> _editLateMinutes(RosterEntry entry) async {
    final controller = TextEditingController(
      text: entry.lateMinutes?.toString() ?? '',
    );

    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('دقائق تأخير ${entry.fullName}'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              helperText: 'اتركها فارغة ليحسبها الخادم من بداية الدوام',
              suffixText: 'دقيقة',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(-1),
            child: const Text('احسبها تلقائياً'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(int.tryParse(controller.text.trim()) ?? -1),
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
        title: Text('ملاحظة على ${entry.fullName}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
          ),
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
      _teacherEdits.clear();
    });
  }

  // ------------------------------------------------------------ الحفظ

  Future<void> _save(
    SessionView session, {
    required bool canAmend,
    bool andComplete = false,
    bool andLock = false,
  }) async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);
    final deps = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await deps.circles.saveAttendance(
        session: session,
        entries: [
          for (final entry in session.roster) _edits[entry.studentId] ?? entry,
        ],
        // التصحيحُ الرجعي يُعلَن لا يُستنتَج: جلسةٌ أُكملت ⇒ هذا الحفظ `amend`،
        // ولا يبلغ هذا السطرَ من لا يملك الصلاحية لأن `editable` منعته قبله.
        amend: session.isAmendment && canAmend,
      );

      if (_teacherEdits.isNotEmpty) {
        // تُقرأ الجلسة من جديد: الحفظُ قد يكون هو ما أنشأ صفَّ المسودّة المحلية،
        // فالمعرّفُ الذي يُعلَّق عليه تفقّدُ الأساتذة لم يكن موجوداً قبل السطر السابق.
        await deps.circles.saveTeacherAttendance(
          session: await _refresh(deps, session),
          entries: [
            for (final entry in session.teacherRoster)
              _teacherEdits[entry.teacherId] ?? entry,
          ],
        );
      }

      if (andComplete || andLock) {
        final refreshed = await _refresh(deps, session);

        if (andLock) {
          await deps.circles.lockSession(refreshed);
        } else {
          await deps.circles.completeSession(refreshed);
        }
      }

      _edits.clear();
      _teacherEdits.clear();
      deps.sync.syncNow();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            switch ((andLock, andComplete, session.isAmendment)) {
              (true, _, _) => 'قُفلت الجلسة نهائياً وصُفَّ القفل للمزامنة.',
              (_, true, _) => 'أُكملت الجلسة وصُفَّت للمزامنة.',
              (_, _, true) => 'صُفَّ التصحيح للمزامنة — تعديلٌ بعد الإقفال.',
              _ => 'حُفظ التفقّد محلياً وصُفَّ للمزامنة.',
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<SessionView> _refresh(AppDependencies deps, SessionView session) {
    return deps.circles.loadSession(
      circle: widget.circle,
      date: _date,
      graceMinutes: deps.session.graceMinutes,
      withTeachers: session.teacherRoster.isNotEmpty,
    );
  }

  Future<void> _confirmComplete(
    SessionView session, {
    required bool canAmend,
  }) async {
    final confirmed = await _confirm(
      title: 'إكمال الجلسة',
      body: canAmend
          ? 'الجلسةُ المكتملة تبقى قابلةً للتصحيح بصلاحيتك — والقفلُ وحده نهائي.'
          : 'بعد الإكمال لن تستطيع تعديل هذا التفقّد من هذا الحساب.',
      action: 'إكمال',
    );

    if (confirmed && mounted) {
      await _save(session, canAmend: canAmend, andComplete: true);
    }
  }

  Future<void> _confirmLock(
    SessionView session, {
    required bool canAmend,
  }) async {
    final confirmed = await _confirm(
      title: 'قفل الجلسة نهائياً',
      // القفلُ لا يُنقض: لا `attendance.amend` ولا إعادةُ فتحٍ تفتحه، فيُقال قبله
      // لا بعده.
      body: session.completed
          ? 'بعد القفل لا يعدّلها أحد ولا يعيد فتحها أحد — ولا صلاحيةَ تنقضه.'
          : 'ستُكمَل الجلسةُ ثم تُقفَل في دفعةٍ واحدة.\n'
              'وبعد القفل لا يعدّلها أحد ولا يعيد فتحها أحد.',
      action: 'قفل نهائي',
    );

    if (confirmed && mounted) {
      await _save(session, canAmend: canAmend, andLock: true);
    }
  }

  // ------------------------------------------------------------ التسميع والنقاط

  Future<void> _openProfile(RosterEntry entry) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentProfileScreen(studentId: entry.studentId),
      ),
    );
  }

  Future<void> _openRecitation(
    SessionView session,
    RosterEntry entry,
    RecitationEntry? recitation,
  ) {
    return showRecitationDialog(
      context: context,
      session: session,
      entry: entry,
      recitation: recitation,
    );
  }

  Future<void> _openPoints(
    SessionView session,
    RosterEntry entry,
    PointEntry? award,
  ) {
    return showPointsDialog(
      context: context,
      session: session,
      entry: entry,
      award: award,
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

    if (!await _confirm(
      title: 'حذف التسميع',
      body: 'سيُحذف «${recitation.rangeLabel}». لا يمكن التراجع بعد المزامنة.',
      action: 'حذف',
    )) {
      return;
    }

    await deps.circles.deleteRecitation(
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

    if (!await _confirm(
      title: 'حذف النقاط',
      body: 'سيُحذف «${pointsLabel(award)}». لا يمكن التراجع بعد المزامنة.',
      action: 'حذف',
    )) {
      return;
    }

    await deps.circles.deletePoints(
      session: session,
      studentId: entry.studentId,
      award: award,
    );

    deps.sync.syncNow();
    messenger.showSnackBar(
      const SnackBar(content: Text('حُذفت النقاط وصُفَّ الحذف للمزامنة.')),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 460, child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );

    return (confirmed ?? false) && mounted;
  }
}

// ---------------------------------------------------------------- المكوّنات

class _DateBar extends StatelessWidget {
  const _DateBar({required this.date, required this.onPick});

  final DateTime date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          const Icon(Icons.event_outlined, size: 18),
          Text(DateFormat('EEEE، d MMMM y', 'ar').format(date)),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('تغيير اليوم'),
          ),
        ],
      ),
    );
  }
}

/// ملخّصُ الكشف وحالتُه — وبانرُ الجلسة غير القابلة للتحرير.
class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.roster,
    required this.editable,
    required this.canAmend,
  });

  final SessionView session;
  final List<RosterEntry> roster;
  final bool editable;
  final bool canAmend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Count(
                status: BadgeStatus.present,
                count: _countOf(AttendanceStatus.present),
              ),
              _Count(
                status: BadgeStatus.absent,
                count: _countOf(AttendanceStatus.absent),
              ),
              _Count(
                status: BadgeStatus.late,
                count: _countOf(AttendanceStatus.late),
              ),
              _Count(
                status: BadgeStatus.excused,
                count: _countOf(AttendanceStatus.excused),
              ),
              Text(
                'المجموع ${roster.length}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          if (session.locked || (session.completed && !editable))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _Banner(
                icon: Icons.lock_outline,
                message: session.locked
                    ? 'الجلسة مقفلة نهائياً — لا تُعدَّل ولا يُعاد فتحها.'
                    : 'الجلسة مكتملة، وتعديلُها يحتاج صلاحية «التصحيح الرجعي».',
              ),
            )
          else if (session.completed && canAmend)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _Banner(
                icon: Icons.history_edu_outlined,
                // بانرٌ لا مجرّد سماحٍ صامت: من يعدّل جلسةً أُكملت يجب أن يعرف
                // أنه يصحّح رجعياً لا يتفقّد اليوم.
                message: 'تصحيحٌ رجعي: هذه الجلسة أُكملت، وما تحفظه الآن يُرسَل '
                    'بعلامة «تعديلٍ بعد الإقفال».',
                accent: true,
              ),
            ),
        ],
      ),
    );
  }

  int _countOf(AttendanceStatus status) =>
      roster.where((entry) => entry.status == status).length;
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    this.accent = false,
  });

  final IconData icon;
  final String message;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, size: 18, color: color),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.status, required this.count});

  final BadgeStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        AttendanceStatusBadge(status: status),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

/// صفُّ طالبٍ واحد — الحالةُ ضغطةٌ واحدة، وما تحتها ما سُجّل له في الجلسة.
class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.entry,
    required this.editable,
    required this.onStatus,
    required this.onProfile,
    required this.onRecitation,
    required this.onDeleteRecitation,
    required this.onPoint,
    required this.onDeletePoint,
    required this.onLate,
    required this.onNote,
  });

  final RosterEntry entry;
  final bool editable;
  final ValueChanged<AttendanceStatus> onStatus;
  final VoidCallback onProfile;
  final ValueChanged<RecitationEntry?> onRecitation;
  final ValueChanged<RecitationEntry> onDeleteRecitation;
  final ValueChanged<PointEntry?> onPoint;
  final ValueChanged<PointEntry> onDeletePoint;
  final VoidCallback onLate;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: onProfile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            entry.fullName,
                            style: theme.textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.origin == AttendanceOrigin.pending)
                          Tooltip(
                            message: 'كتابةٌ لم تصل الخادم بعد',
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else if (entry.origin == AttendanceOrigin.suggested)
                          Tooltip(
                            message: 'قيمةٌ مقترحة لم يؤكّدها أحد',
                            child: Icon(
                              Icons.help_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              _StatusPicker(
                status: entry.status,
                editable: editable,
                onChanged: onStatus,
              ),
              SizedBox(
                width: 90,
                child: entry.status == AttendanceStatus.late
                    ? TextButton(
                        onPressed: editable ? onLate : null,
                        child: Text('${entry.lateMinutes ?? 0} د'),
                      )
                    : const SizedBox.shrink(),
              ),
              _RowMenu(
                editable: editable,
                onProfile: onProfile,
                onRecitation: () => onRecitation(null),
                onPoints: () => onPoint(null),
                onNote: onNote,
              ),
            ],
          ),
          if (entry.note != null || entry.recitations.isNotEmpty ||
              entry.points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (entry.note != null)
                    Chip(
                      avatar: const Icon(Icons.sticky_note_2_outlined, size: 16),
                      label: Text(entry.note!),
                      visualDensity: VisualDensity.compact,
                    ),
                  for (final recitation in entry.recitations)
                    InputChip(
                      avatar: const Icon(
                        Icons.record_voice_over_outlined,
                        size: 16,
                      ),
                      label: Text(
                        '${recitationTypeLabels[recitation.type]} · '
                        '${recitation.rangeLabel}'
                        '${recitation.pending ? ' (بانتظار المزامنة)' : ''}',
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRecitation(recitation),
                      onDeleted: () => onDeleteRecitation(recitation),
                    ),
                  for (final award in entry.points)
                    InputChip(
                      avatar: const Icon(Icons.star_outline, size: 16),
                      label: Text(
                        '${pointsLabel(award)}'
                        '${award.pending ? ' (بانتظار المزامنة)' : ''}',
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onPoint(award),
                      onDeleted: () => onDeletePoint(award),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

/// أربعُ حالاتٍ ظاهرةٌ معاً — لا قائمةٌ منسدلة.
///
/// الشاشةُ عريضة، والمشرفُ يمرّ على عشرين طالباً: ضغطةٌ واحدة لكلٍّ أسرعُ من
/// فتحِ قائمةٍ واختيارٍ وإغلاق.
class _StatusPicker extends StatelessWidget {
  const _StatusPicker({
    required this.status,
    required this.editable,
    required this.onChanged,
  });

  final AttendanceStatus status;
  final bool editable;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AttendanceStatus>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: AttendanceStatus.present, label: Text('حاضر')),
        ButtonSegment(value: AttendanceStatus.absent, label: Text('غائب')),
        ButtonSegment(value: AttendanceStatus.late, label: Text('متأخر')),
        ButtonSegment(value: AttendanceStatus.excused, label: Text('مأذون')),
      ],
      selected: {status},
      onSelectionChanged: editable ? (values) => onChanged(values.first) : null,
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.editable,
    required this.onProfile,
    required this.onRecitation,
    required this.onPoints,
    required this.onNote,
  });

  final bool editable;
  final VoidCallback onProfile;
  final VoidCallback onRecitation;
  final VoidCallback onPoints;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_outline, size: 18),
          onPressed: onProfile,
          child: const Text('ملف الطالب'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.record_voice_over_outlined, size: 18),
          onPressed: onRecitation,
          child: const Text('تسجيل تسميع'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.star_outline, size: 18),
          onPressed: onPoints,
          child: const Text('منح نقاط'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.sticky_note_2_outlined, size: 18),
          onPressed: editable ? onNote : null,
          child: const Text('ملاحظة'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'إجراءات',
        icon: const Icon(Icons.more_horiz),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// كشفُ تفقّد الأساتذة — قسمٌ ثانٍ تحت كشف الطلاب لا عمودٌ فيه.
///
/// والفصلُ ليس تنظيماً بصرياً: حضورُ الأستاذ **لا يدخل** في نسبة الحلقة ولا في
/// ترتيبها، فجدولُه منفصل على الخادم وفعلُه منفصل — وخلطُهما في كشفٍ واحد كان
/// يوحي بأن غيابَ الأستاذ غيابٌ في الإحصاء.
class _TeacherSection extends StatelessWidget {
  const _TeacherSection({
    required this.entries,
    required this.editable,
    required this.onStatus,
  });

  final List<TeacherRosterEntry> entries;
  final bool editable;
  final void Function(TeacherRosterEntry, AttendanceStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(Icons.co_present_outlined, size: 18),
              Text('تفقّد الأساتذة', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'لا أستاذ مسنَدٌ إلى هذه الحلقة.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: Text(
                              entry.fullName,
                              style: theme.textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            entry.roleLabel,
                            style: theme.textTheme.labelSmall,
                          ),
                          if (!entry.recorded)
                            Tooltip(
                              // لا حضورَ بالسكوت: الخادم يزرع صفوف الطلاب عند
                              // فتح الجلسة ولا يزرع للأساتذة شيئاً.
                              message: 'لم يُسجَّل بعد',
                              child: Icon(
                                Icons.radio_button_unchecked,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          else if (entry.pending)
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                    _StatusPicker(
                      status: entry.status,
                      editable: editable,
                      onChanged: (status) => onStatus(entry, status),
                    ),
                    const SizedBox(width: 90),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// شريطُ الأفعال أسفل الشاشة — والقفلُ فيه **لا يظهر لمن لا يملكه**.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.session,
    required this.editable,
    required this.canLock,
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onComplete,
    required this.onLock,
  });

  final SessionView session;
  final bool editable;
  final bool canLock;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onComplete;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    if (!editable && !canLock) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 8,
        children: [
          if (editable)
            Expanded(
              child: FilledButton.icon(
                onPressed: saving || !(dirty || !session.exists) ? null : onSave,
                icon: const Icon(Icons.save_outlined),
                // «فتح الجلسة» و«حفظ» فعلٌ واحد: الفتحُ يصفّ
                // `attendance.session.open` وحدها، والحفظُ يُتبعها
                // `attendance.take` بنفس الطابور وبنفس الترتيب.
                label: Text(
                  switch ((session.exists, session.isAmendment)) {
                    (false, _) => 'فتح الجلسة وحفظ التفقّد',
                    (_, true) => 'حفظ التصحيح',
                    _ => 'حفظ التفقّد',
                  },
                ),
              ),
            )
          else
            const Spacer(),
          if (editable && !session.completed)
            OutlinedButton.icon(
              onPressed: saving ? null : onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('إكمال'),
            ),
          // ما لا يملكه المستخدم لا يظهر أصلاً — نفسُ قاعدة القائمة الجانبية
          // ([CHECKPOINT-PHASE-6.3.MD §6]). والمقفلةُ لا تُقفل مرّتين.
          if (canLock && !session.locked)
            OutlinedButton.icon(
              onPressed: saving || !session.exists ? null : onLock,
              icon: const Icon(Icons.lock_outline),
              label: const Text('قفل نهائي'),
            ),
        ],
      ),
    );
  }
}

/// `+2 مشاركة` أو `-1.5 سلوك` — الإشارة جزءٌ من المعنى، فالخصم يُقرأ خصماً.
String pointsLabel(PointEntry award) {
  final value = award.points == award.points.roundToDouble()
      ? '${award.points.round()}'
      : award.points.toStringAsFixed(1);

  return '${award.points > 0 ? '+' : ''}$value '
      '${pointsReasonLabels[award.reason] ?? ''}';
}
