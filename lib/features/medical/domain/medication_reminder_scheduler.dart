import 'models/medication.dart';
import 'reminder_scheduler.dart';
import 'reminder_strings.dart';

/// Pure computation of the daily dose reminders spec 5.2 asks for
/// (`reminder_enabled` + `reminder_time` on a medication).
///
/// Separate from [ReminderScheduler], which handles prevention programs: the
/// two answer different questions. A prevention reminder is a one-off "your
/// next dose is coming up in N days"; a medication reminder is "take it at
/// 08:00, every day, for as long as the course lasts". They only share the
/// [ScheduledReminder] output type so the adapter can apply both in one pass.
///
/// The medication fields have been stored since the form screen was built,
/// but nothing ever read them -- these reminders had never fired.
class MedicationReminderScheduler {
  const MedicationReminderScheduler({
    this.strings = ReminderStrings.fallback,
  });

  /// The wording for the notifications this builds. See [ReminderStrings].
  final ReminderStrings strings;

  /// Which daily reminders should exist right now for [medications].
  ///
  /// A course is skipped when it has not started yet, when it has already
  /// finished, or when the owner turned its reminder off. [now] is compared
  /// by date, not instant: a course ending today still reminds today.
  List<ScheduledReminder> computeReminders({
    required List<Medication> medications,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final reminders = <ScheduledReminder>[];

    for (final medication in medications) {
      if (!medication.reminderEnabled || medication.reminderTimes.isEmpty) {
        continue;
      }

      final start = _dateOnly(medication.startDate);
      if (start.isAfter(today)) continue;

      final end = medication.endDate;
      if (end != null && _dateOnly(end).isBefore(today)) {
        // The course is over. Reminding someone to take a medicine they
        // finished is worse than not reminding them at all.
        continue;
      }

      // One reminder per time of day. A twice-daily course is two
      // notifications, not one that fires at whichever time was saved last.
      for (final time in medication.reminderTimes) {
        reminders.add(
          ScheduledReminder(
            // The time is part of the id, so the two do not collide and
            // cancel each other. Deriving it from the index instead would
            // renumber every reminder when one is removed from the middle.
            notificationId: stableNotificationId(
              'medication:${medication.medicationId}:${time.wireValue}',
            ),
            recordId: medication.medicationId,
            // Only the time-of-day is used for a daily repeat, but the date
            // still has to be a real upcoming instant for the first fire.
            fireAt: _nextOccurrence(
              now: now,
              hour: time.hour,
              minute: time.minute,
            ),
            title: medication.name,
            body: _bodyFor(medication),
            repeatsDaily: true,
          ),
        );
      }
    }
    return reminders;
  }

  String _bodyFor(Medication medication) =>
      strings.medicationBodyFor(medication.dosage);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Today at [hour]:[minute] if that is still ahead, otherwise tomorrow.
  /// Scheduling an instant in the past makes the plugin fire immediately,
  /// which would ping the owner the moment they saved the medication.
  static DateTime _nextOccurrence({
    required DateTime now,
    required int hour,
    required int minute,
  }) {
    final todayAt = DateTime(now.year, now.month, now.day, hour, minute);
    return todayAt.isAfter(now)
        ? todayAt
        : todayAt.add(const Duration(days: 1));
  }
}
