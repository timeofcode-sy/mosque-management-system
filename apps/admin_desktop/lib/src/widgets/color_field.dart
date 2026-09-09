import 'package:flutter/material.dart';

/// حقلُ لونٍ سُداسيّ بمعاينةٍ إلى جانبه — ✅ م.6.5.
///
/// **ولا منتقيَ ألوانٍ رسوميّ**: قيمةُ اللون تُكتب `#RRGGBB` كما في
/// `design-tokens.json` وكما تُخزَّن في `institutes.settings['theme']`، ومن يضبط
/// هويّةَ معهدٍ يأتي بالرمز من دليلٍ بصريّ لا يخترعه بعجلة. والمعاينةُ تكفي
/// ليتأكّد أن ما كتبه هو ما قصده.
///
/// والقيمةُ غيرُ الصالحة تُعرَض شفّافةً ولا تُسقط الشاشة: الخادم يتحقّق منها
/// (`InstituteForm::rules`) ويردّ 422 برسالته، فالواجهةُ لا تكرّر الحكم.
class ColorField extends StatefulWidget {
  const ColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<ColorField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHex(_controller.text);

    return SizedBox(
      width: 300,
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value.trim());
        },
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `#0F5132` ⇒ لون، وأي شيءٍ آخر ⇒ شفّاف.
  static Color parseHex(String value) {
    final hex = value.trim().replaceFirst('#', '');

    if (hex.length != 6) {
      return Colors.transparent;
    }

    final parsed = int.tryParse(hex, radix: 16);

    return parsed == null ? Colors.transparent : Color(0xFF000000 | parsed);
  }
}
