/// Central place for Firestore collection paths so every feature agrees on
/// the same layout: `users/{uid}/pets/{petId}/...`. Keeping this in shared/
/// avoids each feature guessing its own path convention.
class FirestorePaths {
  const FirestorePaths._();

  static String users() => 'users';
  static String user(String uid) => 'users/$uid';
  static String pets(String uid) => 'users/$uid/pets';
  static String pet(String uid, String petId) => 'users/$uid/pets/$petId';

  static String healthRecords(String uid, String petId) =>
      '${pet(uid, petId)}/health_records';
  static String weightRecords(String uid, String petId) =>
      '${pet(uid, petId)}/weight_records';
  static String toiletRecords(String uid, String petId) =>
      '${pet(uid, petId)}/toilet_records';

  static String visits(String uid, String petId) => '${pet(uid, petId)}/visits';
  static String medications(String uid, String petId) =>
      '${pet(uid, petId)}/medications';
  static String preventionPrograms(String uid, String petId) =>
      '${pet(uid, petId)}/prevention_programs';
  static String preventionRecords(String uid, String petId) =>
      '${pet(uid, petId)}/prevention_records';

  static String consultations(String uid, String petId) =>
      '${pet(uid, petId)}/consultations';
  static String reports(String uid, String petId) =>
      '${pet(uid, petId)}/reports';
  static String usageCounters(String uid) => 'users/$uid/usage_counters';
}
