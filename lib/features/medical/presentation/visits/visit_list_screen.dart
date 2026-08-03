import 'package:flutter/material.dart';

import '../../data/visit_repository.dart';
import '../../domain/models/visit.dart';
import 'visit_form_screen.dart';

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
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('通院履歴')),
      body: StreamBuilder<List<Visit>>(
        stream: repository.watchVisits(uid, petId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final visits = snapshot.data!;
          if (visits.isEmpty) {
            return const Center(child: Text('通院記録がありません'));
          }
          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              return Dismissible(
                key: ValueKey(visit.visitId),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red),
                onDismissed: (_) =>
                    repository.delete(uid, petId, visit.visitId),
                child: ListTile(
                  title: Text(visit.hospitalName ?? '通院記録'),
                  subtitle: Text(
                    '${visit.visitedAt.toLocal().toString().split(' ').first}'
                    '${visit.diagnosis != null ? ' - ${visit.diagnosis}' : ''}',
                  ),
                  trailing: visit.cost != null ? Text('${visit.cost}円') : null,
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
