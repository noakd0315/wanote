import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/medical/domain/models/prevention_program.dart';
import 'package:wanote/features/medical/domain/reminder_scheduler.dart';

void main() {
  const scheduler = ReminderScheduler(
    vaccineLeadDays: 7,
    recurringLeadDays: 3,
    reminderHourOfDay: 9,
  );

  group('ReminderScheduler', () {
    test('no-due-date records produce no reminder', () {
      final now = DateTime(2026, 1, 1);
      final result = scheduler.computeReminders(
        records: [
          const ReminderCandidate(
            recordId: 'r1',
            type: PreventionType.vaccine,
            productName: '混合ワクチン',
            nextDueDate: null,
          ),
        ],
        now: now,
      );

      expect(result, isEmpty);
    });

    test('vaccine reminder fires vaccineLeadDays before next_due_date', () {
      final now = DateTime(2026, 1, 1);
      final nextDueDate = DateTime(2026, 1, 20);

      final result = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'vaccine-1',
            type: PreventionType.vaccine,
            productName: '狂犬病ワクチン',
            nextDueDate: nextDueDate,
          ),
        ],
        now: now,
      );

      expect(result, hasLength(1));
      expect(result.first.fireAt, DateTime(2026, 1, 13, 9));
      expect(result.first.recordId, 'vaccine-1');
    });

    test('medication reminder uses the shorter recurring lead time', () {
      final now = DateTime(2026, 1, 1);
      final nextDueDate = DateTime(2026, 1, 20);

      final heartwormResult = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'heartworm-1',
            type: PreventionType.medication,
            productName: 'フィラリア予防薬',
            nextDueDate: nextDueDate,
          ),
        ],
        now: now,
      );
      final fleaTickResult = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'flea-1',
            type: PreventionType.medication,
            productName: 'ノミ・ダニ予防薬',
            nextDueDate: nextDueDate,
          ),
        ],
        now: now,
      );

      expect(heartwormResult.single.fireAt, DateTime(2026, 1, 17, 9));
      expect(fleaTickResult.single.fireAt, DateTime(2026, 1, 17, 9));
    });

    test('already-overdue next_due_date produces no upcoming reminder', () {
      final now = DateTime(2026, 2, 1);
      final nextDueDate = DateTime(2026, 1, 20); // in the past

      final result = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'overdue-1',
            type: PreventionType.vaccine,
            productName: '混合ワクチン',
            nextDueDate: nextDueDate,
          ),
        ],
        now: now,
      );

      expect(result, isEmpty);
    });

    test(
      'a due date already inside the lead window fires immediately (catch-up)',
      () {
        // now is only 2 days before the due date, but the vaccine lead time
        // is 7 days -- we're already "late" to notify, so it should fire
        // right away instead of being silently dropped.
        final now = DateTime(2026, 1, 18);
        final nextDueDate = DateTime(2026, 1, 20);

        final result = scheduler.computeReminders(
          records: [
            ReminderCandidate(
              recordId: 'catchup-1',
              type: PreventionType.vaccine,
              productName: '混合ワクチン',
              nextDueDate: nextDueDate,
            ),
          ],
          now: now,
        );

        expect(result.single.fireAt, now);
      },
    );

    test('notification id is deterministic for the same recordId', () {
      final now = DateTime(2026, 1, 1);
      final nextDueDate = DateTime(2026, 1, 20);
      final candidate = ReminderCandidate(
        recordId: 'stable-id',
        type: PreventionType.vaccine,
        productName: '混合ワクチン',
        nextDueDate: nextDueDate,
      );

      final first = scheduler.computeReminders(records: [candidate], now: now);
      final second = scheduler.computeReminders(records: [candidate], now: now);

      expect(first.single.notificationId, second.single.notificationId);
    });

    test('multiple records each produce their own reminder', () {
      final now = DateTime(2026, 1, 1);
      final result = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'a',
            type: PreventionType.vaccine,
            productName: 'A',
            nextDueDate: DateTime(2026, 2, 1),
          ),
          ReminderCandidate(
            recordId: 'b',
            type: PreventionType.medication,
            productName: 'B',
            nextDueDate: DateTime(2026, 2, 5),
          ),
          const ReminderCandidate(
            recordId: 'c',
            type: PreventionType.medication,
            productName: 'C',
            nextDueDate: null,
          ),
        ],
        now: now,
      );

      expect(result.map((r) => r.recordId), containsAll(['a', 'b']));
      expect(result, hasLength(2));
    });
  });

  // PM request (2026-08-18): the fixed lead time did not fit every
  // treatment. A monthly heartworm tablet the owner already has is better
  // remembered on the day than three days early.
  group('owner-chosen lead times', () {
    test('one notification per chosen lead time', () {
      final reminders = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'heartworm',
            type: PreventionType.medication,
            productName: 'フィラリア薬',
            nextDueDate: DateTime(2026, 9, 1),
            leadDays: const [0, 3],
          ),
        ],
        now: DateTime(2026, 8, 1),
      );
      expect(reminders, hasLength(2));
      expect(
        reminders.map((r) => r.fireAt).toSet(),
        {DateTime(2026, 9, 1, 9), DateTime(2026, 8, 29, 9)},
      );
    });

    test('each lead time gets its own notification id', () {
      final reminders = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'heartworm',
            type: PreventionType.medication,
            productName: 'フィラリア薬',
            nextDueDate: DateTime(2026, 9, 1),
            leadDays: const [0, 3, 7],
          ),
        ],
        now: DateTime(2026, 8, 1),
      );
      // Sharing an id would mean each reschedule overwrote the last, and
      // only one of the three would ever arrive.
      expect(reminders.map((r) => r.notificationId).toSet(), hasLength(3));
    });

    test('a same-day reminder fires on the due date itself', () {
      final reminders = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'heartworm',
            type: PreventionType.medication,
            productName: 'フィラリア薬',
            nextDueDate: DateTime(2026, 9, 1),
            leadDays: const [0],
          ),
        ],
        now: DateTime(2026, 8, 1),
      );
      expect(reminders.single.fireAt, DateTime(2026, 9, 1, 9));
    });

    test('no chosen lead time falls back to the type default', () {
      final reminders = scheduler.computeReminders(
        records: [
          ReminderCandidate(
            recordId: 'rabies',
            type: PreventionType.vaccine,
            productName: '狂犬病ワクチン',
            nextDueDate: DateTime(2026, 9, 1),
          ),
        ],
        now: DateTime(2026, 8, 1),
      );
      // 7 days for a vaccine, unchanged from before this was configurable.
      expect(reminders.single.fireAt, DateTime(2026, 8, 25, 9));
    });
  });
}
