import 'package:flutter/material.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

/// التخطيطُ المتكيّف — البرنامجُ نفسُه على الحاسوب والهاتف.
///
/// الحدُّ هو `NzBreakpoint.medium` (600px) من رموز الهوية: دونه هاتفٌ بعمودٍ
/// واحد وهوامشَ 16px وشريطٍ سفلي، وفوقه ما كان للمكتب كما هو. فلا يتغيّر في
/// نسخة ويندوز شيء، والقرارُ بالعرض لا بالمنصّة: نافذةٌ ضيّقة على الحاسوب
/// تأخذ تخطيطَ الهاتف أيضاً.
extension AdaptiveContext on BuildContext {
  /// هاتفٌ أو نافذةٌ في ضيقه.
  bool get isCompact => MediaQuery.sizeOf(this).width < NzBreakpoint.medium;

  /// هامشُ الصفحة: 16px على الهاتف، و[wide] فوقه.
  double gutter([double wide = NzSpace.s4]) => isCompact ? NzSpace.s4 : wide;
}

/// فعلٌ في شريط التطبيق: زرٌّ بنصّه على الشاشة العريضة، وأيقونةٌ بتلميحٍ على
/// الهاتف — فلا يزاحم العنوانَ في 360px.
class AdaptiveAction extends StatelessWidget {
  const AdaptiveAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.busy = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  /// زرٌّ مصمت (الفعلُ الرئيس في الشاشة) لا نصّيّ.
  final bool filled;

  /// مؤشّرُ انشغالٍ مكان الأيقونة.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final glyph = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : NzIcon(icon, size: 18);

    if (context.isCompact) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: busy ? glyph : NzIcon(icon, semanticLabel: label),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: glyph,
              label: Text(label),
            )
          : TextButton.icon(
              onPressed: onPressed,
              icon: glyph,
              label: Text(label),
            ),
    );
  }
}

/// قائمةُ أفعال الصفّ على الهاتف: أيقونةُ «المزيد» تفتح الأفعالَ بأسمائها، بدل
/// صفٍّ من الأيقونات يأكل عرضَ الاسم.
class RowActionsMenu extends StatelessWidget {
  const RowActionsMenu({super.key, required this.actions});

  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<RowAction>(
      tooltip: 'إجراءات',
      icon: const NzIcon(NzIcons.moreVertical),
      onSelected: (action) => action.onPressed(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Row(
              spacing: NzSpace.s3,
              children: [
                NzIcon(
                  action.icon,
                  size: 20,
                  color: action.destructive ? context.nz.danger : null,
                ),
                Expanded(
                  child: Text(
                    action.label,
                    style: action.destructive
                        ? TextStyle(color: context.nz.danger)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RowAction {
  const RowAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;
}

/// بطاقةُ أرقامٍ متجاورة على الشاشة العريضة، وشبكةٌ من عمودين على الهاتف.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.isCompact) {
      return Row(
        spacing: spacing,
        children: [for (final child in children) Expanded(child: child)],
      );
    }

    // صفوفٌ من اثنين بارتفاعٍ واحد: تسميةٌ في سطرين بجانب تسميةٍ في سطرٍ لا
    // تترك بطاقتين متفاوتتين.
    return Column(
      spacing: spacing,
      children: [
        for (var i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing,
              children: [
                Expanded(child: children[i]),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
