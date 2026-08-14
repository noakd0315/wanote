import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/monthly_report_input_stats.dart';

/// Builds and shares/prints a PDF export of a monthly report (spec 7.2:
/// "PDF出力（通院時に獣医へ共有する用途を想定）"), combining the AI summary
/// text (if generated) with the underlying weight/toilet numbers so the
/// document is still useful for free-tier users who only have the graphs.
class ReportPdfExporter {
  const ReportPdfExporter();

  /// [strings] carries the localized headings. The exporter is const and
  /// has no BuildContext -- the screen that triggers the export resolves the
  /// wording and passes it in, the same way reminders do. The PDF used to be
  /// written entirely in Japanese literals, so an English user exported a
  /// Japanese document.
  Future<Uint8List> buildPdfBytes({
    required MonthlyReportInputStats stats,
    required ReportPdfStrings strings,
    String? summaryText,
    String? petName,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              strings.titleFor(petName ?? strings.defaultPetName),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              strings.periodFor(
                _dateOnly(stats.periodStart),
                _dateOnly(stats.periodEnd),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              strings.summaryHeading,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(summaryText ?? strings.noSummary),
            pw.SizedBox(height: 16),
            pw.Text(
              strings.weightHeading,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: [strings.dateColumn, strings.weightColumn],
              data: stats.weightSamples
                  .map(
                    (s) => [_dateOnly(s.date), s.weightKg.toStringAsFixed(1)],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              strings.toiletHeading,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: [strings.dateColumn, strings.countColumn],
              data: stats.toiletCountsByDay
                  .map((c) => [_dateOnly(c.date), c.count.toString()])
                  .toList(),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Opens the platform print/share sheet (covers both "print" and "share
  /// the PDF file to the vet" use cases via the `printing` package).
  Future<void> shareOrPrint({
    required MonthlyReportInputStats stats,
    required ReportPdfStrings strings,
    String? summaryText,
    String? petName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) => buildPdfBytes(
        stats: stats,
        strings: strings,
        summaryText: summaryText,
        petName: petName,
      ),
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The headings and column names used in the exported report.
///
/// Resolved by the screen and passed in, because the exporter is a const
/// value object with no BuildContext of its own.
class ReportPdfStrings {
  const ReportPdfStrings({
    required this.title,
    required this.defaultPetName,
    required this.period,
    required this.summaryHeading,
    required this.noSummary,
    required this.weightHeading,
    required this.toiletHeading,
    required this.dateColumn,
    required this.weightColumn,
    required this.countColumn,
  });

  /// Contains `{petName}`.
  final String title;
  final String defaultPetName;

  /// Contains `{start}` and `{end}`.
  final String period;

  final String summaryHeading;
  final String noSummary;
  final String weightHeading;
  final String toiletHeading;
  final String dateColumn;
  final String weightColumn;
  final String countColumn;

  String titleFor(String petName) => title.replaceAll('{petName}', petName);

  String periodFor(String start, String end) =>
      period.replaceAll('{start}', start).replaceAll('{end}', end);
}
