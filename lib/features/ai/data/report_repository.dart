import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/firestore_paths.dart';
import '../models/monthly_report.dart';

/// Firestore-backed store of generated monthly AI reports (spec 7.3),
/// scoped to one owner/pet pair via [FirestorePaths.reports].
abstract class ReportRepository {
  Stream<List<MonthlyReport>> watchReports(String uid, String petId);

  Future<MonthlyReport> save({
    required String uid,
    required String petId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String summaryText,
  });
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  @override
  Stream<List<MonthlyReport>> watchReports(String uid, String petId) {
    return _firestore
        .collection(FirestorePaths.reports(uid, petId))
        .orderBy('generated_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => MonthlyReport.fromMap(d.data())).toList(),
        );
  }

  @override
  Future<MonthlyReport> save({
    required String uid,
    required String petId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String summaryText,
  }) async {
    final report = MonthlyReport(
      reportId: _uuid.v4(),
      petId: petId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      summaryText: summaryText,
      generatedAt: DateTime.now(),
    );
    await _firestore
        .collection(FirestorePaths.reports(uid, petId))
        .doc(report.reportId)
        .set(report.toMap());
    return report;
  }
}
