import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Mirrors spec section 5.1 (通院履歴). All fields except [visitId]/[petId]/
/// [visitedAt] are optional per the spec's requirement column.
class Visit extends Equatable {
  const Visit({
    required this.visitId,
    required this.petId,
    required this.visitedAt,
    this.hospitalName,
    this.diagnosis,
    this.cost,
    this.nextVisitDate,
  });

  final String visitId;
  final String petId;
  final DateTime visitedAt;
  final String? hospitalName;
  final String? diagnosis;
  final int? cost;
  final DateTime? nextVisitDate;

  Visit copyWith({
    DateTime? visitedAt,
    String? hospitalName,
    String? diagnosis,
    int? cost,
    DateTime? nextVisitDate,
    bool clearHospitalName = false,
    bool clearDiagnosis = false,
    bool clearCost = false,
    bool clearNextVisitDate = false,
  }) {
    return Visit(
      visitId: visitId,
      petId: petId,
      visitedAt: visitedAt ?? this.visitedAt,
      hospitalName: clearHospitalName
          ? null
          : (hospitalName ?? this.hospitalName),
      diagnosis: clearDiagnosis ? null : (diagnosis ?? this.diagnosis),
      cost: clearCost ? null : (cost ?? this.cost),
      nextVisitDate: clearNextVisitDate
          ? null
          : (nextVisitDate ?? this.nextVisitDate),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visit_id': visitId,
      'pet_id': petId,
      'visited_at': Timestamp.fromDate(visitedAt),
      'hospital_name': hospitalName,
      'diagnosis': diagnosis,
      'cost': cost,
      'next_visit_date': nextVisitDate == null
          ? null
          : Timestamp.fromDate(nextVisitDate!),
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      visitId: map['visit_id'] as String,
      petId: map['pet_id'] as String,
      visitedAt: _readDate(map['visited_at'])!,
      hospitalName: map['hospital_name'] as String?,
      diagnosis: map['diagnosis'] as String?,
      cost: (map['cost'] as num?)?.toInt(),
      nextVisitDate: _readDate(map['next_visit_date']),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  @override
  List<Object?> get props => [
    visitId,
    petId,
    visitedAt,
    hospitalName,
    diagnosis,
    cost,
    nextVisitDate,
  ];
}
