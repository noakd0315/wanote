import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/consultation_reference_record.dart';
import '../data/toilet_record_repository.dart';
import '../domain/anomaly_detector.dart';
import '../models/toilet_record.dart';
import 'toilet_frequency_chart_view.dart';
import 'toilet_record_form_screen.dart';
import 'widgets/toilet_labels.dart';
import '../data/health_record_repository.dart';
import 'toilet_record_detail_screen.dart';

/// Spec 4.2's one-tap timeline, plus the anomaly-driven AI-consultation
/// banner from spec 4.4.
///
/// [onConsultationSuggested] is a hook point only: this feature must not
/// import/depend on features/ai/'s screens directly (see AnomalyDetector's
/// doc comment for why). Wire it up to actual navigation to the AI
/// consultation screen at the app-shell level, passing the
/// [ConsultationSuggestion.reference] through as prefill context.
class ToiletRecordTimelineScreen extends StatefulWidget {
  const ToiletRecordTimelineScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.healthRecordRepository,
    this.anomalyDetector = const AnomalyDetector(),
    this.onConsultationSuggested,
  });

  final String uid;
  final String petId;
  final ToiletRecordRepository repository;

  /// Passed through to the stool form, which offers to copy the record into
  /// the daily log. Null in tests that build this screen alone.
  final HealthRecordRepository? healthRecordRepository;
  final AnomalyDetector anomalyDetector;
  final void Function(ConsultationSuggestion suggestion)?
  onConsultationSuggested;

  @override
  State<ToiletRecordTimelineScreen> createState() =>
      _ToiletRecordTimelineScreenState();
}

class _ToiletRecordTimelineScreenState
    extends State<ToiletRecordTimelineScreen> {
  /// Per-reason "last shown" timestamps, for AnomalyDetector's dedupe-by-day
  /// input. Held in memory here for simplicity; a production build should
  /// persist this (e.g. shared_preferences or a small Firestore doc) so the
  /// suppression survives app restarts. See AnomalyDetector.detect's doc.
  final Map<ConsultationSuggestionReason, DateTime> _lastSuggestedAt = {};

  /// Whether the frequency chart is showing instead of the record list. Not
  /// persisted: unlike the weight screen's chart/table choice, this is a
  /// glance at a summary rather than a preferred way of reading the data.
  bool _showChart = false;

  /// Reasons the owner has put away in this session.
  ///
  /// The banner used to reappear on every visit with no way to dismiss it,
  /// including after the vet had already been called (PM request). Kept in
  /// memory rather than persisted: a warning that is still true tomorrow
  /// should say so again.
  final Set<ConsultationSuggestionReason> _dismissed = {};

  /// A screen, not a dialog.
  ///
  /// The dialog was the faster path for the app's most frequent record, but
  /// the keyboard broke it the moment the location field was focused, and it
  /// left two different ways to enter the same kind of thing. PM decision:
  /// one screen, the same one stool uses.
  void _recordUrine() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToiletRecordFormScreen(
          uid: widget.uid,
          petId: widget.petId,
          repository: widget.repository,
          type: ToiletType.urine,
        ),
      ),
    );
  }

  /// The banner's wording, built here rather than carried on the
  /// suggestion. The detector has no BuildContext and cannot localize, which
  /// is how its Japanese literal ended up on the English screen.
  String _suggestionMessage(
    AppLocalizations l10n,
    ConsultationSuggestion suggestion,
  ) => switch (suggestion.reason) {
    ConsultationSuggestionReason.bloodInStoolSuspected =>
      l10n.anomalyBloodInStoolMessage,
    ConsultationSuggestionReason.prolongedDiarrhea =>
      l10n.anomalyProlongedDiarrheaMessage(suggestion.streakDayCount ?? 0),
  };

  void _handleSuggestions(List<ToiletRecord> records) {
    final now = DateTime.now();
    final suggestions = widget.anomalyDetector.detect(
      records: records,
      now: now,
      lastSuggestedAt: _lastSuggestedAt,
    );
    if (suggestions.isEmpty) return;
    for (final suggestion in suggestions) {
      _lastSuggestedAt[suggestion.reason] = now;
      widget.onConsultationSuggested?.call(suggestion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _showChart
              ? l10n.toiletFrequencyChartTitle
              : l10n.toiletRecordTimelineTitle,
        ),
        actions: [
          // Swaps the body in place instead of pushing the chart as its own
          // screen. Pushing replaced this AppBar with one that had no
          // actions, so the button that got you there disappeared (PM
          // report: "グラフ表示をすると、ヘッダー部のメニューが消えて
          // しまいます") -- the weight screen has always toggled in place.
          IconButton(
            tooltip: _showChart
                ? l10n.toiletShowTimelineTooltip
                : l10n.toiletShowChartTooltip,
            icon: Icon(_showChart ? Icons.list_alt : Icons.bar_chart),
            onPressed: () => setState(() => _showChart = !_showChart),
          ),
        ],
      ),
      body: _showChart
          ? ToiletFrequencyChartView(
              uid: widget.uid,
              petId: widget.petId,
              repository: widget.repository,
            )
          : StreamBuilder<List<ToiletRecord>>(
              stream: widget.repository.watchTimeline(widget.uid, widget.petId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data ?? const <ToiletRecord>[];
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _handleSuggestions(records),
                );

                final now = DateTime.now();
                final currentSuggestions = widget.anomalyDetector.detect(
                  records: records,
                  now: now,
                  lastSuggestedAt: const {},
                );
                final remaining = currentSuggestions
                    .where((s) => !_dismissed.contains(s.reason))
                    .toList();
                final visibleSuggestion = remaining.isEmpty
                    ? null
                    : remaining.first;

                return Column(
                  children: [
                    if (visibleSuggestion != null)
                      MaterialBanner(
                        content: Text(
                          _suggestionMessage(l10n, visibleSuggestion),
                        ),
                        leading: const Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => widget.onConsultationSuggested
                                ?.call(visibleSuggestion),
                            child: Text(l10n.toiletConsultAiButtonLabel),
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _dismissed.add(visibleSuggestion.reason),
                            ),
                            child: Text(l10n.anomalyDismissButton),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _recordUrine,
                              icon: const Icon(Icons.water_drop),
                              label: Text(l10n.toiletUrineLabel),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ToiletRecordFormScreen(
                                      uid: widget.uid,
                                      petId: widget.petId,
                                      repository: widget.repository,
                                      healthRecordRepository:
                                          widget.healthRecordRepository,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.circle),
                              label: Text(l10n.toiletStoolLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: records.isEmpty
                          ? Center(child: Text(l10n.commonNoRecordsYet))
                          : ListView.builder(
                              itemCount: records.length,
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final isUrine = record.type == ToiletType.urine;
                                final subtitleParts = [
                                  if (isUrine)
                                    if (record.urineColor != null)
                                      l10n.toiletUrineColorSubtitle(
                                        urineColorLabel(
                                          context,
                                          record.urineColor!,
                                        ),
                                      ),
                                  if (!isUrine)
                                    l10n.toiletStoolConditionSubtitle(
                                      record.stoolCondition != null
                                          ? stoolHardnessLabel(
                                              context,
                                              record.stoolCondition!.hardness,
                                            )
                                          : '-',
                                      record.stoolCondition != null
                                          ? stoolColorLabel(
                                              context,
                                              record.stoolCondition!.color,
                                            )
                                          : '-',
                                    ),
                                  if (record.location != null)
                                    l10n.toiletLocationSubtitle(
                                      record.location!,
                                    ),
                                ];
                                return ListTile(
                                  // Stool only. A urine record holds nothing
                                  // a list row does not already show, and
                                  // carries no photo (PM: 排尿は写真不要),
                                  // so a detail screen for it would open on
                                  // the same three facts.
                                  onTap: isUrine
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                ToiletRecordDetailScreen(
                                                  uid: widget.uid,
                                                  record: record,
                                                  repository: widget.repository,
                                                ),
                                          ),
                                        ),
                                  leading: Icon(
                                    isUrine ? Icons.water_drop : Icons.circle,
                                  ),
                                  title: Text(
                                    DateFormat(
                                      'yyyy/MM/dd HH:mm',
                                    ).format(record.recordedAt),
                                  ),
                                  subtitle: subtitleParts.isEmpty
                                      ? null
                                      : Text(subtitleParts.join(' ・ ')),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => widget.repository.delete(
                                      uid: widget.uid,
                                      record: record,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
