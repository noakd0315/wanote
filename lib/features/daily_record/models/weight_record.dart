import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for spec section 3.3's weight record. Field names below
/// (`weight_id`, `pet_id`, `measured_at`, `weight_kg`) mirror the spec table
/// exactly. `measured_at` is a `date` per the spec (no time-of-day meaning),
/// but we store/read it as a Firestore Timestamp at midnight for simplicity;
/// callers should treat only the date components as meaningful.
class WeightRecord extends Equatable {
  const WeightRecord({
    required this.weightId,
    required this.petId,
    required this.measuredAt,
    required this.weightKg,
  });

  final String weightId;
  final String petId;
  final DateTime measuredAt;

  /// decimal(4,1) per spec — we don't enforce the precision here, that's a
  /// form-level validation concern.
  final double weightKg;

  WeightRecord copyWith({DateTime? measuredAt, double? weightKg}) {
    return WeightRecord(
      weightId: weightId,
      petId: petId,
      measuredAt: measuredAt ?? this.measuredAt,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weight_id': weightId,
      'pet_id': petId,
      'measured_at': Timestamp.fromDate(measuredAt),
      'weight_kg': weightKg,
    };
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    final rawMeasuredAt = map['measured_at'];
    final measuredAt = rawMeasuredAt is Timestamp
        ? rawMeasuredAt.toDate()
        : DateTime.parse(rawMeasuredAt as String);
    return WeightRecord(
      weightId: map['weight_id'] as String,
      petId: map['pet_id'] as String,
      measuredAt: measuredAt,
      weightKg: (map['weight_kg'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [weightId, petId, measuredAt, weightKg];
}
