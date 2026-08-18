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
import '../../../shared/widgets/wanote_loading_indicator.dart';

/// Spec 4.2's one-tap timeline, plus the anomaly-driven AI-consultation
/// banner from spec 4.4.
///
/// [onConsultationSuggested] is a hook point only: this feature must not
/// import/depend on features/ai/'s screens directly (see AnomalyDetector's
/// doc comment for why). Wire it up to actual navigation to the AI
/// consultation screen at the app-shell level, passing the
/// [ConsultationSuggestion.reference] through as prefill context.
///
/// **Only the banner's button calls it.** It used to fire on its own
/// whenever the record stream delivered something the detector flagged,
/// and the shell turned that into a pushed screen -- so an owner with one
/// bloody-stool record on file had the AI consultation screen open itself
/// over the home screen on every launch and every sign-in, unasked (PM
/// report, 2026-08-16). The sections sit in an IndexedStack, so this
/// screen's stream runs whether or not its tab is the one on screen.
///
/// The banner is the whole feature: it says what was noticed and offers a
/// button. Navigating for the owner is not a stronger version of that, it
/// is a different and worse thing.
class ToiletRecordTimelineScreen extends StatefulWidget {
  const ToiletRecordTimelineScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.healthRecordRepository,
    this.anomalyDetector = const AnomalyDetector(),
    this.onConsultationSuggested,
    this.onConsultAboutRecord,
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

  /// Passed to the detail screen's AI-consultation button. Separate from
  /// [onConsultationSuggested] because nothing was detected here -- the
  /// owner picked a record and asked about it.
  final void Function(ConsultationReferenceRecord reference)?
  onConsultAboutRecord;

  @override
  State<ToiletRecordTimelineScreen> createState() =>
      _ToiletRecordTimelineScreenState();
}

class _ToiletRecordTimelineScreenState
    extends State<ToiletRecordTimelineScreen> {
  /// Whether the frequency chart is showing instead of the record list. Not
  /// persisted: unlike the weight screen's chart/table choice, this is a
  /// glance at a summary rather than a preferred way of reading the data.
  bool _showChart = false;

  /// How far back the list reaches (PM request: "トイレ記録も期間で絞り込み
  /// たい"). Records accumulate several a day, so within a month the list is
  /// long enough that scrolling to last week is work.
  _ToiletPeriod _period = _ToiletPeriod.oneMonth;

  /// Which kind of record the list is showing (PM request, 2026-08-18).
  _TypeFilter _typeFilter = _TypeFilter.all;

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
  /// Asks before removing a record.
  ///
  /// This button used to delete on the first tap. It sits at the end of
  /// every row, next to a row that is itself tappable, and there is no
  /// undo -- so the one tap it took to lose a record was the same tap it
  /// took to open one. The weight list now shares this shape, and both ask
  /// (PM: 統一してほしい, 2026-08-18).
  Future<void> _confirmDelete(ToiletRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.toiletStoolDeleteConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.delete(uid: widget.uid, record: record);
  }

  /// Opens the record form, which asks which kind it is.
  ///
  /// The screen used to have a button per type, which was the only way in.
  /// Choosing on the form keeps the entry point single, the way every other
  /// list screen works.
  void _recordToilet() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToiletRecordFormScreen(
          uid: widget.uid,
          petId: widget.petId,
          repository: widget.repository,
          healthRecordRepository: widget.healthRecordRepository,
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
                  return WanoteLoadingIndicator.centered();
                }
                final allRecords = snapshot.data ?? const <ToiletRecord>[];
                final now = DateTime.now();
                // The filter is the reader's window on the list. The
                // detector keeps its own (one month, fixed): narrowing the
                // list must not silently switch the warnings off.
                final records = _typeFilter.filter(
                  _period.filter(allRecords, now),
                );
                final currentSuggestions = widget.anomalyDetector.detect(
                  records: allRecords,
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
                    // Filter, not "add". The two full-width buttons that
                    // used to sit here were the only way in, and they read
                    // as a filter anyway -- a pair of segments above a list
                    // is what filtering looks like (PM, 2026-08-18).
                    // Recording moved to the FAB, like every other screen.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_TypeFilter>(
                          showSelectedIcon: false,
                          segments: _TypeFilter.values
                              .map(
                                (f) => ButtonSegment(
                                  value: f,
                                  label: Text(f.label(l10n)),
                                ),
                              )
                              .toList(),
                          selected: {_typeFilter},
                          onSelectionChanged: (selection) =>
                              setState(() => _typeFilter = selection.first),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_ToiletPeriod>(
                          // Same reason as the weight chart's: the check
                          // mark is laid out inside the segment, so it
                          // widens whichever one is selected.
                          showSelectedIcon: false,
                          segments: _ToiletPeriod.values
                              .map(
                                (p) => ButtonSegment(
                                  value: p,
                                  label: Text(p.label(l10n)),
                                ),
                              )
                              .toList(),
                          selected: {_period},
                          onSelectionChanged: (selection) =>
                              setState(() => _period = selection.first),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: records.isEmpty
                          ? Center(child: Text(l10n.commonNoRecordsYet))
                          : ListView.builder(
                              itemCount: records.length,
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final isUrine = record.type == ToiletType.urine;
                                final subtitleParts = [
                                  // Colour and volume read as one line
                                  // joined by "/", the way stool's hardness
                                  // and colour already do (PM, 2026-08-18).
                                  // They were two separate parts, so a
                                  // urine row was punctuated differently
                                  // from the stool row above it.
                                  if (isUrine)
                                    if (record.urineColor != null &&
                                        record.urineVolume != null)
                                      l10n.toiletUrineConditionSubtitle(
                                        urineColorLabel(
                                          context,
                                          record.urineColor!,
                                        ),
                                        urineVolumeLabel(
                                          context,
                                          record.urineVolume!,
                                        ),
                                      )
                                    else if (record.urineColor != null)
                                      l10n.toiletUrineColorSubtitle(
                                        urineColorLabel(
                                          context,
                                          record.urineColor!,
                                        ),
                                      )
                                    else if (record.urineVolume != null)
                                      l10n.toiletUrineVolumeSubtitle(
                                        urineVolumeLabel(
                                          context,
                                          record.urineVolume!,
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
                                  // Both types open now (PM request). The
                                  // detail screen is also where a record can
                                  // be taken to the AI, which is not
                                  // something a list row can offer.
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ToiletRecordDetailScreen(
                                        uid: widget.uid,
                                        record: record,
                                        repository: widget.repository,
                                        onConsultAi: widget.onConsultAboutRecord,
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
                                      // One separator for the whole row.
                                      // Colour and volume were joined with
                                      // "/" while the location hung off the
                                      // end with "・", so a single row used
                                      // two (PM, 2026-08-18).
                                      : Text(subtitleParts.join(' / ')),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _confirmDelete(record),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      // One "+", like every other list screen. Which kind is chosen on the
      // form itself, so the two records are entered the same way rather
      // than one through a dedicated button and one through a screen.
      floatingActionButton: _showChart
          ? null
          : FloatingActionButton(
              onPressed: _recordToilet,
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// How far back the timeline list reaches.
///
/// Private to this screen rather than a domain type: it filters what is
/// displayed and nothing else. The weight chart's [WeightTrendPeriod] is a
/// different thing -- it feeds a calculation whose results depend on it.
enum _ToiletPeriod {
  oneWeek,
  oneMonth,
  threeMonths,
  all;

  String label(AppLocalizations l10n) => switch (this) {
    _ToiletPeriod.oneWeek => l10n.toiletPeriodOneWeek,
    _ToiletPeriod.oneMonth => l10n.toiletPeriodOneMonth,
    _ToiletPeriod.threeMonths => l10n.toiletPeriodThreeMonths,
    _ToiletPeriod.all => l10n.toiletPeriodAll,
  };

  List<ToiletRecord> filter(List<ToiletRecord> records, DateTime now) {
    final days = switch (this) {
      _ToiletPeriod.oneWeek => 7,
      _ToiletPeriod.oneMonth => 31,
      _ToiletPeriod.threeMonths => 92,
      _ToiletPeriod.all => null,
    };
    if (days == null) return records;
    final cutoff = now.subtract(Duration(days: days));
    return records.where((r) => !r.recordedAt.isBefore(cutoff)).toList();
  }
}


/// Which kind of record the timeline shows.
enum _TypeFilter {
  all,
  urine,
  stool;

  String label(AppLocalizations l10n) => switch (this) {
    _TypeFilter.all => l10n.toiletFilterAll,
    _TypeFilter.urine => l10n.toiletUrineLabel,
    _TypeFilter.stool => l10n.toiletStoolLabel,
  };

  List<ToiletRecord> filter(List<ToiletRecord> records) => switch (this) {
    _TypeFilter.all => records,
    _TypeFilter.urine => records
        .where((r) => r.type == ToiletType.urine)
        .toList(),
    _TypeFilter.stool => records
        .where((r) => r.type == ToiletType.stool)
        .toList(),
  };
}
