import 'package:mousqe_core/mousqe_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_fonts.dart';

/// بناءُ مستندَي التقرير — ✅ م.6.6، **من الجهاز لا من الخادم**.
///
/// ### 🔑 لماذا يُبنى المستندُ هنا لا تُطلب صفحةُ طباعةٍ من الخادم؟
///
/// لأن الشرطَ في [APPS-FEATURES.md §4.2](../../../../../docs/APPS-FEATURES.md)
/// البند 7 هو أن يُطبع **والشبكةُ مقطوعة**. واللوحةُ تطبع من الخادم لأنها فيه؛
/// والديسكتوبُ يجلس في مسجدٍ قد لا يكون فيه إنترنت أصلاً، وتقريرُ اليوم يُطلب
/// آخرَ الحصّة لا آخرَ الأسبوع.
///
/// **وأرقامُه أرقامُ اللوحة نفسُها** لأنها تمرّ بـ`AttendanceRate` و
/// `PointsSettings` — لا لأن الشاشةَ حرصت، بل لأن المعادلةَ والقيمَ في موضعٍ
/// واحدٍ لكل سطح ([CHECKPOINT-PHASE-6.6.MD §3](../../../../../docs/CHECKPOINT-PHASE-6.6.MD)).
///
/// **ولا ويدجت فلاتر واحدة هنا:** `pw` عالمٌ آخر — فالبناءُ دالّةٌ صرفٌ تأخذ
/// نموذجاً وتعيد بايتات، تُختبَر بلا شجرةٍ ولا نافذة.
class ReportDocuments {
  const ReportDocuments._();

  /// تقريرُ يومٍ واحد لحلقة — نظير `pages/reports/circle-daily` في اللوحة.
  static Future<pw.Document> daily({
    required CircleDailyReport report,
    required ReportFonts fonts,
    required String instituteName,
  }) async {
    final document = pw.Document(theme: fonts.theme);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // 🔑 الاتجاهُ يُعلَن مرّةً على الصفحة: `pdf` يعيد تشكيل العربية ويعكس
        // ترتيبَ الأسطر بناءً عليه. وبدونه يخرج النصُّ **مقلوباً حرفاً حرفاً**
        // — وهو خطأٌ يُقرأ ولا يُرمى، فلا يكشفه إلا من ينظر في الورقة.
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(
              instituteName: instituteName,
              title: 'تقريرُ التفقّد اليومي',
              subtitle: '${report.circleName} · ${report.shiftName}'
                  '${report.room == null ? '' : ' · ${report.room}'}',
              date: _date(report.date),
            ),
            pw.SizedBox(height: 12),
            _facts({
              'الأساتذة': report.teachersLabel,
              'حالةُ الجلسة': _sessionLabel(report.sessionStatus),
              'النسبة': _percent(report.rate),
              'الترتيبُ في الدوام': report.rank?.toString() ?? '—',
              'النسبةُ التراكمية': _percent(report.cumulativeRate),
              'جلساتٌ قِيست': '${report.sessionsCount}',
            }),
            pw.SizedBox(height: 16),
            if (!report.exists)
              pw.Text(
                'لم تُفتح جلسةُ هذا اليوم لهذه الحلقة.',
                style: const pw.TextStyle(fontSize: 12),
              )
            else ...[
              _countsTable(report.breakdown),
              pw.SizedBox(height: 16),
              for (final status in AttendanceStatus.values)
                _namesBlock(status, report.names[status] ?? const []),
            ],
            pw.Spacer(),
            _footer(),
          ],
        ),
      ),
    );

    return document;
  }

  /// تقريرُ نقاطِ حلقةٍ في مدى تواريخ — نظير `BuildCirclePointsReport`.
  static Future<pw.Document> points({
    required PointsReport report,
    required ReportFonts fonts,
    required String instituteName,
  }) async {
    final document = pw.Document(theme: fonts.theme);

    document.addPage(
      // `MultiPage` لا `Page`: حلقةٌ بأربعين طالباً لا تسع صفحةً واحدة، وقصُّ
      // الذيل يعني تقريرَ ترتيبٍ بلا نصفِه الأسفل.
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _header(
            instituteName: instituteName,
            title: 'تقريرُ النقاط',
            subtitle: '${report.circleName} · ${report.shiftName}',
            date: '${_date(report.from)} ← ${_date(report.to)}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            headers: const [
              '#',
              'الطالب',
              'القرآن',
              'الحديث',
              'المتون',
              'الحضور',
              'يدوية',
              'المجموع',
            ],
            data: [
              for (final row in report.rows)
                [
                  '${row.rank}',
                  row.studentName,
                  _number(row.quran),
                  _number(row.hadith),
                  _number(row.mutun),
                  _number(row.attendance),
                  _number(row.manual),
                  _number(row.total),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'مجموعُ الحلقة: ${_number(report.total)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          // شرحٌ في الورقة لا في رأس القارئ: من يقرأ عموداً بصفرٍ يجب أن يعرف
          // أهو «لا نقاط» أم «لم يصل بعد».
          pw.Text(
            'نقاطُ التسميع والمناهج كما حسبها الخادم؛ ونقاطُ الحضور محسوبةٌ بقيم '
            'المعهد. وتسميعٌ لم يصل الخادمَ بعد لا نقاطَ له حتى تكتمل المزامنة.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          _footer(),
        ],
      ),
    );

    return document;
  }

  // ------------------------------------------------------------ القطع

  static pw.Widget _header({
    required String instituteName,
    required String title,
    required String subtitle,
    required String date,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              instituteName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(date, style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(title, style: const pw.TextStyle(fontSize: 13)),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _facts(Map<String, String> facts) {
    return pw.Wrap(
      spacing: 24,
      runSpacing: 6,
      children: [
        for (final entry in facts.entries)
          pw.Text(
            '${entry.key}: ${entry.value}',
            style: const pw.TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  static pw.Widget _countsTable(StatusBreakdown breakdown) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.center,
      headers: const ['حاضر', 'متأخّر', 'غائب', 'مأذون', 'المجموع'],
      data: [
        [
          '${breakdown.present}',
          '${breakdown.late}',
          '${breakdown.absent}',
          '${breakdown.excused}',
          '${breakdown.total}',
        ],
      ],
    );
  }

  static pw.Widget _namesBlock(AttendanceStatus status, List<String> names) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${statusLabels[status]} (${names.length})',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            // الفراغُ يُقال لا يُترك: قائمةٌ خاليةٌ بلا شرطة تبدو قصّاً في الطباعة.
            names.isEmpty ? '—' : names.join('، '),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer() => pw.Text(
    'طُبع من تطبيق المشرف — mousqe',
    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
  );

  static String _sessionLabel(String? status) => switch (status) {
    'draft' => 'مسوّدة',
    'completed' => 'مكتملة',
    'locked' => 'مقفلة',
    _ => 'لم تُفتح',
  };

  static String _percent(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}٪';

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(2);

  static String _date(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

/// تسمياتُ الحالات في الورقة — نظير `AttendanceStatusBadge` بلا ويدجت.
const Map<AttendanceStatus, String> statusLabels = {
  AttendanceStatus.present: 'الحاضرون',
  AttendanceStatus.late: 'المتأخّرون',
  AttendanceStatus.absent: 'الغائبون',
  AttendanceStatus.excused: 'المأذونون',
};
