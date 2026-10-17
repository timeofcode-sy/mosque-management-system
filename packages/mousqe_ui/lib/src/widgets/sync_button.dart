import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import 'sync_bar.dart';

/// حالةُ المزامنة كما يعرضها [SyncButton] و[SyncPanel] — قيمٌ جاهزة بلا محرّك، يبنيها التطبيق
/// من `SyncController` كما يبني [SyncBar].
class SyncSnapshot {
  const SyncSnapshot({
    required this.pendingCount,
    required this.isSyncing,
    this.failures = const [],
    this.lastPulledAt,
    this.errorMessage,
    this.offline = false,
  });

  final int pendingCount;
  final bool isSyncing;
  final List<SyncFailureView> failures;
  final DateTime? lastPulledAt;

  /// خطأٌ **من الخادم** — انقطاعُ الشبكة يُعرض بـ[offline].
  final String? errorMessage;
  final bool offline;

  SyncTone get tone {
    if (failures.isNotEmpty || errorMessage != null) {
      return SyncTone.problem;
    }

    if (isSyncing) {
      return SyncTone.syncing;
    }

    if (offline) {
      return SyncTone.offline;
    }

    return pendingCount > 0 ? SyncTone.pending : SyncTone.synced;
  }

  /// سطرٌ واحد يقول الحال — تلميحُ الزر وعنوانُ الورقة.
  String get headline => switch (tone) {
        SyncTone.problem when failures.isNotEmpty =>
          '${failures.length} عملية رفضها الخادم',
        SyncTone.problem => 'تعذّرت المزامنة',
        SyncTone.syncing => 'جارٍ المزامنة…',
        SyncTone.offline when pendingCount > 0 =>
          'دون اتصال · $pendingCount بانتظار المزامنة',
        SyncTone.offline => 'دون اتصال',
        SyncTone.pending => '$pendingCount عملية بانتظار المزامنة',
        SyncTone.synced => 'كل التغييرات مُزامَنة',
      };
}

/// خمسُ حالاتٍ لكلٍّ أيقونتُها ولونُها — فلا يكفي اللونُ وحده.
enum SyncTone { synced, pending, syncing, offline, problem }

/// زرُّ المزامنة في الشريط العلوي: يحلّ محلّ شريط المزامنة على الهاتف فلا يأكل من الشاشة شيئاً.
///
/// يتبدّل شكلُه بالحال — ✓ أخضر حين يُزامَن كلُّ شيء، وسهمان يدوران أثناء المزامنة، وعدّادٌ
/// بلون التنبيه لما ينتظر، وأيقونةُ «دون اتصال»، وتنبيهٌ أحمر لما رفضه الخادم — والضغطُ يفتح
/// التفصيل ([SyncPanel]).
class SyncButton extends StatefulWidget {
  const SyncButton({super.key, required this.snapshot, required this.onOpen});

  final SyncSnapshot snapshot;
  final VoidCallback onOpen;

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(SyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    final spinning = widget.snapshot.isSyncing &&
        !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

    if (spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!spinning && _spin.isAnimating) {
      // الدورةُ تُكمل نفسها ولا تقف مائلة.
      _spin.forward(from: _spin.value).then((_) {
        if (mounted) {
          _spin.value = 0;
        }
      });
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final snapshot = widget.snapshot;
    final tone = snapshot.tone;
    final (icon, color) = _look(c, tone);
    final count = snapshot.failures.isNotEmpty
        ? snapshot.failures.length
        : snapshot.pendingCount;
    final badge = tone != SyncTone.synced && count > 0;

    return Tooltip(
      message: snapshot.headline,
      child: Semantics(
        button: true,
        label: 'المزامنة: ${snapshot.headline}',
        excludeSemantics: true,
        child: InkResponse(
          onTap: widget.onOpen,
          radius: 24,
          child: SizedBox.square(
            dimension: NzSize.touchTarget,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(icon),
                    child: tone == SyncTone.syncing
                        ? RotationTransition(
                            // عكسَ عقارب الساعة: سهما الأيقونة يدوران في اتجاههما.
                            turns: Tween(begin: 0.0, end: -1.0).animate(_spin),
                            child: NzIcon(icon, size: 22, color: color),
                          )
                        : NzIcon(icon, size: 22, color: color),
                  ),
                ),
                PositionedDirectional(
                  top: 6,
                  end: 4,
                  child: AnimatedScale(
                    scale: badge ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: _Badge(
                      count: count,
                      color: tone == SyncTone.problem ? c.danger : c.warning,
                      onColor: c.surfaceRaised,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color, required this.onColor});

  final int count;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: onColor, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: NzType.caption.copyWith(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: onColor,
        ),
      ),
    );
  }
}

(String, Color) _look(NzColorTokens c, SyncTone tone) => switch (tone) {
      SyncTone.synced => (NzIcons.checkCircle, c.success),
      SyncTone.pending => (NzIcons.review, c.warning),
      SyncTone.syncing => (NzIcons.review, c.primary),
      SyncTone.offline => (NzIcons.offline, c.info),
      SyncTone.problem => (NzIcons.warning, c.danger),
    };

/// يفتح تفصيلَ المزامنة في ورقةٍ سفلية. [builder] يبني [SyncPanel] من مصدر التطبيق نفسه فتبقى
/// الورقةُ حيّةً بينما تجري المزامنة.
Future<void> showSyncSheet(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(child: builder(sheet)),
  );
}

/// تفصيلُ المزامنة: الحالُ وآخرُ مزامنة، و«زامن الآن»، وما رفضه الخادم بأفعاله.
class SyncPanel extends StatelessWidget {
  const SyncPanel({
    super.key,
    required this.snapshot,
    required this.onSync,
    this.onRetryFailure,
    this.onDiscardFailure,
  });

  final SyncSnapshot snapshot;
  final VoidCallback onSync;
  final void Function(String opUuid)? onRetryFailure;
  final void Function(String opUuid)? onDiscardFailure;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final tone = snapshot.tone;
    final (icon, color) = _look(c, tone);
    final at = snapshot.lastPulledAt;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(NzSpace.s4, 0, NzSpace.s4, NzSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NzRadius.md),
                  ),
                  child: snapshot.isSyncing
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: color),
                        )
                      : NzIcon(icon, size: 24, color: color),
                ),
                const SizedBox(width: NzSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المزامنة', style: NzType.caption.copyWith(color: c.inkMuted)),
                      Text(
                        snapshot.headline,
                        style: NzType.title.copyWith(color: c.ink, fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: NzSpace.s3),
            _Line(
              icon: NzIcons.clock,
              text: at == null
                  ? 'لم تكتمل مزامنةٌ بعد'
                  : 'آخر مزامنة ${DateFormat('yyyy-MM-dd HH:mm').format(at.toLocal())}',
            ),
            if (snapshot.offline)
              const _Line(
                icon: NzIcons.offline,
                text: 'تعمل دون اتصال. ما تسجّله محفوظٌ على الجهاز ويُزامَن وحده حين يعود الاتصال.',
              ),
            if (snapshot.errorMessage != null)
              _Line(icon: NzIcons.exclamationCircle, text: snapshot.errorMessage!, danger: true),
            if (snapshot.failures.isNotEmpty) ...[
              const SizedBox(height: NzSpace.s3),
              Container(
                padding: const EdgeInsets.all(NzSpace.s3),
                decoration: BoxDecoration(
                  color: c.dangerSoft,
                  borderRadius: BorderRadius.circular(NzRadius.sm),
                ),
                child: Text(
                  'لا تُحذف ولا يُعاد إرسالها تلقائياً: تكرارُ إرسالها لا يجعلها مقبولة. '
                  'أصلِح السبب ثم أعِد المحاولة، أو تخلَّ عنها.',
                  style: NzType.caption.copyWith(color: c.danger),
                ),
              ),
              for (final failure in snapshot.failures)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(failure.type, style: NzType.label.copyWith(color: c.ink)),
                  subtitle: Text(failure.reason),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onRetryFailure != null)
                        IconButton(
                          tooltip: 'أعِد المحاولة',
                          onPressed: () => onRetryFailure!(failure.opUuid),
                          icon: const NzIcon(NzIcons.review),
                        ),
                      if (onDiscardFailure != null)
                        IconButton(
                          tooltip: 'تخلَّ عنها',
                          onPressed: () => onDiscardFailure!(failure.opUuid),
                          icon: const NzIcon(NzIcons.trash),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: NzSpace.s4),
            FilledButton.icon(
              onPressed: snapshot.isSyncing ? null : onSync,
              icon: const NzIcon(NzIcons.review, size: 20),
              label: Text(snapshot.isSyncing ? 'جارٍ المزامنة…' : 'زامن الآن'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.danger = false});

  final String icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final color = danger ? c.danger : c.inkMuted;

    return Padding(
      padding: const EdgeInsets.only(top: NzSpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: NzIcon(icon, size: 16, color: color),
          ),
          const SizedBox(width: NzSpace.s2),
          Expanded(child: Text(text, style: NzType.caption.copyWith(color: color))),
        ],
      ),
    );
  }
}
