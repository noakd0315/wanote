import '../data/ai_backend_client.dart';
import '../models/monthly_report_input_stats.dart';

/// Produces the AI text summary for spec section 7 ("AI健康レポート"). Kept
/// as an interface so the report screen depends on a narrow seam rather than
/// the full [AiBackendClient] surface, and so tests can substitute a fake
/// without any HTTP/Firebase setup.
abstract class MonthlyReportGenerator {
  Future<String> generateSummary({
    required String petId,
    required MonthlyReportInputStats stats,
  });
}

/// Default implementation: delegates to the Cloudflare Worker's
/// `POST /ai/report` route (functions/src/routes/report.ts).
class BackendMonthlyReportGenerator implements MonthlyReportGenerator {
  const BackendMonthlyReportGenerator(this._client);

  final AiBackendClient _client;

  @override
  Future<String> generateSummary({
    required String petId,
    required MonthlyReportInputStats stats,
  }) {
    return _client.requestMonthlyReport(petId: petId, stats: stats);
  }
}
