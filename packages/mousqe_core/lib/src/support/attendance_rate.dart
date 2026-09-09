/// معادلةُ نسبة الحضور — في موضعٍ واحد، ✅ م.6.6.
///
/// **النسبة = (حاضر + متأخّر) ÷ (المجموع − المأذون)**: الإذنُ المسبق لا يُحسب
/// غياباً، وإلا عاقب الترتيبُ الحلقةَ على ظرفٍ خارجَ يدها.
///
/// وهي نقلٌ حرفيٌّ لـ`App\Support\AttendanceRate` — والسببُ الذي استُخرجت لأجله
/// هناك هو نفسُه هنا: كانت مكرَّرةً في ثلاثة مواضع خادمية «كي لا يختلف رقمُ
/// اللوحة عن رقم التقرير». وقد بدأت تتكرّر في Dart أيضاً: نسخةٌ في
/// `StudentProfile.attendanceRate` منذ م.5.3، وكانت م.6.6 ستضيف ثلاثاً —
/// الداشبورد وتقريرُ اليوم وترتيبُ الدوام. **ورقمٌ مطبوعٌ من الجهاز يخالف رقمَ
/// اللوحة أسوأُ من رقمٍ غائب**، لأن أحداً لا يعرف أيَّهما يصدّق.
class AttendanceRate {
  const AttendanceRate._();

  /// النسبةُ مئويةً بمنزلةٍ عشرية واحدة.
  ///
  /// و**صفرٌ لا `null`** حين لا يبقى ما يُقاس (كلُّهم مأذونون): نظيرُ
  /// `AttendanceRate::percent` حرفياً. والتمييزُ بين «صفرٌ قِيس» و«لا شيءَ
  /// يُقاس» يقع عند المستدعي — يعيد `null` حين **لا صفَّ حضورٍ أصلاً**، كما
  /// تفعل `DashboardOverviewQuery::rateOn` على الخادم.
  static double percent({
    required int present,
    required int late,
    required int excused,
    required int total,
    int precision = 1,
  }) {
    final countable = total - excused;

    if (countable <= 0) {
      return 0;
    }

    final factor = _pow10(precision);

    return ((present + late) / countable * 100 * factor).round() / factor;
  }

  static double _pow10(int precision) {
    var result = 1.0;

    for (var i = 0; i < precision; i++) {
      result *= 10;
    }

    return result;
  }
}
