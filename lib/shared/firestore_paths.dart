/// Central place for Firestore collection paths so every feature agrees on
/// the same layout: `users/{uid}/pets/{petId}/...`. Keeping this in shared/
/// avoids each feature guessing its own path convention.
class FirestorePaths {
  const FirestorePaths._();

  static String users() => 'users';
  static String user(String uid) => 'users/$uid';
  static String pets(String uid) => 'users/$uid/pets';
  static String pet(String uid, String petId) => 'users/$uid/pets/$petId';

  // Subcollection names are named constants rather than literals inlined in
  // the helpers below, so [petSubcollectionNames] can be built from the same
  // values the helpers use.
  //
  // Account deletion is why that matters: the client SDK has no recursive
  // delete, so FirestoreAccountDocumentEraser has to walk the subcollections
  // by name. A pet subcollection missing from [petSubcollectionNames] is one
  // that survives "delete my account" -- silently, since nothing else reads
  // it afterwards. Adding a subcollection means adding it here.
  static const healthRecordsName = 'health_records';
  static const weightRecordsName = 'weight_records';
  static const toiletRecordsName = 'toilet_records';
  static const visitsName = 'visits';
  static const medicationsName = 'medications';
  static const preventionProgramsName = 'prevention_programs';
  static const preventionRecordsName = 'prevention_records';
  static const consultationsName = 'consultations';
  static const reportsName = 'reports';

  /// Every subcollection that can exist under a pet document.
  static const petSubcollectionNames = <String>[
    healthRecordsName,
    weightRecordsName,
    toiletRecordsName,
    visitsName,
    medicationsName,
    preventionProgramsName,
    preventionRecordsName,
    consultationsName,
    reportsName,
  ];

  /// Account-level subcollections the *client* is allowed to delete.
  ///
  /// Deliberately not the whole list: `rewards`, `pending_grants` and
  /// `redeemed_codes` are server-owned (firestore.rules denies clients even a
  /// read), so account deletion has to ask the Worker to remove those --
  /// see functions/src/routes/deleteAccountServerData.ts.
  static const ownedAccountSubcollectionNames = <String>[
    'pets',
    'usage_counters',
  ];

  static String healthRecords(String uid, String petId) =>
      '${pet(uid, petId)}/$healthRecordsName';
  static String weightRecords(String uid, String petId) =>
      '${pet(uid, petId)}/$weightRecordsName';
  static String toiletRecords(String uid, String petId) =>
      '${pet(uid, petId)}/$toiletRecordsName';

  static String visits(String uid, String petId) =>
      '${pet(uid, petId)}/$visitsName';
  static String medications(String uid, String petId) =>
      '${pet(uid, petId)}/$medicationsName';
  static String preventionPrograms(String uid, String petId) =>
      '${pet(uid, petId)}/$preventionProgramsName';
  static String preventionRecords(String uid, String petId) =>
      '${pet(uid, petId)}/$preventionRecordsName';

  static String consultations(String uid, String petId) =>
      '${pet(uid, petId)}/$consultationsName';
  static String reports(String uid, String petId) =>
      '${pet(uid, petId)}/$reportsName';
  static String usageCounters(String uid) => 'users/$uid/usage_counters';
}
