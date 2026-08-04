import '../../../shared/models/consultation_reference_record.dart';
import '../models/toilet_record.dart';

/// Pure anomaly-detection logic over toilet records, per spec section 4.4
/// ("血便疑い」「下痢が◯日連続」等、特定条件が続いた場合にAI相談機能への導線
/// を表示する"). Emits [ConsultationSuggestion]/[ConsultationReferenceRecord]
/// instances only — these are the *shared* models that form the interface
/// boundary with Agent D's AI-consultation feature (features/ai/). This
/// class must never import anything from features/ai/; features/ai only
/// ever sees the shared [ConsultationSuggestion] shape produced here.
///
/// Deliberately framework-free (no Firestore/Flutter) so it's unit-testable
/// with plain `List<ToiletRecord>` fixtures.
class AnomalyDetector {
  const AnomalyDetector({
    this.diarrheaStreakThresholdDays = defaultDiarrheaStreakThresholdDays,
  });

  /// Spec 4.4 says only "下痢が◯日連続" without pinning down a number of
  /// days. We use 3 consecutive calendar days as the working default —
  /// tune via the constructor parameter if product wants a different value.
  static const int defaultDiarrheaStreakThresholdDays = 3;

  final int diarrheaStreakThresholdDays;

  /// Inspects [records] (expected to be one pet's recent toilet records) and
  /// returns the suggestions that should currently be shown.
  ///
  /// [lastSuggestedAt] lets the caller implement spec 4.4's "通知過多を避け
  /// るため、異常検知アラートの頻度には上限を設ける" requirement without this
  /// class holding any mutable state itself: pass in, per
  /// [ConsultationSuggestionReason], the timestamp a suggestion for that
  /// reason was last surfaced to the user (e.g. persisted in local storage
  /// or a Firestore doc by the caller). If a reason was already suggested on
  /// the same calendar day as [now], it's suppressed here even if the
  /// underlying condition still holds — i.e. dedupe-by-day, at most one
  /// alert per condition per day. Omit or pass an empty map on first run.
  List<ConsultationSuggestion> detect({
    required List<ToiletRecord> records,
    required DateTime now,
    Map<ConsultationSuggestionReason, DateTime> lastSuggestedAt = const {},
  }) {
    final suggestions = <ConsultationSuggestion>[];

    bool suppressedToday(ConsultationSuggestionReason reason) {
      final last = lastSuggestedAt[reason];
      return last != null && _isSameDay(last, now);
    }

    final bloodSuggestion = _detectBloodInStool(records);
    if (bloodSuggestion != null &&
        !suppressedToday(ConsultationSuggestionReason.bloodInStoolSuspected)) {
      suggestions.add(bloodSuggestion);
    }

    final diarrheaSuggestion = _detectProlongedDiarrhea(records);
    if (diarrheaSuggestion != null &&
        !suppressedToday(ConsultationSuggestionReason.prolongedDiarrhea)) {
      suggestions.add(diarrheaSuggestion);
    }

    return suggestions;
  }

  ConsultationSuggestion? _detectBloodInStool(List<ToiletRecord> records) {
    final bloodRecords = records.where(
      (r) =>
          r.type == ToiletType.stool &&
          r.stoolCondition?.color == StoolColor.bloodSuspected,
    );
    if (bloodRecords.isEmpty) return null;

    final latest = bloodRecords.reduce(
      (a, b) => a.recordedAt.isAfter(b.recordedAt) ? a : b,
    );

    return ConsultationSuggestion(
      reason: ConsultationSuggestionReason.bloodInStoolSuspected,
      message: '血便の疑いがある記録があります。念のため獣医師にご相談ください。',
      reference: ConsultationReferenceRecord(
        recordId: latest.toiletId,
        recordType: ConsultationRecordType.toiletRecord,
        petId: latest.petId,
        recordedAt: latest.recordedAt,
        label: '血便疑い',
        tags: [
          latest.stoolCondition!.color.wireName,
          latest.stoolCondition!.hardness.wireName,
        ],
      ),
    );
  }

  ConsultationSuggestion? _detectProlongedDiarrhea(List<ToiletRecord> records) {
    final diarrheaRecords = records.where(
      (r) =>
          r.type == ToiletType.stool &&
          r.stoolCondition?.hardness == StoolHardness.diarrhea,
    );
    if (diarrheaRecords.isEmpty) return null;

    final diarrheaDays =
        diarrheaRecords.map((r) => _dateOnly(r.recordedAt)).toSet().toList()
          ..sort();

    final streakDayCount = _longestConsecutiveStreak(diarrheaDays);
    if (streakDayCount < diarrheaStreakThresholdDays) return null;

    final latest = diarrheaRecords.reduce(
      (a, b) => a.recordedAt.isAfter(b.recordedAt) ? a : b,
    );

    return ConsultationSuggestion(
      reason: ConsultationSuggestionReason.prolongedDiarrhea,
      message: '下痢が$diarrheaStreakThresholdDays日以上続いています。獣医師への相談をご検討ください。',
      reference: ConsultationReferenceRecord(
        recordId: latest.toiletId,
        recordType: ConsultationRecordType.toiletRecord,
        petId: latest.petId,
        recordedAt: latest.recordedAt,
        label: '下痢が$streakDayCount日連続',
        tags: [latest.stoolCondition!.hardness.wireName],
      ),
    );
  }

  int _longestConsecutiveStreak(List<DateTime> sortedUniqueDays) {
    var longest = 0;
    var current = 0;
    DateTime? previous;
    for (final day in sortedUniqueDays) {
      if (previous != null && day.difference(previous).inDays == 1) {
        current += 1;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      previous = day;
    }
    return longest;
  }

  DateTime _dateOnly(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
