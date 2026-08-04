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

  Future<Uint8List> buildPdfBytes({
    required MonthlyReportInputStats stats,
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
              '${petName ?? 'ペット'} 健康レポート',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '対象期間: ${_dateOnly(stats.periodStart)} 〜 ${_dateOnly(stats.periodEnd)}',
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'AIサマリー',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(summaryText ?? '（このレポートにはAIサマリーは含まれていません）'),
            pw.SizedBox(height: 16),
            pw.Text(
              '体重の推移',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['日付', '体重(kg)'],
              data: stats.weightSamples
                  .map(
                    (s) => [_dateOnly(s.date), s.weightKg.toStringAsFixed(1)],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'トイレ回数の推移',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['日付', '回数'],
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
    String? summaryText,
    String? petName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) => buildPdfBytes(
        stats: stats,
        summaryText: summaryText,
        petName: petName,
      ),
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
