import 'package:flutter/material.dart';

import 'adaptive.dart';

/// بابٌ معنونٌ في استمارةِ مكتب — حقولُه تتدفّق في `Wrap` لا في عمود.
///
/// وهو ما يفرّق استمارةَ المكتب عن استمارة الهاتف: نافذةٌ من ١٤٤٠ بكسلاً تسع
/// أربعةَ حقولٍ في السطر، وعمودٌ واحد فيها يجعل استمارةَ الطالب عشرين شاشةَ
/// تمرير. ولذلك لم تُرفع الشاشاتُ إلى `mousqe_ui` في م.6.4
/// ([CHECKPOINT-PHASE-6.4.MD §2.1](../../../../../docs/checkpoints/CHECKPOINT-PHASE-6.4.MD)).
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    this.children = const [],
    this.child,
    this.trailing,
  });

  final String title;

  /// حقولٌ تتدفّق جنباً إلى جنب — أو [child] لمحتوى بابٍ لا ينقسم حقولاً.
  final List<Widget> children;

  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 12),
          // على الهاتف عمودٌ بعرض الشاشة: القيدُ المحكَم يغلب عرضَ الحقل
          // (300px) فيمتدّ كلُّ حقلٍ إلى الحافّتين.
          child ??
              (context.isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: children,
                    )
                  : Wrap(spacing: 16, runSpacing: 16, children: children)),
        ],
      ),
    );
  }
}
