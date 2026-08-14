/// The wording a reminder notification uses, resolved before it reaches the
/// schedulers.
///
/// The schedulers and the notification adapter run nowhere near a
/// BuildContext -- they are driven by Firestore streams, and the
/// notification itself fires days later with the app closed. They used to
/// solve that by writing the text in Japanese and moving on, so an English
/// user was reminded to give their dog its medicine in Japanese.
///
/// Passing the resolved strings in keeps the schedulers testable and free of
/// localization, and puts the choice of language where the app already knows
/// it. The schedule is rebuilt when the language changes, so the next
/// notification is in the new one.
class ReminderStrings {
  const ReminderStrings({
    required this.medicationBody,
    required this.medicationBodyWithDosage,
    required this.preventionTitle,
    required this.preventionVaccineBody,
    required this.preventionMedicationBody,
    required this.channelName,
    required this.channelDescription,
  });

  /// A fallback for tests and for any code path that builds a scheduler
  /// without the app around it. Not for display: it is one fixed language,
  /// which is the problem this class exists to solve.
  static const ReminderStrings fallback = ReminderStrings(
    medicationBody: 'Time for medication.',
    medicationBodyWithDosage: _dosagePlaceholder,
    preventionTitle: _productPlaceholder,
    preventionVaccineBody: _daysPlaceholder,
    preventionMedicationBody: 'The next dose is due soon.',
    channelName: 'Reminders',
    channelDescription: 'Medication and prevention reminders.',
  );

  static const String _dosagePlaceholder = 'Time for medication ({dosage}).';
  static const String _productPlaceholder = '{productName} reminder';
  static const String _daysPlaceholder =
      'The next dose is due within {days} days.';

  final String medicationBody;

  /// Contains `{dosage}`.
  final String medicationBodyWithDosage;

  /// Contains `{productName}`.
  final String preventionTitle;

  /// Contains `{days}`.
  final String preventionVaccineBody;

  final String preventionMedicationBody;
  final String channelName;
  final String channelDescription;

  String medicationBodyFor(String? dosage) =>
      (dosage == null || dosage.isEmpty)
      ? medicationBody
      : medicationBodyWithDosage.replaceAll('{dosage}', dosage);

  String preventionTitleFor(String productName) =>
      preventionTitle.replaceAll('{productName}', productName);

  String preventionVaccineBodyFor(int days) =>
      preventionVaccineBody.replaceAll('{days}', '$days');
}
