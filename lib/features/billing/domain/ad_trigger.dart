import '../../../shared/services/ai_usage_repository.dart';
import 'ad_policy.dart';
import 'billing_models.dart';

/// Every action in the app that can show an interstitial.
///
/// An enum rather than scattered `maybeShowInterstitial()` calls: with the
/// calls inlined in each screen, "where does an ad appear?" could only be
/// answered by reading all of them, and the list would drift as screens
/// changed. Here it is one list, and the rules below are testable without a
/// widget.
enum AdTrigger {
  /// AI 相談を送信 (consultation_screen).
  aiConsultation,

  /// 餌の量を算出 (food_portion_screen).
  aiFoodPortion,

  /// 健康記録を写真つきで保存 (health_record_form_screen).
  healthRecordUpload,

  /// トイレ記録を写真つきで保存 (toilet_record_form_screen).
  toiletRecordUpload,

  /// 証明書の撮影と OCR (prevention_record_form_screen). One ad for the
  /// pair -- the owner performed one action.
  certificateCapture,
}

/// Whether [trigger] should show an ad right now.
///
/// Deliberately not a method on AdPolicy: the subscription question and the
/// "did this particular call come out of something they bought" question are
/// different, and only the AI triggers care about the second one.
class AdTriggerPolicy {
  const AdTriggerPolicy();

  /// [aiUsageSource] is which wallet paid for an AI call, and must be read
  /// *before* the call is recorded -- afterwards the balance has already
  /// moved. Null for triggers that are not AI calls.
  bool shouldShowAd({
    required AdTrigger trigger,
    required PremiumStatus premiumStatus,
    AiUsageSource? aiUsageSource,
  }) {
    if (!AdPolicy.fromStatus(premiumStatus).shouldShowInterstitial) {
      return false;
    }

    // A ticket is a purchase. Showing an ad for the call it paid for would
    // charge the owner twice for one thing -- money and attention -- and is
    // the whole reason this class exists rather than AdPolicy alone.
    //
    // Only AI calls draw on tickets. Photo uploads and the certificate scan
    // do not consume them (the tickets are sold as "AI相談チケット" and the
    // OCR route is limited server-side instead), so they are unaffected by a
    // ticket balance.
    if (aiUsageSource == AiUsageSource.ticket) return false;

    return true;
  }
}
