import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import '../../domain/models/medication.dart';
import 'medication_form_screen.dart';

/// Spec 5.2 list screen.
class MedicationListScreen extends StatelessWidget {
  MedicationListScreen({
    super.key,
    required this.uid,
    required this.petId,
    MedicationRepository? repository,
  }) : repository = repository ?? FirestoreMedicationRepository();

  final String uid;
  final String petId;
  final MedicationRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('薬の記録')),
      body: StreamBuilder<List<Medication>>(
        stream: repository.watchMedications(uid, petId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final medications = snapshot.data!;
          if (medications.isEmpty) {
            return const Center(child: Text('薬の記録がありません'));
          }
          return ListView.builder(
            itemCount: medications.length,
            itemBuilder: (context, index) {
              final medication = medications[index];
              return Dismissible(
                key: ValueKey(medication.medicationId),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red),
                onDismissed: (_) =>
                    repository.delete(uid, petId, medication.medicationId),
                child: ListTile(
                  title: Text(medication.name),
                  subtitle: Text(
                    medication.isOngoing
                        ? '継続中'
                        : '〜${medication.endDate!.toLocal().toString().split(' ').first}',
                  ),
                  trailing: medication.reminderEnabled
                      ? const Icon(Icons.notifications_active)
                      : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MedicationFormScreen(
                        uid: uid,
                        petId: petId,
                        repository: repository,
                        medication: medication,
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
            builder: (_) => MedicationFormScreen(
              uid: uid,
              petId: petId,
              repository: repository,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
