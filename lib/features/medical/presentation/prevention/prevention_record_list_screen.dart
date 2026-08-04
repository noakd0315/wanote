import 'package:flutter/material.dart';

import '../../data/certificate_ocr_service.dart';
import '../../data/prevention_record_repository.dart';
import '../../domain/models/prevention_program.dart';
import '../../domain/models/prevention_record.dart';
import 'prevention_record_form_screen.dart';

/// Administration history for one [program] (spec 5.3's prevention_records).
class PreventionRecordListScreen extends StatelessWidget {
  PreventionRecordListScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.program,
    PreventionRecordRepository? repository,
    CertificateOcrService? ocrService,
  }) : repository = repository ?? FirestorePreventionRecordRepository(),
       // Wired to the real backend by default so certificate photo capture +
       // AI-OCR auto-fill actually runs for every prevention type (vaccine,
       // heartworm, flea/tick all share this one form) -- previously this
       // was left null everywhere it was constructed, so the OCR button
       // always showed "自動読取は準備中" even though functions/src/routes/
       // ocr.ts and this HTTP client both already existed.
       ocrService = ocrService ?? HttpCertificateOcrService.fromEnvironment();

  final String uid;
  final String petId;
  final PreventionProgram program;
  final PreventionRecordRepository repository;
  final CertificateOcrService ocrService;

  /// PM request: ワクチンは「接種履歴」、薬（フィラリア／ノミ・ダニ予防）は
  /// 「投薬履歴」-- vaccines are injected ("接種"), heartworm/flea-tick
  /// prevention is administered as an oral/topical medication ("投薬").
  bool get _isVaccine => program.type == PreventionType.vaccine;
  String get _historyLabel => _isVaccine ? '接種履歴' : '投薬履歴';
  String get _recordLabel => _isVaccine ? '接種記録' : '投薬記録';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through, per the PM's request to scatter the
      // pattern across every non-input-form screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('${program.productName} の$_historyLabel')),
      body: StreamBuilder<List<PreventionRecord>>(
        stream: repository.watchRecordsForProgram(
          uid,
          petId,
          program.programId,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!;
          if (records.isEmpty) {
            return Center(child: Text('$_recordLabelがありません'));
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Dismissible(
                key: ValueKey(record.recordId),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red),
                onDismissed: (_) =>
                    repository.delete(uid, petId, record.recordId),
                child: ListTile(
                  leading: record.certificateFile != null
                      ? const Icon(Icons.description)
                      : null,
                  title: Text(
                    record.administeredAt.toLocal().toString().split(' ').first,
                  ),
                  subtitle: Text(
                    record.nextDueDate == null
                        ? (record.hospitalName ?? '')
                        : '次回: ${record.nextDueDate!.toLocal().toString().split(' ').first}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PreventionRecordFormScreen(
                        uid: uid,
                        petId: petId,
                        program: program,
                        repository: repository,
                        record: record,
                        ocrService: ocrService,
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
            builder: (_) => PreventionRecordFormScreen(
              uid: uid,
              petId: petId,
              program: program,
              repository: repository,
              ocrService: ocrService,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
