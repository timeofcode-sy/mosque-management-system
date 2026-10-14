import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// شريطُ ترقيم الصفحات بنمط الهوية — نظيرُ `flux/pagination.blade.php` في اللوحة: ملخّص «عرض 1–25 من 243»
/// وأزرارٌ مربّعة بزاوية 3px (الحاليةُ primary مصمتة) ونافذةُ صفحاتٍ مع نقاط حذف، وسهمان يتبعان اتجاه الواجهة.
/// وفي العرض الضيّق (دون 600px) «صفحة 2 من 4» بين السابق والتالي بمساحة لمس 44px.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
  });

  /// رقمُ الصفحة الحالية من 0.
  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  /// أرقامُ الصفحات الظاهرة (من 0)؛ `null` تعني نقاط حذف.
  List<int?> get window {
    final last = pageCount - 1;
    final shown = <int>{
      0,
      last,
      page - 1,
      page,
      page + 1,
    }.where((p) => p >= 0 && p <= last).toList()..sort();
    final out = <int?>[];
    int? previous;

    for (final p in shown) {
      if (previous != null && p - previous > 1) {
        out.add(null);
      }
      out.add(p);
      previous = p;
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final c = context.nz;
    final first = page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, total);
    final narrow = MediaQuery.sizeOf(context).width < NzBreakpoint.medium;

    final summary = Text.rich(
      TextSpan(
        style: NzType.body.copyWith(color: c.inkMuted),
        children: [
          const TextSpan(text: 'عرض '),
          TextSpan(
            text: '$first–$last',
            style: NzType.body.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: ' من '),
          TextSpan(
            text: '$total',
            style: NzType.body.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final controls = pageCount <= 1
        ? const SizedBox.shrink()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageButton(
                tooltip: 'السابق',
                enabled: page > 0,
                onTap: () => onPage(page - 1),
                // السهمُ للخلف يشير إلى اليمين في الواجهة العربية.
                child: const NzIcon(NzIcons.back, size: 16),
                narrow: false,
              ),
              for (final p in window)
                p == null
                    ? SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            '…',
                            style: NzType.body.copyWith(color: c.inkMuted),
                          ),
                        ),
                      )
                    : _PageButton(
                        tooltip: 'الصفحة ${p + 1}',
                        current: p == page,
                        onTap: () => onPage(p),
                        narrow: false,
                        child: Text(
                          '${p + 1}',
                          style: NzType.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: p == page ? c.onPrimary : c.ink,
                          ),
                        ),
                      ),
              _PageButton(
                tooltip: 'التالي',
                enabled: page < pageCount - 1,
                onTap: () => onPage(page + 1),
                child: const NzIcon(NzIcons.chevronLeft, size: 16),
                narrow: false,
              ),
            ],
          );

    // على الهاتف سطرٌ واحد بعرض الشاشة: السابق · «عرض 1–24 من 418» · التالي — لا سطران
    // وأزرارٌ كبيرة تأكل ربعَ الشاشة.
    if (narrow) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: NzSpace.s3,
          vertical: NzSpace.s1,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            if (pageCount > 1)
              _PageButton(
                tooltip: 'السابق',
                enabled: page > 0,
                onTap: () => onPage(page - 1),
                narrow: true,
                child: const NzIcon(NzIcons.back, size: 16),
              ),
            Expanded(child: Center(child: summary)),
            if (pageCount > 1)
              _PageButton(
                tooltip: 'التالي',
                enabled: page < pageCount - 1,
                onTap: () => onPage(page + 1),
                narrow: true,
                child: const NzIcon(NzIcons.chevronLeft, size: 16),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NzSpace.s4,
        vertical: NzSpace.s3,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [summary, controls],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.tooltip,
    required this.child,
    required this.onTap,
    required this.narrow,
    this.enabled = true,
    this.current = false,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback onTap;
  final bool narrow;
  final bool enabled;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final size = narrow ? 44.0 : 36.0;
    final radius = BorderRadius.circular(NzRadius.sm);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: current,
          enabled: enabled,
          label: tooltip,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Material(
              color: current ? c.primary : c.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(color: current ? c.primary : c.line),
              ),
              child: InkWell(
                borderRadius: radius,
                hoverColor: c.surfaceSunken,
                onTap: enabled && !current ? onTap : null,
                child: SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: c.ink, size: 16),
                      child: child,
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
}

/// قائمةٌ مرقَّمة بنمط الجدول في الهوية: بطاقةٌ raised بحدّ line وزاوية 6px، ورأسٌ اختياري على sunken،
/// وصفوفٌ بهوامش 20px أفقياً و12px عمودياً يفصل بينها خطّ، وتحتها [PaginationBar].
///
/// البياناتُ محلّيةٌ كاملة (قاعدةُ الجهاز) فالتقطيعُ هنا لا في الاستعلام. و[resetKey] يعيد إلى الصفحة الأولى
/// حين يتغيّر (بحثٌ أو مرشّح) كي لا يبقى المستخدمُ على صفحةٍ لم تعد موجودة.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.header,
    this.pageSize = 25,
    this.resetKey,
    this.onTap,
    this.margin = const EdgeInsets.all(NzSpace.s4),
    this.rowPadding = const EdgeInsets.symmetric(
      horizontal: NzSpace.s5 - 4,
      vertical: NzSpace.s3,
    ),
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// صفُّ العناوين فوق الصفوف (يُوضع على sunken).
  final Widget? header;
  final int pageSize;
  final Object? resetKey;
  final ValueChanged<T>? onTap;
  final EdgeInsetsGeometry margin;

  /// هامشُ كل صف: 20px أفقياً و12px عمودياً. ومن يضع `ListTile` (له هامشه) يصغّره.
  final EdgeInsetsGeometry rowPadding;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  int _page = 0;

  @override
  void didUpdateWidget(PagedList<T> old) {
    super.didUpdateWidget(old);

    if (old.resetKey != widget.resetKey) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final total = widget.items.length;
    final pages = total == 0
        ? 1
        : (total + widget.pageSize - 1) ~/ widget.pageSize;
    final page = _page.clamp(0, pages - 1);
    final slice = widget.items
        .skip(page * widget.pageSize)
        .take(widget.pageSize)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: widget.margin,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(NzRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null)
              Container(
                color: c.surfaceSunken,
                padding: const EdgeInsets.symmetric(
                  horizontal: NzSpace.s5 - 4,
                  vertical: NzSpace.s2,
                ),
                child: DefaultTextStyle.merge(
                  style: NzType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.inkMuted,
                  ),
                  child: widget.header!,
                ),
              ),
            for (var i = 0; i < slice.length; i++) ...[
              if (i > 0 || widget.header != null)
                Divider(height: 1, color: c.line),
              InkWell(
                hoverColor: c.surfaceSunken,
                onTap: widget.onTap == null
                    ? null
                    : () => widget.onTap!(slice[i]),
                child: Padding(
                  padding: widget.rowPadding,
                  child: widget.itemBuilder(context, slice[i]),
                ),
              ),
            ],
            PaginationBar(
              page: page,
              pageSize: widget.pageSize,
              total: total,
              onPage: (value) => setState(() => _page = value),
            ),
          ],
        ),
      ),
    );
  }
}

/// ترقيمٌ لأيّ جسمٍ قابلٍ للتمرير (قائمة بطاقات، شبكة …): يعطي [builder] صفحةَ العناصر الحالية، ويثبّت
/// [PaginationBar] أسفل المنطقة. للقوائم بنمط الجدول استعمل [PagedList]. و[resetKey] كما فيه.
class PagedView<T> extends StatefulWidget {
  const PagedView({
    super.key,
    required this.items,
    required this.builder,
    this.pageSize = 24,
    this.resetKey,
  });

  final List<T> items;
  final Widget Function(BuildContext context, List<T> pageItems) builder;
  final int pageSize;
  final Object? resetKey;

  @override
  State<PagedView<T>> createState() => _PagedViewState<T>();
}

class _PagedViewState<T> extends State<PagedView<T>> {
  int _page = 0;

  @override
  void didUpdateWidget(PagedView<T> old) {
    super.didUpdateWidget(old);

    if (old.resetKey != widget.resetKey) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final total = widget.items.length;
    final pages = total == 0
        ? 1
        : (total + widget.pageSize - 1) ~/ widget.pageSize;
    final page = _page.clamp(0, pages - 1);
    final slice = widget.items
        .skip(page * widget.pageSize)
        .take(widget.pageSize)
        .toList(growable: false);

    return Column(
      children: [
        Expanded(child: widget.builder(context, slice)),
        Material(
          color: c.surfaceRaised,
          child: PaginationBar(
            page: page,
            pageSize: widget.pageSize,
            total: total,
            onPage: (value) => setState(() => _page = value),
          ),
        ),
      ],
    );
  }
}
