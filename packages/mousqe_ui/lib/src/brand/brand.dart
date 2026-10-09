import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// هويةُ النظام نفسِه لا هويةُ المعهد: الاسمُ والشعار اللذان تحملهما التطبيقاتُ الأربعة واللوحة.
/// الشعارُ ثابتٌ لا يتلوّن بمعهدٍ دون آخر (قاعدة الهوية v3).
class Brand {
  const Brand._();

  static const String name = 'نزلاً';
  static const String latinName = 'Nuzuln';
  static const String domain = 'nuzuln.com';

  /// ليلُ المسجد: أرضيةُ العلامة — لونُ شاشة البدء الأصلية في أندرويد (`nuzuln_ground`).
  static const Color ground = NzBrand.night;
  static const Color groundRaised = NzBrand.nightRaised;
  static const Color groundLine = NzBrand.nightLine;

  /// نحاسُ الشريط: نصٌّ على الليل (8.97:1) ولونُ العلامة عليه. لا يُكتب به نصٌّ على أرضيةٍ فاتحة.
  static const Color ribbon = NzBrand.bronze;
}

/// العلامةُ على الأرضيات الداكنة (شاشة البدء، الدخول): شرائطُ نحاسية وهلالٌ ونجمتان بيض.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: NzMark(
          height: height,
          ribbons: NzBrand.bronze,
          lights: NzBrand.star,
          semanticLabel: null,
        ),
      );
}

/// العلامةُ بألوان السمة: أخضرُ عميق على الفاتح ونحاسٌ على الليلي. من 48 بكسل فما فوق
/// (دون ذلك تُستعمل الأيقونة الصغرى).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72});

  /// ارتفاعُ العلامة.
  final double size;

  @override
  Widget build(BuildContext context) => NzMark(height: size, semanticLabel: Brand.name);
}
