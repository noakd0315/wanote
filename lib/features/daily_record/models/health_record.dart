import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Category tags for a [HealthRecord], per spec section 2.3's example list
/// ("皮膚／食欲不振／元気がない／嘔吐 等"). Kept as a closed enum (with an
/// [other] escape hatch) rather than free text so these tags can double as
/// selectable input candidates for the AI consultation screen, per section
/// 2.4's "タグはAI相談機能の入力候補としても再利用する設計にする". See
/// docs/dog_health_app_spec.md section 2.
enum HealthRecordTag {
  skin,
  appetiteLoss,
  lowEnergy,
  vomiting,
  diarrhea,
  other;

  String get wireName => name;

  static HealthRecordTag fromWireName(String value) {
    return HealthRecordTag.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => HealthRecordTag.other,
    );
  }
}

/// Firestore model for spec section 2.3's photo-attached daily health record.
/// Field names below (`record_id`, `pet_id`, `recorded_at`, `photos`, `tags`,
/// `memo`) intentionally mirror the spec table exactly so other agents'
/// Firestore reads (if any) stay compatible.
class HealthRecord extends Equatable {
  const HealthRecord({
    required this.recordId,
    required this.petId,
    required this.recordedAt,
    this.photos = const [],
    this.tags = const [],
    this.memo,
  });

  /// Spec 2.2: "写真添付（複数枚、最大4〜6枚程度を想定）" — we cap at 6.
  static const int maxPhotos = 6;

  final String recordId;
  final String petId;
  final DateTime recordedAt;

  /// Download URLs of already-uploaded (compressed) photos.
  final List<String> photos;
  final List<HealthRecordTag> tags;
  final String? memo;

  HealthRecord copyWith({
    DateTime? recordedAt,
    List<String>? photos,
    List<HealthRecordTag>? tags,
    String? memo,
    bool clearMemo = false,
  }) {
    return HealthRecord(
      recordId: recordId,
      petId: petId,
      recordedAt: recordedAt ?? this.recordedAt,
      photos: photos ?? this.photos,
      tags: tags ?? this.tags,
      memo: clearMemo ? null : (memo ?? this.memo),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'pet_id': petId,
      'recorded_at': Timestamp.fromDate(recordedAt),
      'photos': photos,
      'tags': tags.map((t) => t.wireName).toList(),
      'memo': memo,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    final rawRecordedAt = map['recorded_at'];
    final recordedAt = rawRecordedAt is Timestamp
        ? rawRecordedAt.toDate()
        : DateTime.parse(rawRecordedAt as String);
    return HealthRecord(
      recordId: map['record_id'] as String,
      petId: map['pet_id'] as String,
      recordedAt: recordedAt,
      photos: (map['photos'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      tags: (map['tags'] as List<dynamic>? ?? const [])
          .map((e) => HealthRecordTag.fromWireName(e as String))
          .toList(),
      memo: map['memo'] as String?,
    );
  }

  @override
  List<Object?> get props => [recordId, petId, recordedAt, photos, tags, memo];
}
