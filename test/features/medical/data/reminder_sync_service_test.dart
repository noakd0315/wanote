import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanote/features/medical/data/medication_repository.dart';
import 'package:wanote/features/medical/data/prevention_program_repository.dart';
import 'package:wanote/features/medical/data/prevention_record_repository.dart';
import 'package:wanote/features/medical/data/reminder_sync_service.dart';
import 'package:wanote/features/medical/domain/models/medication.dart';
import 'package:wanote/features/medical/domain/models/prevention_program.dart';
import 'package:wanote/features/medical/domain/models/prevention_record.dart';
import 'package:wanote/features/medical/domain/reminder_scheduler.dart';
import 'package:wanote/features/medical/notifications/reminder_notification_adapter.dart';

class MockMedicationRepository extends Mock implements MedicationRepository {}

class MockPreventionProgramRepository extends Mock
    implements PreventionProgramRepository {}

class MockPreventionRecordRepository extends Mock
    implements PreventionRecordRepository {}

class MockAdapter extends Mock implements ReminderNotificationAdapter {}

/// The one place that decides which reminders should exist.
///
/// Every write goes through here rather than each form screen scheduling its
/// own notification, so this is where a reminder gets left behind if anything
/// is wrong -- and a leftover reminder is worse than a missing one: it tells
/// someone to medicate a dog on a course that ended.
void main() {
  const uid = 'owner-uid';
  const petId = 'pet-1';
  final now = DateTime(2026, 8, 12, 10);

  late MockMedicationRepository medications;
  late MockPreventionProgramRepository programs;
  late MockPreventionRecordRepository records;
  late MockAdapter adapter;

  void seed({
    List<Medication> meds = const [],
    List<PreventionProgram> programList = const [],
    List<PreventionRecord> recordList = const [],
    String pet = petId,
  }) {
    when(
      () => medications.watchMedications(uid, pet),
    ).thenAnswer((_) => Stream.value(meds));
    when(
      () => programs.watchPrograms(uid, pet),
    ).thenAnswer((_) => Stream.value(programList));
    when(
      () => records.watchRecords(uid, pet),
    ).thenAnswer((_) => Stream.value(recordList));
  }

  ReminderSyncService buildService() => ReminderSyncService(
    medicationRepository: medications,
    preventionProgramRepository: programs,
    preventionRecordRepository: records,
    adapter: adapter,
    now: () => now,
    // Long enough to prove coalescing happens, short enough not to slow the
    // suite down.
    debounce: const Duration(milliseconds: 20),
  );

  /// Starts tracking and waits past the debounce, so the assertions below see
  /// the settled schedule rather than one of the intermediate ones.
  Future<List<ScheduledReminder>> scheduleFor(List<String> petIds) async {
    final service = buildService();
    addTearDown(service.stop);
    await service.start(uid: uid, petIds: petIds);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return service.computeReminders();
  }

  setUp(() {
    medications = MockMedicationRepository();
    programs = MockPreventionProgramRepository();
    records = MockPreventionRecordRepository();
    adapter = MockAdapter();

    when(() => adapter.isSupported).thenReturn(true);
    when(() => adapter.applySchedule(any())).thenAnswer((_) async {});
    when(adapter.requestPermissions).thenAnswer((_) async => true);
    seed();
  });

  Medication med({
    String id = 'med-1',
    bool reminderEnabled = true,
    DateTime? endDate,
  }) => Medication(
    medicationId: id,
    petId: petId,
    name: 'アポキル',
    startDate: DateTime(2026, 8, 1),
    endDate: endDate,
    reminderEnabled: reminderEnabled,
    reminderTimes: reminderEnabled ? const [ReminderTime(8, 0)] : const [],
  );

  PreventionProgram program({
    String id = 'prog-1',
    bool active = true,
    PreventionType type = PreventionType.vaccine,
  }) => PreventionProgram(
    programId: id,
    petId: petId,
    type: type,
    productName: '狂犬病ワクチン',
    scheduleType: ScheduleType.annual,
    startDate: DateTime(2026, 1, 1),
    active: active,
  );

  PreventionRecord record({
    String id = 'rec-1',
    String programId = 'prog-1',
    required DateTime administeredAt,
    DateTime? nextDueDate,
  }) => PreventionRecord(
    recordId: id,
    programId: programId,
    petId: petId,
    administeredAt: administeredAt,
    nextDueDate: nextDueDate,
  );

  test('schedules medication and prevention reminders together', () async {
    seed(
      meds: [med()],
      programList: [program()],
      recordList: [
        record(
          administeredAt: DateTime(2026, 8, 1),
          nextDueDate: DateTime(2026, 9, 1),
        ),
      ],
    );

    final reminders = await scheduleFor(const [petId]);

    expect(reminders, hasLength(2));
    expect(reminders.where((r) => r.repeatsDaily), hasLength(1));
  });

  test('ignores a prevention program the owner switched off', () async {
    seed(
      programList: [program(active: false)],
      recordList: [
        record(
          administeredAt: DateTime(2026, 8, 1),
          nextDueDate: DateTime(2026, 9, 1),
        ),
      ],
    );

    expect(await scheduleFor(const [petId]), isEmpty);
  });

  test('uses only the newest record of a program', () async {
    // watchRecords returns newest-first. An older dose carries an old
    // next_due_date; scheduling from it would resurrect a reminder for a
    // date that has already been superseded.
    seed(
      programList: [program()],
      recordList: [
        record(
          id: 'new',
          administeredAt: DateTime(2026, 8, 1),
          nextDueDate: DateTime(2026, 9, 1),
        ),
        record(
          id: 'old',
          administeredAt: DateTime(2025, 8, 1),
          nextDueDate: DateTime(2025, 9, 1),
        ),
      ],
    );

    final reminders = await scheduleFor(const [petId]);

    expect(reminders, hasLength(1));
    // 7 days before 2026-09-01 at 09:00.
    expect(reminders.single.fireAt, DateTime(2026, 8, 25, 9));
  });

  test('covers every pet in the household, not just the active one', () async {
    seed(meds: [med()]);
    seed(
      meds: [med(id: 'med-2')],
      pet: 'pet-2',
    );

    final reminders = await scheduleFor(const [petId, 'pet-2']);

    expect(reminders.map((r) => r.recordId), ['med-1', 'med-2']);
  });

  test('a record with no due date schedules nothing', () async {
    seed(
      programList: [program()],
      recordList: [record(administeredAt: DateTime(2026, 8, 1))],
    );

    expect(await scheduleFor(const [petId]), isEmpty);
  });

  test('reschedules by itself when a medication is written', () async {
    // The point of subscribing rather than exposing a "reschedule" call:
    // nothing in the medication form has to remember to do this, which is
    // exactly what went wrong the first time.
    final controller = StreamController<List<Medication>>();
    addTearDown(controller.close);
    when(
      () => medications.watchMedications(uid, petId),
    ).thenAnswer((_) => controller.stream);

    final service = buildService();
    addTearDown(service.stop);
    await service.start(uid: uid, petIds: const [petId]);
    controller.add([med()]);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final applied = verify(
      () => adapter.applySchedule(captureAny()),
    ).captured.last;
    expect(applied, hasLength(1));
  });

  test('coalesces the opening burst into one reschedule', () async {
    // Three streams per pet all deliver their first snapshot at once.
    // Without debouncing, opening the app would cancel and rewrite the whole
    // schedule three times over.
    seed(
      meds: [med()],
      programList: [program()],
      recordList: [
        record(
          administeredAt: DateTime(2026, 8, 1),
          nextDueDate: DateTime(2026, 9, 1),
        ),
      ],
    );

    await scheduleFor(const [petId]);

    verify(() => adapter.applySchedule(any())).called(1);
  });

  test('stops tracking the previous household when restarted', () async {
    seed(meds: [med()]);
    seed(
      meds: [med(id: 'med-2')],
      pet: 'pet-2',
    );

    final service = buildService();
    addTearDown(service.stop);
    await service.start(uid: uid, petIds: const [petId]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await service.start(uid: uid, petIds: const ['pet-2']);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(service.computeReminders().map((r) => r.recordId), ['med-2']);
  });

  test('a failing source does not bring anything down', () async {
    // Offline, or a rules change. The schedule keeps whatever it last
    // applied rather than the app crashing on a stream error.
    when(
      () => medications.watchMedications(uid, petId),
    ).thenAnswer((_) => Stream.error(Exception('firestore is down')));

    await expectLater(scheduleFor(const [petId]), completes);
  });

  test(
    'asks for notification permission only once there is a reminder',
    () async {
      // Prompting at app start, before the owner has entered a single
      // medication, is how you collect a denial that cannot be undone.
      seed();
      await scheduleFor(const [petId]);
      verifyNever(adapter.requestPermissions);

      seed(meds: [med()]);
      await scheduleFor(const [petId]);
      verify(adapter.requestPermissions).called(1);
    },
  );

  test('does not re-ask on every later change', () async {
    final controller = StreamController<List<Medication>>();
    addTearDown(controller.close);
    when(
      () => medications.watchMedications(uid, petId),
    ).thenAnswer((_) => controller.stream);

    final service = buildService();
    addTearDown(service.stop);
    await service.start(uid: uid, petIds: const [petId]);
    controller.add([med()]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    controller.add([med(), med(id: 'med-2')]);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    verify(adapter.requestPermissions).called(1);
  });

  test('does nothing at all on a platform without notifications', () async {
    // Web, where the plugin has no implementation. The app runs there all
    // through development.
    when(() => adapter.isSupported).thenReturn(false);
    seed(meds: [med()]);

    await scheduleFor(const [petId]);

    verifyNever(() => adapter.applySchedule(any()));
  });
}
