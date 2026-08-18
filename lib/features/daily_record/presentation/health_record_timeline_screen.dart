import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/health_record_repository.dart';
import '../models/health_record.dart';
import 'health_record_detail_screen.dart';
import 'health_record_form_screen.dart';
import 'widgets/health_record_labels.dart';
import '../../../shared/utils/formatting.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';
import '../../../shared/widgets/patterned_background.dart';

/// How far back the timeline shows.
enum HealthRecordPeriod {
  all,
  lastMonth,
  lastThreeMonths,
  lastYear;

  /// The earliest record to show, or null for no limit.
  DateTime? cutoffFrom(DateTime now) => switch (this) {
    HealthRecordPeriod.all => null,
    HealthRecordPeriod.lastMonth => now.subtract(const Duration(days: 30)),
    HealthRecordPeriod.lastThreeMonths => now.subtract(
      const Duration(days: 90),
    ),
    HealthRecordPeriod.lastYear => now.subtract(const Duration(days: 365)),
  };
}

/// Spec 2.2: "記録一覧（タイムライン表示、日付降順）", with filters.
///
/// PM request: a timeline that only grows becomes unreadable, and the
/// question being asked of it is usually narrow -- "the skin trouble in
/// spring", "everything from last month". Filtering happens here rather
/// than in the query: the records are already streamed in full for the
/// charts, and a Firestore range filter on top of the tag filter would need
/// another composite index for each combination.
class HealthRecordTimelineScreen extends StatefulWidget {
  const HealthRecordTimelineScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
  });

  final String uid;
  final String petId;
  final HealthRecordRepository repository;

  @override
  State<HealthRecordTimelineScreen> createState() =>
      _HealthRecordTimelineScreenState();
}

class _HealthRecordTimelineScreenState
    extends State<HealthRecordTimelineScreen> {
  HealthRecordPeriod _period = HealthRecordPeriod.all;
  HealthRecordTag? _tag;

  String _periodLabel(AppLocalizations l10n, HealthRecordPeriod period) =>
      switch (period) {
        HealthRecordPeriod.all => l10n.healthRecordFilterAllPeriods,
        HealthRecordPeriod.lastMonth => l10n.healthRecordFilterLastMonth,
        HealthRecordPeriod.lastThreeMonths =>
          l10n.healthRecordFilterLastThreeMonths,
        HealthRecordPeriod.lastYear => l10n.healthRecordFilterLastYear,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.healthRecordTimelineTitle)),
      body: StreamBuilder<List<HealthRecord>>(
        stream: widget.repository.watchTimeline(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return WanoteLoadingIndicator.centered();
          }
          final records = snapshot.data ?? const <HealthRecord>[];
          // watchTimeline already orders by recorded_at descending, but sort
          // defensively in case a caller passes a differently-ordered fake.
          final sorted = [...records]
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
          if (sorted.isEmpty) {
            return Center(child: Text(l10n.commonNoRecordsYet));
          }
          final cutoff = _period.cutoffFrom(DateTime.now());
          final shown = sorted
              .where(
                (r) =>
                    (cutoff == null || !r.recordedAt.isBefore(cutoff)) &&
                    (_tag == null || r.tags.contains(_tag)),
              )
              .toList();
          return Column(
            children: [
              _buildFilters(l10n),
              Expanded(
                child: shown.isEmpty
                    // Deliberately not the same message as having no records
                    // at all: with filters on, that wording would read as the
                    // records having been lost.
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.healthRecordFilterNoMatches),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(() {
                                _period = HealthRecordPeriod.all;
                                _tag = null;
                              }),
                              child: Text(l10n.healthRecordFilterClear),
                            ),
                          ],
                        ),
                      )
                    : _buildList(context, l10n, shown),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HealthRecordFormScreen(
                uid: widget.uid,
                petId: widget.petId,
                repository: widget.repository,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<HealthRecordPeriod>(
              isExpanded: true,
              value: _period,
              onChanged: (value) =>
                  setState(() => _period = value ?? HealthRecordPeriod.all),
              items: [
                for (final period in HealthRecordPeriod.values)
                  DropdownMenuItem(
                    value: period,
                    child: Text(_periodLabel(l10n, period)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<HealthRecordTag?>(
              isExpanded: true,
              value: _tag,
              onChanged: (value) => setState(() => _tag = value),
              items: [
                DropdownMenuItem(
                  child: Text(l10n.healthRecordFilterAllTags),
                ),
                for (final tag in HealthRecordTag.values)
                  DropdownMenuItem(
                    value: tag,
                    child: Text(healthRecordTagLabel(context, tag)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<HealthRecord> shown,
  ) {
    return ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final record = shown[index];
              return ListTile(
                leading: record.photos.isNotEmpty
                    ? const Icon(Icons.photo)
                    : const Icon(Icons.notes),
                title: Text(
                  formatDateTime(context, record.recordedAt),
                ),
                subtitle: Text(
                  record.tags.isEmpty
                      ? (record.memo ?? '')
                      : record.tags
                            .map((t) => healthRecordTagLabel(context, t))
                            .join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatternedBackground(
                        child: HealthRecordDetailScreen(
                          uid: widget.uid,
                          record: record,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
    );
  }
}
