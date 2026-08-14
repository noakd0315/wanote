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
    int hour = 8,
    int minute = 0,
  }) => Medication(
    medicationId: id,
    petId: 'pet-1',
    name: name,
    dosage: dosage,
    startDate: startDate ?? DateTime(2026, 8, 1),
    endDate: endDate,
    reminderEnabled: reminderEnabled,
    reminderTimes: reminderEnabled ? [ReminderTime(hour, minute)] : const [],
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

  _multipleTimesTests();
}

/// Several doses a day.
///
/// PM request: a course is often morning and evening, or one with each meal.
/// A single time could only ever describe a once-daily medicine.
void _multipleTimesTests() {
  const scheduler = MedicationReminderScheduler();
  final now = DateTime(2026, 8, 12, 10, 30);

  Medication twiceDaily() => Medication(
    medicationId: 'med-1',
    petId: 'pet-1',
    name: 'アポキル',
    startDate: DateTime(2026, 8, 1),
    reminderEnabled: true,
    reminderTimes: const [ReminderTime(8, 0), ReminderTime(20, 0)],
  );

  test('one reminder per time of day', () {
    final reminders = scheduler.computeReminders(
      medications: [twiceDaily()],
      now: now,
    );

    expect(reminders, hasLength(2));
    expect(
      reminders.map((r) => '${r.fireAt.hour}:${r.fireAt.minute}'),
      containsAll(<String>['8:0', '20:0']),
    );
  });

  test('the two do not share a notification id', () {
    // They would cancel each other if they did: scheduling the second over
    // the first leaves one reminder for a medicine due twice.
    final ids = scheduler
        .computeReminders(medications: [twiceDaily()], now: now)
        .map((r) => r.notificationId)
        .toSet();

    expect(ids, hasLength(2));
  });

  test('a record saved before this change keeps its reminder', () {
    // Older documents hold reminder_hour/reminder_minute and no list.
    // Losing their reminder on upgrade would be silent: nothing on screen
    // says a notification stopped being scheduled.
    final medication = Medication.fromMap({
      'medication_id': 'med-1',
      'pet_id': 'pet-1',
      'name': 'アポキル',
      'start_date': DateTime(2026, 8, 1).toIso8601String(),
      'reminder_enabled': true,
      'reminder_hour': 21,
      'reminder_minute': 30,
    });

    expect(medication.reminderTimes, [const ReminderTime(21, 30)]);
    expect(
      scheduler.computeReminders(medications: [medication], now: now),
      hasLength(1),
    );
  });

  test('times are kept in order however they were added', () {
    final medication = Medication.fromMap({
      'medication_id': 'med-1',
      'pet_id': 'pet-1',
      'name': 'アポキル',
      'start_date': DateTime(2026, 8, 1).toIso8601String(),
      'reminder_enabled': true,
      'reminder_times': ['20:00', '08:00', '12:30'],
    });

    expect(medication.reminderTimes, const [
      ReminderTime(8, 0),
      ReminderTime(12, 30),
      ReminderTime(20, 0),
    ]);
  });
}
