import 'package:equatable/equatable.dart';

import 'models/medication.dart' show ReminderTime;
import 'models/prevention_program.dart';
import 'reminder_strings.dart';

/// Minimal input the scheduler needs about one prevention record + its
/// parent program. Deliberately not the full [PreventionRecord]/
/// [PreventionProgram] models so this stays a small, obvious pure-function
/// input (callers just project the fields they have).
class ReminderCandidate extends Equatable {
  const ReminderCandidate({
    required this.recordId,
    required this.type,
    required this.productName,
    required this.nextDueDate,
    this.reminderEnabled = true,
    this.reminderTime,
    this.leadDays = const [],
  });

  final String recordId;
  final PreventionType type;
  final String productName;

  /// The owner's switch. Off means no notification for this one, however
  /// close the due date is.
  final bool reminderEnabled;

  /// The hour the owner chose, or null to use [reminderHourOfDay].
  ///
  /// PM: a reminder arriving just after midnight is no use, so the time is
  /// not left to a constant.
  final ReminderTime? reminderTime;

  /// How many days before [nextDueDate] to remind, one notification each.
  /// Empty falls back to the type's default lead time.
  ///
  /// PM (2026-08-18): a monthly heartworm tablet is better remembered on
  /// the day than three days early, and some owners want both.
  final List<int> leadDays;

  /// `prevention_records.next_due_date`. `null` means no reminder can be
  /// computed (e.g. a `single`-schedule vaccine whose next date wasn't
  /// entered) — the no-due-date edge case.
  final DateTime? nextDueDate;

  @override
  List<Object?> get props => [
    recordId,
    type,
    productName,
    nextDueDate,
    leadDays,
  ];
}

/// One notification the caller should (re)schedule with
/// flutter_local_notifications. [notificationId] is derived deterministically
/// from [recordId] so recomputing the schedule twice for the same record
/// yields the same id (making reschedule = cancel + re-add idempotent).
class ScheduledReminder extends Equatable {
  const ScheduledReminder({
    required this.notificationId,
    required this.recordId,
    required this.fireAt,
    required this.title,
    required this.body,
    this.repeatsDaily = false,
  });

  final int notificationId;
  final String recordId;
  final DateTime fireAt;
  final String title;
  final String body;

  /// True for medication doses (spec 5.2), which repeat at the same time
  /// every day for the length of the course. Prevention reminders are
  /// one-off, so they leave this false.
  ///
  /// A daily repeat has no end date at the platform level -- see
  /// [MedicationReminderScheduler] and ReminderSyncService for how a
  /// finished course stops reminding.
  final bool repeatsDaily;

  @override
  List<Object?> get props => [
    notificationId,
    recordId,
    fireAt,
    title,
    body,
    repeatsDaily,
  ];
}

/// Pure computation of "which local notifications should exist right now"
/// from prevention records + "now" (spec 5.3's reminder section). No
/// flutter_local_notifications/timezone dependency here — see
/// `ReminderNotificationAdapter` in lib/features/medical/notifications for
/// the thin adapter that actually calls the plugin with this output.
///
/// Spec 5.3 describes two notification patterns, both anchored on
/// `next_due_date` (which is itself either auto-calculated by
/// [PreventionDueDateCalculator] for monthly/annual/custom programs, or
/// manually entered for `single` schedules):
///   - vaccine: notify [vaccineLeadDays] days *before* the registered
///     next_due_date (a rarer, appointment-needing event -> more advance
///     notice).
///   - heartworm/flea_tick: notify as the date "approaches", i.e. a shorter
///     lead window ([recurringLeadDays]) before next_due_date, since these
///     are routine monthly doses the owner just needs a nearer-term nudge
///     for.
///
/// We deliberately did not duplicate `administered_at + interval_days` math
/// here: `next_due_date` on the record is already that computation's output
/// (done once, at save time, by [PreventionDueDateCalculator]), so the
/// scheduler only needs to decide *how much lead time* to give depending on
/// category. This keeps the "what is the due date" logic in exactly one
/// place.
class ReminderScheduler {
  const ReminderScheduler({
    this.vaccineLeadDays = defaultVaccineLeadDays,
    this.recurringLeadDays = defaultRecurringLeadDays,
    this.reminderHourOfDay = defaultReminderHourOfDay,
    this.strings = ReminderStrings.fallback,
  });

  /// The wording for the notifications this builds. See [ReminderStrings].
  final ReminderStrings strings;

  /// Named constant per task instructions ("make N a named constant e.g.
  /// 7"): vaccines are infrequent/appointment-based, so give a full week's
  /// notice.
  static const int defaultVaccineLeadDays = 7;

  /// Heartworm/flea-tick prevention is a routine monthly dose; a shorter
  /// "it's getting close" window is enough and avoids notification fatigue
  /// from a 7-day-early ping every single month.
  static const int defaultRecurringLeadDays = 3;

  /// Local notifications fire at 9:00 on the computed day, a reasonable
  /// default "owner is awake and can act on it" time.
  static const int defaultReminderHourOfDay = 9;

  final int vaccineLeadDays;
  final int recurringLeadDays;
  final int reminderHourOfDay;

  List<ScheduledReminder> computeReminders({
    required List<ReminderCandidate> records,
    required DateTime now,
  }) {
    final reminders = <ScheduledReminder>[];
    for (final record in records) {
      if (!record.reminderEnabled) continue;
      final nextDueDate = record.nextDueDate;
      if (nextDueDate == null) {
        // No-due-date edge case: nothing to schedule.
        continue;
      }

      final leadDaysForRecord = record.leadDays.isNotEmpty
          ? record.leadDays
          : [defaultLeadDaysFor(record.type)];

      final dueAt = DateTime(
        nextDueDate.year,
        nextDueDate.month,
        nextDueDate.day,
        record.reminderTime?.hour ?? reminderHourOfDay,
        record.reminderTime?.minute ?? 0,
      );
      if (!dueAt.isAfter(now)) {
        // Already due or overdue: this scheduler only handles upcoming
        // "heads up" reminders, not overdue nagging.
        continue;
      }

      // One notification per chosen lead time. The ids are namespaced by
      // lead time as well as record, or the second would overwrite the
      // first and only the last one asked for would ever arrive.
      for (final leadDays in leadDaysForRecord) {
        var fireAt = dueAt.subtract(Duration(days: leadDays));
        if (fireAt.isBefore(now)) {
          // We're already inside the lead window (e.g. app wasn't opened
          // for a while) — fire the catch-up reminder right away instead of
          // silently dropping it. With several lead times this can collapse
          // two of them onto now; they share a moment, not an id, so the
          // later one still lands.
          fireAt = now;
        }

        reminders.add(
          ScheduledReminder(
            notificationId: stableNotificationId(
              '${record.recordId}#lead$leadDays',
            ),
            recordId: record.recordId,
            fireAt: fireAt,
            title: _titleFor(record),
            body: _bodyFor(record, leadDays),
          ),
        );
      }
    }
    return reminders;
  }

  /// The lead time used when a record names none of its own.
  ///
  /// Vaccines are infrequent and need an appointment, so a week. Routine
  /// monthly doses get a nearer nudge.
  int defaultLeadDaysFor(PreventionType type) =>
      type == PreventionType.vaccine ? vaccineLeadDays : recurringLeadDays;

  String _titleFor(ReminderCandidate record) =>
      strings.preventionTitleFor(record.productName);

  String _bodyFor(ReminderCandidate record, int leadDays) {
    // "Due within 0 days" is not a sentence. A reminder set for the due
    // date says so instead.
    if (leadDays == 0) return strings.preventionDueTodayBody;
    switch (record.type) {
      case PreventionType.vaccine:
        return strings.preventionVaccineBodyFor(leadDays);
      case PreventionType.medication:
        return strings.preventionMedicationBody;
    }
  }

}

/// FNV-1a 32-bit hash of [key], masked to a positive 31-bit int so it always
/// fits flutter_local_notifications' platform notification id range and is
/// stable across recomputations (making reschedule = cancel + re-add
/// idempotent).
///
/// Shared with [MedicationReminderScheduler], which namespaces its keys
/// (`medication:{id}`) so a medication and a prevention record can never
/// derive the same id and silently overwrite each other's notification.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final codeUnit in key.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
