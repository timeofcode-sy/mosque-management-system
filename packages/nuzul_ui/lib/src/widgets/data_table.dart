import 'package:flutter/material.dart';

import '../digits.dart';
import '../generated/tokens.dart';
import '../theme.dart';

/// A column of [NzDataTable]. Numeric columns align to the end and show Arabic-Indic digits.
class NzColumn {
  const NzColumn(this.label, {this.numeric = false});

  final String label;
  final bool numeric;
}

/// Records and reports on desktop and in the web app. On phones use a list of `NzStudentCard`s instead.
class NzDataTable extends StatelessWidget {
  const NzDataTable({super.key, required this.columns, required this.rows, this.caption, this.sortColumn});

  final List<NzColumn> columns;

  /// Each cell is a String (numbers are converted for numeric columns) or a Widget.
  final List<List<Object>> rows;
  final String? caption;
  final int? sortColumn;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    Widget cell(Object v, NzColumn col) => v is Widget
        ? v
        : Text(col.numeric ? nzDigits(v) : v.toString(), textAlign: col.numeric ? TextAlign.end : TextAlign.start);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(NzRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (caption != null)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: NzSpace.s4, vertical: NzSpace.s3),
            child: Text(caption!, style: NzType.title.copyWith(fontSize: 15, height: 24 / 15, color: c.ink)),
          ),
        LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              child: DataTable(
                sortColumnIndex: sortColumn,
                sortAscending: false,
                horizontalMargin: NzSpace.s4,
                columnSpacing: NzSpace.s6,
                columns: [for (final col in columns) DataColumn(label: Text(col.label), numeric: col.numeric)],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [for (var i = 0; i < columns.length; i++) DataCell(cell(r[i], columns[i]))]),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
