import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/visit_repository.dart';
import '../../domain/models/visit.dart';
import 'visit_form_screen.dart';
import '../../../../shared/widgets/stream_error_view.dart';
import '../../../../shared/widgets/wanote_loading_indicator.dart';
import '../widgets/confirm_delete.dart';

/// Spec 5.1 list/detail screen. Kept intentionally simple (per task scope):
/// a single scrollable list with inline delete, tapping opens the edit form.
class VisitListScreen extends StatefulWidget {
  VisitListScreen({
    super.key,
    required this.uid,
    required this.petId,
    VisitRepository? repository,
  }) : repository = repository ?? FirestoreVisitRepository();

  final String uid;
  final String petId;
  final VisitRepository repository;

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  /// How far back the list reaches (PM request, 2026-08-21: 通院・薬も
  /// 絞れるようにしたい). Visits accumulate slowly, so this starts at
  /// everything -- unlike the toilet list, where a month is already long.
  _VisitPeriod _period = _VisitPeriod.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.visitListTitle)),
      body: StreamBuilder<List<Visit>>(
        stream: widget.repository.watchVisits(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return WanoteLoadingIndicator.centered();
          }
          final allVisits = snapshot.data!;
          if (allVisits.isEmpty) {
            return Center(child: Text(l10n.visitListEmptyMessage));
          }
          final visits = _period.filter(allVisits, DateTime.now());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_VisitPeriod>(
                    segments: [
                      for (final period in _VisitPeriod.values)
                        ButtonSegment(
                          value: period,
                          label: Text(period.label(l10n)),
                        ),
                    ],
                    selected: {_period},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _period = selection.first),
                  ),
                ),
              ),
              if (visits.isEmpty)
                // Not the same as having no visits at all: saying so would
                // read as the records having been lost.
                Expanded(child: Center(child: Text(l10n.filterNoMatchMessage)))
              else
                Expanded(child: _buildList(context, l10n, visits)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VisitFormScreen(
              uid: widget.uid,
              petId: widget.petId,
              repository: widget.repository,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<Visit> visits,
  ) {
    return ListView.builder(
      itemCount: visits.length,
      itemBuilder: (context, index) {
        final visit = visits[index];
        return ListTile(
          title: Text(visit.hospitalName ?? l10n.visitFallbackTitle),
          subtitle: Text(
            '${visit.visitedAt.toLocal().toString().split(' ').first}'
            '${visit.diagnosis != null ? ' - ${visit.diagnosis}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visit.cost != null)
                Text(l10n.visitCostYenSuffix(visit.cost!)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirmDelete(
                    context,
                    l10n.visitDeleteConfirmationMessage,
                  )) {
                    await widget.repository.delete(
                      widget.uid,
                      widget.petId,
                      visit.visitId,
                    );
                  }
                },
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VisitFormScreen(
                uid: widget.uid,
                petId: widget.petId,
                repository: widget.repository,
                visit: visit,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How far back the visit list reaches.
enum _VisitPeriod {
  all,
  threeMonths,
  oneYear;

  String label(AppLocalizations l10n) => switch (this) {
    _VisitPeriod.all => l10n.filterPeriodAll,
    _VisitPeriod.threeMonths => l10n.filterPeriodThreeMonths,
    _VisitPeriod.oneYear => l10n.filterPeriodOneYear,
  };

  List<Visit> filter(List<Visit> visits, DateTime now) {
    final days = switch (this) {
      _VisitPeriod.all => null,
      _VisitPeriod.threeMonths => 92,
      _VisitPeriod.oneYear => 366,
    };
    if (days == null) return visits;
    final cutoff = now.subtract(Duration(days: days));
    return visits.where((v) => !v.visitedAt.isBefore(cutoff)).toList();
  }
}
