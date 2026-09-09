import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:printing/printing.dart';

import '../di/app_scope.dart';
import '../reports/report_documents.dart';
import '../reports/report_fonts.dart';

/// التقاريرُ والطباعة — ✅ م.6.6، **من الجهاز لا من الخادم**.
///
/// تقريران هما ما تطبعه اللوحةُ اليوم: **تفقّدُ يومٍ لحلقة**، و**نقاطُ حلقةٍ في
/// مدى تواريخ**. وكلاهما يُبنى من [StatsRepository] — أي من drift — فيخرج
/// والشبكةُ مقطوعة.
///
/// **والمعاينةُ هي المستندُ نفسُه لا صورةٌ عنه:** `PdfPreview` يعرض البايتاتِ
/// التي ستُطبع، فلا يقع فرقٌ بين ما رآه المشرفُ وما خرج من الطابعة. وهو ما
/// جعلته اللوحةُ صفحةَ HTML ثانيةً غير التقرير، فاختلف المعروضُ من المطبوع
/// مرّاتٍ في م.4.7.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// `daily` أو `points` — والافتراضيُّ اليومي: هو ما يُطلب آخرَ كل حصّة.
  String _kind = 'daily';

  int? _courseCircleId;
  DateTime _date = DateTime.now();
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والطباعة')),
      body: FutureBuilder<List<CircleStanding>>(
        future: deps.stats.loadReportableCircles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final circles = snapshot.data!;

          if (circles.isEmpty) {
            return EmptyState(
              message:
                  'لا حلقةَ مشغَّلةٌ في الدورة الجارية، فلا تقريرَ يُبنى. '
                  'تُشغَّل الحلقاتُ من باب «الدورات والدوامات».',
              icon: Icons.print_outlined,
              onRetry: deps.sync.syncNow,
            );
          }

          final selected = _courseCircleId ?? circles.first.courseCircleId;

          return Column(
            children: [
              _Toolbar(
                circles: circles,
                kind: _kind,
                courseCircleId: selected,
                date: _date,
                range: _range ?? _defaultRange(),
                onKind: (value) => setState(() => _kind = value),
                onCircle: (value) => setState(() => _courseCircleId = value),
                onDate: (value) => setState(() => _date = value),
                onRange: (value) => setState(() => _range = value),
              ),
              const Divider(height: 1),
              Expanded(
                child: _Preview(
                  key: ValueKey(
                    '$_kind-$selected-$_date-${_range ?? _defaultRange()}',
                  ),
                  kind: _kind,
                  courseCircleId: selected,
                  date: _date,
                  range: _range ?? _defaultRange(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// آخرُ ثلاثين يوماً — مدّةُ تقرير النقاط المعتادة، وتُغيَّر بضغطة.
  DateTimeRange _defaultRange() => DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.circles,
    required this.kind,
    required this.courseCircleId,
    required this.date,
    required this.range,
    required this.onKind,
    required this.onCircle,
    required this.onDate,
    required this.onRange,
  });

  final List<CircleStanding> circles;
  final String kind;
  final int courseCircleId;
  final DateTime date;
  final DateTimeRange range;
  final ValueChanged<String> onKind;
  final ValueChanged<int> onCircle;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<DateTimeRange> onRange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('تفقّدُ يوم')),
              ButtonSegment(value: 'points', label: Text('النقاط')),
            ],
            selected: {kind},
            onSelectionChanged: (value) => onKind(value.first),
          ),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<int>(
              initialValue: courseCircleId,
              decoration: const InputDecoration(
                labelText: 'الحلقة',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final circle in circles)
                  DropdownMenuItem(
                    value: circle.courseCircleId,
                    child: Text('${circle.circleName} · ${circle.shiftName}'),
                  ),
              ],
              onChanged: (value) => value == null ? null : onCircle(value),
            ),
          ),
          if (kind == 'daily')
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );

                if (picked != null) {
                  onDate(picked);
                }
              },
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_date(date)),
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: range,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );

                if (picked != null) {
                  onRange(picked);
                }
              },
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text('${_date(range.start)} ← ${_date(range.end)}'),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

/// المعاينةُ والطباعةُ في مكوّنٍ واحد — و`PdfPreview` يعطي الحفظَ والمشاركةَ
/// وحوارَ الطابعة معاً على ويندوز.
class _Preview extends StatelessWidget {
  const _Preview({
    super.key,
    required this.kind,
    required this.courseCircleId,
    required this.date,
    required this.range,
  });

  final String kind;
  final int courseCircleId;
  final DateTime date;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return PdfPreview(
      canDebug: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      pdfFileName: '${kind == 'daily' ? 'daily' : 'points'}-$courseCircleId.pdf',
      build: (format) async {
        final fonts = await ReportFonts.load();
        final snapshot = deps.session.snapshot;
        final institute = snapshot?.institute.name ?? 'المعهد';

        if (kind == 'daily') {
          final report = await deps.stats.loadDailyReport(
            courseCircleId: courseCircleId,
            date: date,
          );

          final document = await ReportDocuments.daily(
            report: report!,
            fonts: fonts,
            instituteName: institute,
          );

          return document.save();
        }

        final report = await deps.stats.loadPointsReport(
          courseCircleId: courseCircleId,
          from: range.start,
          to: range.end,
          // 🔑 قيمُ المعهد من اللقطة لا افتراضياتُ الحزمة — `institutes.settings`
          // جدولٌ لا يُزامَن، فلولا حملُها في `/bootstrap` لَخالف الرقمُ المطبوع
          // رقمَ اللوحة بلا أن يشكوَ أحد.
          points: deps.session.snapshot?.institute.points ?? const PointsSettings(),
        );

        final document = await ReportDocuments.points(
          report: report!,
          fonts: fonts,
          instituteName: institute,
        );

        return document.save();
      },
    );
  }
}
