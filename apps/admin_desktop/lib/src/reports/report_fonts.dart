import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// خطوطُ التقارير المطبوعة — ✅ م.6.6.
///
/// ### 🔑 لماذا لا تكفي خطوط `pdf` المدمجة؟
///
/// حزمةُ `pdf` تحمل خطوطَ PDF المعيارية (Helvetica وأخواتها)، وهي **بلا حرفٍ
/// عربيٍّ واحد**. فتقريرٌ يُبنى بها يخرج بمربّعاتٍ فارغة مكان كل كلمة — ولا خطأ
/// يُرمى، لأن الخطَّ موجودٌ والحرفُ مفقود.
///
/// **والخطُّ يُؤخذ من `mousqe_ui` لا يُنسَخ:** الحزمةُ تحمل `IBM Plex Sans Arabic`
/// أصلاً لأنها هويّةُ التطبيقات الأربعة البصرية، وأصولُ الحزمة تُقرأ من التطبيق
/// بمفتاح `packages/<الحزمة>/<المسار>`. فالتقريرُ المطبوع بخطّ الشاشة نفسِه، ولا
/// ملفَّ خطٍّ ثانٍ في المستودع يفترق عنه عند أوّل تحديث.
///
/// **وتُقرأ مرّةً وتُحفظ:** ملفُّ الخط ≈١٥٠ كيلوبايت، وقراءتُه في كل طباعةٍ ثمنٌ
/// بلا مقابل — والمشرفُ يطبع عشرين تقريراً في الجلسة الواحدة.
class ReportFonts {
  const ReportFonts._(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  static ReportFonts? _cached;

  static Future<ReportFonts> load() async {
    final cached = _cached;

    if (cached != null) {
      return cached;
    }

    // ومفتاحُ الخطّ يحتفظ بـ`lib/` خلافاً لمفتاح الأصل العادي: ما يُعلَن في
    // `fonts:` يُحزَم بمساره كما كُتب، لا مقصوصاً عند `lib`.
    const folder = 'packages/mousqe_ui/lib/src/fonts';

    Future<pw.Font> read(String name) async =>
        pw.Font.ttf(await rootBundle.load('$folder/$name'));

    final fonts = ReportFonts._(
      await read('IBMPlexSansArabic-Regular.ttf'),
      await read('IBMPlexSansArabic-Bold.ttf'),
    );

    return _cached = fonts;
  }

  /// ثيمُ المستند — والخطُّ نفسُه في المواضع الأربعة، فلا يسقط موضعٌ إلى
  /// Helvetica فيخرج سطرٌ بمربّعات وسط تقريرٍ سليم.
  pw.ThemeData get theme => pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    italic: regular,
    boldItalic: bold,
  );
}
