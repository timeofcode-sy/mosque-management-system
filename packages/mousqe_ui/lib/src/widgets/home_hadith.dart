import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// الحديثُ الذي أُخذ منه اسمُ النظام — «نُزُلاً» — كما يعرضه الموقع، في رأس الشاشة الرئيسية لكل
/// تطبيق وعلى شاشة البدء.
abstract final class BrandHadith {
  static const String text =
      'مَن غدا إلى المسجدِ أو راحَ، أعدَّ اللهُ له نُزُلَهُ من الجنّةِ كلّما غدا أو راحَ';
  static const String source = 'متفق عليه';
}

/// بطاقةُ الحديث ([NzHadithQuote]) بمسافتها في رأس قائمة — تُوضع أولَ عنصرٍ في الشاشة الرئيسية.
class HomeHadith extends StatelessWidget {
  const HomeHadith({super.key, this.night = false, this.padding});

  /// على أرضية الليل.
  final bool night;

  /// الافتراضيُّ هامشُ الصفحة (16) من الجوانب والأعلى.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s4, NzSpace.s4, 0),
      child: Semantics(
        container: true,
        label: 'حديث',
        child: NzHadithQuote(
          BrandHadith.text,
          source: BrandHadith.source,
          night: night,
        ),
      ),
    );
  }
}
