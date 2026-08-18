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
class VisitListScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.visitListTitle)),
      body: StreamBuilder<List<Visit>>(
        stream: repository.watchVisits(uid, petId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return WanoteLoadingIndicator.centered();
          }
          final visits = snapshot.data!;
          if (visits.isEmpty) {
            return Center(child: Text(l10n.visitListEmptyMessage));
          }
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
                          await repository.delete(uid, petId, visit.visitId);
                        }
                      },
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VisitFormScreen(
                      uid: uid,
                      petId: petId,
                      repository: repository,
                      visit: visit,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                VisitFormScreen(uid: uid, petId: petId, repository: repository),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
