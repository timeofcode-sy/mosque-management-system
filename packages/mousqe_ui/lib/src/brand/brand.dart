import 'package:flutter/material.dart';

/// هويةُ النظام نفسِه لا هويةُ المعهد: الاسمُ والشعار اللذان تحملهما التطبيقاتُ
/// الأربعة واللوحة. وألوانُ الشعار ثابتةٌ هنا عمداً — ثيمُ المعهد يلوّن الواجهة،
/// أما الشعارُ فلا يتلوّن بمعهدٍ دون آخر (`design/design-tokens.json → color.logo`).
class Brand {
  const Brand._();

  static const String name = 'نزلاً';
  static const String latinName = 'Nuzuln';
  static const String domain = 'nuzuln.com';

  /// الأرضيةُ المسطّحة — لونُ شاشة البدء الأصلية في أندرويد (`nuzuln_ground`).
  static const Color ground = Color(0xFF0E2925);
  static const Color groundLight = Color(0xFF1B3C35);
  static const Color groundDark = Color(0xFF0A221E);
  static const Color ribbon = Color(0xFFD8C0A2);
}

/// العلامةُ المجرّدة بلا بلاطة — للأسطح الخضراء الداكنة وحدها.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    // الصورةُ مقصوصةٌ على حدود الرسم، ومحورُ القبّة فيها عند 48.5% من عرضها
    // لأن النجمة اليمنى تبرز خارج الجدار — فتُزاح قليلاً ليتوسّط المحورُ مكانَه.
    return Transform.translate(
      offset: Offset(height * 0.0101, 0),
      child: Image.asset(
        'assets/brand/nuzuln_mark.png',
        package: 'mousqe_ui',
        height: height,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// الشعارُ على بلاطته الخضراء المدوّرة — نفسُ أيقونة التطبيق، فيصلح فوق سطحٍ
/// فاتحٍ أو داكن: الهلالُ والنجمتان بيضٌ ولا يظهران إلا على الأخضر.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: Brand.name,
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.225),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Brand.groundLight, Brand.groundDark],
          ),
        ),
        child: BrandGlyph(height: size * 0.64),
      ),
    );
  }
}
