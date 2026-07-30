import 'package:equatable/equatable.dart';

import 'models/prevention_program.dart';

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
  });

  final String recordId;
  final PreventionType type;
  final String productName;

  /// `prevention_records.next_due_date`. `null` means no reminder can be
  /// computed (e.g. a `single`-schedule vaccine whose next date wasn't
  /// entered) — the no-due-date edge case.
  final DateTime? nextDueDate;

  @override
  List<Object?> get props => [recordId, type, productName, nextDueDate];
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
  });

  final int notificationId;
  final String recordId;
  final DateTime fireAt;
  final String title;
  final String body;

  @override
  List<Object?> get props => [notificationId, recordId, fireAt, title, body];
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
  });

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
      final nextDueDate = record.nextDueDate;
      if (nextDueDate == null) {
        // No-due-date edge case: nothing to schedule.
        continue;
      }

      final leadDays = record.type == PreventionType.vaccine
          ? vaccineLeadDays
          : recurringLeadDays;

      final dueAt = DateTime(
        nextDueDate.year,
        nextDueDate.month,
        nextDueDate.day,
        reminderHourOfDay,
      );
      if (!dueAt.isAfter(now)) {
        // Already due or overdue: this scheduler only handles upcoming
        // "heads up" reminders, not overdue nagging.
        continue;
      }

      var fireAt = dueAt.subtract(Duration(days: leadDays));
      if (fireAt.isBefore(now)) {
        // We're already inside the lead window (e.g. app wasn't opened for
        // a while) — fire the catch-up reminder right away instead of
        // silently dropping it.
        fireAt = now;
      }

      reminders.add(
        ScheduledReminder(
          notificationId: _stableNotificationId(record.recordId),
          recordId: record.recordId,
          fireAt: fireAt,
          title: _titleFor(record),
          body: _bodyFor(record, leadDays),
        ),
      );
    }
    return reminders;
  }

  String _titleFor(ReminderCandidate record) {
    return '${record.productName}の予防リマインダー';
  }

  String _bodyFor(ReminderCandidate record, int leadDays) {
    switch (record.type) {
      case PreventionType.vaccine:
        return '次回接種予定日が近づいています（あと$leadDays日以内）。動物病院の予約をご検討ください。';
      case PreventionType.heartworm:
      case PreventionType.fleaTick:
        return 'そろそろ次回投与の時期です。忘れずに投与しましょう。';
    }
  }

  /// FNV-1a 32-bit hash of [recordId], masked to a positive 31-bit int so it
  /// always fits flutter_local_notifications' platform notification id
  /// range and is stable across recomputations.
  static int _stableNotificationId(String recordId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in recordId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
