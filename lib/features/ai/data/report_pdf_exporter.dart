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

  /// Noto Sans JP, for a document that has to render Japanese.
  ///
  /// Fetched through the printing package rather than bundled: the family
  /// is several megabytes, and every user would carry it whether or not
  /// they ever exported a report. The trade is a network fetch on the first
  /// export, cached afterwards.
  ///
  /// Returns null if it cannot be fetched. A Latin-only document is a poor
  /// result, but it is a result -- the alternative is the export hanging,
  /// which is what it did before.
  static Future<pw.ThemeData> _japaneseTheme() async {
    try {
      final regular = await PdfGoogleFonts.notoSansJPRegular().timeout(
        _fontFetchTimeout,
      );
      final bold = await PdfGoogleFonts.notoSansJPBold().timeout(
        _fontFetchTimeout,
      );
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [regular],
      );
    } catch (error) {
      // Deliberately fatal rather than falling back to Helvetica. Without a
      // CJK font the very next step throws anyway, one layer deeper, where
      // the printing plugin swallows it and the preview simply never
      // appears (PM report, 2026-08-18). A caller that knows the font is
      // missing can say so.
      throw ReportPdfException(ReportPdfFailure.fontUnavailable, error);
    }
  }

  /// The font is a few megabytes over the network on first export. Long
  /// enough for a slow connection, short enough that a dead one is reported
  /// rather than waited on.
  static const Duration _fontFetchTimeout = Duration(seconds: 20);

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
    // A PDF with no font registered cannot draw a single Japanese
    // character. The `pdf` package's built-in Helvetica has no CJK glyphs,
    // and rather than dropping them it throws -- which left the export
    // spinning forever, because the failure happened inside the callback
    // the print dialog was waiting on (PM report, 2026-08-17).
    final theme = await _japaneseTheme();

    final doc = pw.Document(theme: theme);
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
    // Built *before* the preview opens, not inside its callback.
    //
    // onLayout runs while the print dialog is already on screen, and
    // anything it throws is swallowed there -- the dialog just sits at
    // "generating" forever, which is exactly what the PM saw. Doing the
    // work first means a failure is a thrown exception the screen can put
    // in front of someone, and the dialog only ever opens with finished
    // bytes in hand.
    final bytes = await buildPdfBytes(
      stats: stats,
      strings: strings,
      summaryText: summaryText,
      petName: petName,
    );
    await Printing.layoutPdf(onLayout: (format) async => bytes);
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


/// Why a report could not be turned into a PDF.
enum ReportPdfFailure {
  /// The Japanese font could not be fetched, so the document cannot be
  /// drawn at all. Almost always the network.
  fontUnavailable,
}

class ReportPdfException implements Exception {
  const ReportPdfException(this.failure, [this.cause]);

  final ReportPdfFailure failure;
  final Object? cause;

  @override
  String toString() => 'ReportPdfException(${failure.name}): $cause';
}
