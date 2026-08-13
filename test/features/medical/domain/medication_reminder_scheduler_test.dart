import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/domain/medication_reminder_scheduler.dart';
import 'package:wanote/features/medical/domain/models/medication.dart';

/// Daily dose reminders (spec 5.2).
///
/// The medication form has been storing `reminder_enabled` and
/// `reminder_time` since it was built, and nothing ever read them -- these
/// reminders had never fired once. So this is the first thing that decides
/// when someone gets told to give their dog its medicine, and the cases that
/// matter are the ones where it should stay quiet.
void main() {
  const scheduler = MedicationReminderScheduler();
  final now = DateTime(2026, 8, 12, 10, 30);

  Medication medication({
    String id = 'med-1',
    String name = 'アポキル',
    String? dosage,
    DateTime? startDate,
    DateTime? endDate,
    bool reminderEnabled = true,
    int? hour = 8,
    int? minute = 0,
  }) => Medication(
    medicationId: id,
    petId: 'pet-1',
    name: name,
    dosage: dosage,
    startDate: startDate ?? DateTime(2026, 8, 1),
    endDate: endDate,
    reminderEnabled: reminderEnabled,
    reminderHour: reminderEnabled ? hour : null,
    reminderMinute: reminderEnabled ? minute : null,
  );

  List<String> idsFor(List<Medication> medications) => scheduler
      .computeReminders(medications: medications, now: now)
      .map((r) => r.recordId)
      .toList();

  test('schedules a daily reminder for an ongoing course', () {
    final reminders = scheduler.computeReminders(
      medications: [medication()],
      now: now,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.repeatsDaily, isTrue);
    expect(reminders.single.recordId, 'med-1');
  });

  test('stays quiet when the owner did not ask to be reminded', () {
    expect(idsFor([medication(reminderEnabled: false)]), isEmpty);
  });

  test('stops once the course has finished', () {
    // The one that would actively mislead: telling someone to give a dose of
    // a medicine the vet took them off.
    expect(idsFor([medication(endDate: DateTime(2026, 8, 11))]), isEmpty);
  });

  test('still reminds on the final day of a course', () {
    // endDate is inclusive -- the last dose is on that day, so silence would
    // mean skipping it.
    expect(idsFor([medication(endDate: DateTime(2026, 8, 12))]), ['med-1']);
  });

  test('says nothing before the course starts', () {
    expect(idsFor([medication(startDate: DateTime(2026, 8, 20))]), isEmpty);
  });

  test('reminds from the first day of a course starting today', () {
    expect(idsFor([medication(startDate: DateTime(2026, 8, 12))]), ['med-1']);
  });

  test('first fires today when the time has not passed yet', () {
    final reminders = scheduler.computeReminders(
      medications: [medication(hour: 18, minute: 30)],
      now: now,
    );

    expect(reminders.single.fireAt, DateTime(2026, 8, 12, 18, 30));
  });

  test('first fires tomorrow when today already passed', () {
    // Scheduling an instant in the past makes the plugin fire immediately,
    // which would ping the owner the moment they saved the medication.
    final reminders = scheduler.computeReminders(
      medications: [medication(hour: 8, minute: 0)],
      now: now,
    );

    expect(reminders.single.fireAt, DateTime(2026, 8, 13, 8, 0));
  });

  test('puts the dosage in the body when there is one', () {
    final withDosage = scheduler
        .computeReminders(
          medications: [medication(dosage: '1錠')],
          now: now,
        )
        .single;
    final withoutDosage = scheduler
        .computeReminders(medications: [medication()], now: now)
        .single;

    expect(withDosage.body, contains('1錠'));
    expect(withoutDosage.body, isNot(contains('（')));
  });

  test('gives each medication its own notification id', () {
    final reminders = scheduler.computeReminders(
      medications: [
        medication(id: 'a'),
        medication(id: 'b'),
      ],
      now: now,
    );

    expect(reminders.map((r) => r.notificationId).toSet(), hasLength(2));
  });

  test('derives the same id every time, so rescheduling overwrites', () {
    final first = scheduler
        .computeReminders(medications: [medication()], now: now)
        .single;
    final second = scheduler
        .computeReminders(
          medications: [medication()],
          now: now.add(const Duration(days: 3)),
        )
        .single;

    expect(first.notificationId, second.notificationId);
  });
}
