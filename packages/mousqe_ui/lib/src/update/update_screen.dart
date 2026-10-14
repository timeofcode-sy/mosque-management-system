import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import '../brand/brand.dart';
import 'app_update_info.dart';
import 'app_updater.dart';
import 'download_strokes.dart';
import 'update_gate.dart';

/// يفتح شاشةَ التحديث فوق المكدّس الجذري — من القائمة «حول»، أو تلقائياً لإصدارٍ اختياري.
Future<void> openUpdateScreen(BuildContext context) {
  final scope = AppUpdateScope.read(context);

  if (scope == null) {
    return Future.value();
  }

  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          UpdateScreen(updater: scope.updater, appName: scope.appName),
    ),
  );
}

/// شاشةُ التحديث: على أرضية الليل المنقوشة، العلامةُ ثم الانتقالُ من النسخة الحالية إلى الجديدة،
/// وتحتها بطاقةٌ تتبدّل بمرحلة التحديث — المتاح وسجلُّ تغييراته، فالتنزيلُ بخطوطه الثلاثين،
/// فالإذن، فالتثبيت.
///
/// [dismissible] = false للإصدار الإلزامي: لا زرَّ إغلاق ولا رجوع.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({
    super.key,
    required this.updater,
    this.appName = Brand.name,
    this.dismissible = true,
  });

  final AppUpdater updater;
  final String appName;
  final bool dismissible;

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  AppUpdater get _updater => widget.updater;

  @override
  void initState() {
    super.initState();

    // فُتحت من القائمة دون إصدارٍ معروف: تسأل الخادمَ الآن ويرى صاحبُها الجواب.
    if (!_updater.hasUpdate && !_updater.isBusy) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updater.check(manual: true),
      );
    }
  }

  bool get _canClose =>
      widget.dismissible &&
      !_updater.isMandatory &&
      _updater.stage != UpdateStage.installing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _updater,
      builder: (context, _) => PopScope(
        canPop: _canClose,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Material(
            color: Brand.ground,
            child: NzPattern(
              // النقشُ يحفّ العلامةَ في الأعلى ويخفت تحت البطاقة، فلا يزاحم ما يُقرأ.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.4, 0.85],
                    colors: [
                      Brand.ground.withValues(alpha: 0),
                      Brand.ground.withValues(alpha: 0.55),
                      Brand.ground.withValues(alpha: 0.94),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: _canClose
                                  ? IconButton(
                                      tooltip: 'إغلاق',
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: const NzIcon(
                                        NzIcons.close,
                                        color: NzBrand.star,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                NzSpace.s4,
                                0,
                                NzSpace.s4,
                                NzSpace.s5,
                              ),
                              child: Column(
                                children: [
                                  _Hero(updater: _updater),
                                  const SizedBox(height: NzSpace.s5),
                                  _Card(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: SizeTransition(
                                              sizeFactor: animation,
                                              alignment: Alignment.topCenter,
                                              child: child,
                                            ),
                                          ),
                                      child: KeyedSubtree(
                                        key: ValueKey(_phase),
                                        child: _body(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NzSpace.s4),
                                  Text(
                                    _footer,
                                    textAlign: TextAlign.center,
                                    style: NzType.caption.copyWith(
                                      color: NzBrand.bronze,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// مراحلُ متقاربة تتشارك جسماً واحداً، فلا يومض التبديلُ بين «ينزّل» و«يتحقّق».
  String get _phase => switch (_updater.stage) {
    UpdateStage.downloading || UpdateStage.verifying => 'download',
    UpdateStage.ready || UpdateStage.installing => 'ready',
    UpdateStage.idle || UpdateStage.checking => 'checking',
    final stage => stage.name,
  };

  String get _footer => switch (_updater.stage) {
    UpdateStage.downloading ||
    UpdateStage.verifying => 'يُرجى إبقاءُ التطبيق مفتوحاً حتى يكتمل التنزيل',
    _ => '${Brand.name} · ${Brand.domain}',
  };

  Widget _body(BuildContext context) {
    final updater = _updater;

    return switch (updater.stage) {
      UpdateStage.idle || UpdateStage.checking => const _Status(
        icon: null,
        title: 'نتحقّق من وجود تحديث…',
      ),
      UpdateStage.upToDate => _Status(
        icon: NzIcons.checkCircle,
        tone: _Tone.success,
        title: 'تطبيقك محدَّث',
        body: updater.installed == null
            ? 'لا إصدارَ أحدث من نسختك.'
            : 'الإصدار ${ltr(updater.installed!.version)} هو الأحدث.',
        action: widget.dismissible
            ? FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('تم'),
              )
            : null,
      ),
      UpdateStage.available => _Available(
        updater: updater,
        appName: widget.appName,
        onLater: _canClose
            ? () async {
                await updater.snooze();
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              }
            : null,
      ),
      UpdateStage.downloading ||
      UpdateStage.verifying => _Downloading(updater: updater),
      UpdateStage.needsPermission => _Permission(
        updater: updater,
        appName: widget.appName,
      ),
      UpdateStage.ready || UpdateStage.installing => _Ready(updater: updater),
      UpdateStage.failed => _Status(
        icon: NzIcons.exclamationCircle,
        tone: _Tone.danger,
        title: 'لم يكتمل التحديث',
        body: updater.error ?? 'حدث خطأ غير متوقّع.',
        action: FilledButton.icon(
          onPressed: updater.hasUpdate
              ? updater.download
              : () => updater.check(manual: true),
          icon: const NzIcon(NzIcons.undo, size: 18),
          label: const Text('إعادة المحاولة'),
        ),
      ),
    };
  }
}

/// العلامةُ في سداسيّها، والعنوان، والانتقالُ من النسخة الحالية إلى الجديدة.
class _Hero extends StatelessWidget {
  const _Hero({required this.updater});

  final AppUpdater updater;

  @override
  Widget build(BuildContext context) {
    final installed = updater.installed?.version;
    final next = updater.info?.version;

    return Column(
      children: [
        ClipPath(
          clipper: const _HexagonClipper(),
          child: Container(
            width: 112,
            height: 128,
            color: NzBrand.nightRaised,
            alignment: Alignment.center,
            child: const BrandGlyph(height: 76),
          ),
        ),
        const SizedBox(height: NzSpace.s4),
        Text(
          'تحديث التطبيق',
          style: NzType.display3.copyWith(color: NzBrand.star),
          textAlign: TextAlign.center,
        ),
        if (installed != null || next != null) ...[
          const SizedBox(height: NzSpace.s2),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: NzSpace.s2,
            children: [
              if (installed != null)
                Text(
                  ltr(installed),
                  style: NzType.label.copyWith(
                    color: NzBrand.star.withValues(alpha: 0.7),
                  ),
                ),
              if (installed != null && next != null)
                const NzIcon(
                  NzIcons.arrowLeft,
                  size: 16,
                  color: NzBrand.bronze,
                ),
              if (next != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NzSpace.s2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: NzBrand.bronze.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(NzRadius.sm),
                  ),
                  child: Text(
                    ltr(next),
                    style: NzType.label.copyWith(
                      color: NzBrand.bronze,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// البطاقةُ البيضاء (الليلية في الوضع الداكن)، وعلى رأسها خطُّ النحاس.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(NzRadius.md),
        border: Border.all(color: c.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NzRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 3, color: NzBrand.bronze),
            Padding(padding: const EdgeInsets.all(NzSpace.s5), child: child),
          ],
        ),
      ),
    );
  }
}

class _Available extends StatelessWidget {
  const _Available({
    required this.updater,
    required this.appName,
    this.onLater,
  });

  final AppUpdater updater;
  final String appName;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final info = updater.info!;
    final size = info.size;
    final hasNotes = info.changes.any((change) => change.notes.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            NzTag(
              info.mandatory ? 'تحديث إلزامي' : 'إصدار جديد',
              bronze: !info.mandatory,
              icon: info.mandatory ? NzIcons.lockClosed : NzIcons.star,
            ),
            const Spacer(),
            if (size != null)
              Text(
                ltr(formatBytes(size)),
                style: NzType.caption.copyWith(color: c.inkMuted),
              ),
          ],
        ),
        const SizedBox(height: NzSpace.s3),
        Text(
          info.title ?? 'إصدارٌ جديد من $appName',
          style: NzType.title.copyWith(color: c.ink),
        ),
        if (info.mandatory) ...[
          const SizedBox(height: NzSpace.s3),
          _Notice(
            tone: _Tone.warning,
            icon: NzIcons.warning,
            text: 'لا يعمل التطبيق على نسختك الحالية حتى تحدّثه. بياناتك تبقى كما هي.',
          ),
        ],
        const SizedBox(height: NzSpace.s4),
        Text(
          'ما الجديد',
          style: NzType.label.copyWith(
            color: c.bronzeInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: NzSpace.s2),
        if (!hasNotes)
          Text('تحسيناتٌ وإصلاحات.', style: NzType.body.copyWith(color: c.ink))
        else
          for (final (index, change) in info.changes.indexed)
            if (change.notes.isNotEmpty)
              _ChangeBlock(
                change: change,
                showHeader: info.changes.length > 1,
                first: index == 0,
              ),
        const SizedBox(height: NzSpace.s5),
        FilledButton.icon(
          onPressed: updater.download,
          icon: const NzIcon(NzIcons.download, size: 20),
          label: const Text('تحديث الآن'),
        ),
        if (onLater != null) ...[
          const SizedBox(height: NzSpace.s2),
          TextButton(onPressed: onLater, child: const Text('لاحقاً')),
        ],
        const SizedBox(height: NzSpace.s2),
        Text(
          'يُنزَّل التحديث ويُثبَّت من داخل التطبيق، دون متصفّح ولا ملفّاتٍ تبحث عنها.',
          textAlign: TextAlign.center,
          style: NzType.caption.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

/// إصدارٌ في سجلّ التغييرات: رقمُه (إن فات الجهازَ أكثرُ من واحد) ثم بنودُه بمعيّناتٍ نحاسية.
class _ChangeBlock extends StatelessWidget {
  const _ChangeBlock({
    required this.change,
    required this.showHeader,
    required this.first,
  });

  final ReleaseChange change;
  final bool showHeader;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : NzSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: NzSpace.s1),
              child: Text(
                [
                  'الإصدار ${ltr(change.version)}',
                  if (change.title != null) change.title!,
                ].join(' · '),
                style: NzType.caption.copyWith(
                  color: c.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final note in change.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: NzSpace.s1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 6,
                        height: 6,
                        color: c.progressCurrent,
                      ),
                    ),
                  ),
                  const SizedBox(width: NzSpace.s3),
                  Expanded(
                    child: Text(
                      note,
                      style: NzType.body.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Downloading extends StatelessWidget {
  const _Downloading({required this.updater});

  final AppUpdater updater;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final progress = updater.progress ?? const DownloadProgress(received: 0);
    final verifying = updater.stage == UpdateStage.verifying;
    final fraction = verifying ? 1.0 : progress.fraction;
    final percent = fraction == null ? null : (fraction * 100).floor();
    final total = progress.total;
    final remaining = progress.remaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verifying ? 'نتحقّق من سلامة الملف' : 'جارٍ تنزيل التحديث',
                    style: NzType.title.copyWith(color: c.ink),
                  ),
                  Text(
                    total == null
                        ? ltr(formatBytes(progress.received))
                        : '${ltr(formatBytes(progress.received))} من ${ltr(formatBytes(total))}',
                    style: NzType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            if (verifying)
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: c.primary,
                ),
              )
            else if (percent != null)
              Text(
                '$percent%',
                textDirection: TextDirection.ltr,
                style: NzType.display2.copyWith(color: c.primary, height: 1.1),
              ),
          ],
        ),
        const SizedBox(height: NzSpace.s4),
        DownloadStrokes(
          fraction: fraction,
          active: !verifying,
          semanticLabel: percent == null
              ? 'جارٍ التنزيل'
              : 'نُزّل $percent بالمئة',
        ),
        const SizedBox(height: NzSpace.s4),
        Row(
          children: [
            Expanded(
              child: _Stat(
                icon: NzIcons.trend,
                label: 'السرعة',
                value: verifying || progress.bytesPerSecond < 1
                    ? '—'
                    : ltr('${formatBytes(progress.bytesPerSecond.round())}/s'),
              ),
            ),
            const SizedBox(width: NzSpace.s3),
            Expanded(
              child: _Stat(
                icon: NzIcons.clock,
                label: 'المتبقّي',
                value: verifying || remaining == null
                    ? '—'
                    : ltr(formatDuration(remaining)),
              ),
            ),
          ],
        ),
        const SizedBox(height: NzSpace.s4),
        OutlinedButton.icon(
          onPressed: verifying ? null : updater.cancel,
          icon: const NzIcon(NzIcons.pause, size: 18),
          label: const Text('إيقاف مؤقّت'),
        ),
        const SizedBox(height: NzSpace.s2),
        Text(
          'إن انقطع الاتصال يُستأنف التنزيل من حيث وقف.',
          textAlign: TextAlign.center,
          style: NzType.caption.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NzSpace.s3,
        vertical: NzSpace.s2,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(NzRadius.sm),
      ),
      child: Row(
        children: [
          NzIcon(icon, size: 18, color: c.bronzeInk),
          const SizedBox(width: NzSpace.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: NzType.caption.copyWith(color: c.inkMuted)),
                Text(
                  value,
                  style: NzType.label.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({required this.updater, required this.appName});

  final AppUpdater updater;
  final String appName;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    const steps = [
      'اضغط «فتح الإعدادات».',
      'فعّل «السماح من هذا المصدر».',
      'ارجع إلى التطبيق — يبدأ التثبيت وحده.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Status(
          icon: NzIcons.shield,
          tone: _Tone.bronze,
          title: 'خطوةٌ واحدة قبل التثبيت',
          body:
              'اكتمل التنزيل. يطلب أندرويد إذنك مرّةً واحدة ليثبّت $appName تحديثاتِه بنفسه.',
        ),
        const SizedBox(height: NzSpace.s4),
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: NzSpace.s2),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.bronzeSoft,
                    borderRadius: BorderRadius.circular(NzRadius.sm),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: NzType.label.copyWith(
                      color: c.bronzeInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: NzSpace.s3),
                Expanded(
                  child: Text(step, style: NzType.body.copyWith(color: c.ink)),
                ),
              ],
            ),
          ),
        const SizedBox(height: NzSpace.s3),
        FilledButton.icon(
          onPressed: updater.openInstallSettings,
          icon: const NzIcon(NzIcons.settings, size: 20),
          label: const Text('فتح الإعدادات'),
        ),
      ],
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.updater});

  final AppUpdater updater;

  @override
  Widget build(BuildContext context) {
    final windows = updater.installKind == UpdateInstallKind.windows;
    final installing = updater.stage == UpdateStage.installing;

    return _Status(
      icon: NzIcons.checkCircle,
      tone: _Tone.success,
      title: installing
          ? (windows ? 'يُعاد تشغيل البرنامج…' : 'أكمل التثبيت')
          : 'اكتمل التنزيل',
      body: switch ((windows, installing)) {
        (true, true) => 'يُغلق البرنامج ويُحدَّث ثم يعود وحده خلال ثوانٍ.',
        (true, false) =>
          'تحقّقنا من سلامة الملف. يُغلق البرنامج ويُحدَّث ثم يعود وحده.',
        (false, true) =>
          'اضغط «تحديث» في نافذة النظام. يُغلق التطبيق ويعود بالإصدار الجديد.',
        (false, false) =>
          'تحقّقنا من سلامة الملف. ثبّته الآن، وتبقى بياناتك كما هي.',
      },
      action: windows && installing
          ? null
          : FilledButton.icon(
              onPressed: updater.install,
              icon: const NzIcon(NzIcons.check, size: 20),
              label: Text(
                windows
                    ? 'تحديث وإعادة التشغيل'
                    : (installing ? 'فتح المثبّت مجدّداً' : 'تثبيت الآن'),
              ),
            ),
    );
  }
}

enum _Tone { success, warning, danger, bronze }

/// حالةٌ بأيقونةٍ في سداسيّ، وعنوانٍ وسطر — ثم فعلٌ إن كان.
class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.title,
    this.tone = _Tone.bronze,
    this.body,
    this.action,
  });

  /// `null`: مؤشّرُ انتظار.
  final String? icon;
  final _Tone tone;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final (fill, ink) = _colors(c, tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipPath(
            clipper: const _HexagonClipper(),
            child: Container(
              width: 64,
              height: 74,
              color: fill,
              alignment: Alignment.center,
              child: icon == null
                  ? SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ink,
                      ),
                    )
                  : NzIcon(icon!, size: 30, color: ink),
            ),
          ),
        ),
        const SizedBox(height: NzSpace.s3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: NzType.title.copyWith(color: c.ink),
        ),
        if (body != null) ...[
          const SizedBox(height: NzSpace.s1),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: NzType.body.copyWith(color: c.inkMuted),
          ),
        ],
        if (action != null) ...[const SizedBox(height: NzSpace.s5), action!],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.tone, required this.icon, required this.text});

  final _Tone tone;
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = _colors(context.nz, tone);

    return Container(
      padding: const EdgeInsets.all(NzSpace.s3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(NzRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NzIcon(icon, size: 20, color: ink),
          const SizedBox(width: NzSpace.s2),
          Expanded(
            child: Text(text, style: NzType.label.copyWith(color: ink)),
          ),
        ],
      ),
    );
  }
}

(Color, Color) _colors(NzColorTokens c, _Tone tone) => switch (tone) {
  _Tone.success => (c.successSoft, c.success),
  _Tone.warning => (c.warningSoft, c.warning),
  _Tone.danger => (c.dangerSoft, c.danger),
  _Tone.bronze => (c.bronzeSoft, c.bronzeInk),
};

/// سداسيُّ الشعار — شكلُ الصورة الرمزية في الهوية.
class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height * 0.21)
    ..lineTo(size.width, size.height * 0.79)
    ..lineTo(size.width / 2, size.height)
    ..lineTo(0, size.height * 0.79)
    ..lineTo(0, size.height * 0.21)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// يعزل نصّاً لاتينياً (رقمَ إصدار، حجماً) داخل سطرٍ عربي فلا تنقلب أجزاؤه:
/// «38.2 MB من 5.1 MB» لا «MB / 38.2 MB 5.1».
String ltr(String text) => '$_isolate$text$_popIsolate';

/// LEFT-TO-RIGHT ISOLATE و POP DIRECTIONAL ISOLATE — من رقمَيهما لا محرفَين خفيّين في المصدر.
final String _isolate = String.fromCharCode(0x2066);
final String _popIsolate = String.fromCharCode(0x2069);

/// حجمٌ يقرؤه الإنسان بأرقامٍ لاتينية: `812 KB`، `38.2 MB`.
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).ceil()} KB';
  }

  final megabytes = bytes / (1024 * 1024);

  return megabytes >= 100
      ? '${megabytes.round()} MB'
      : '${megabytes.toStringAsFixed(1)} MB';
}

/// مدّةٌ قصيرة: `0:42`، `3:05`، `1:02:10`.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}
