import 'dart:async';
import 'dart:developer' as developer;

import '../domain/medication_reminder_scheduler.dart';
import '../domain/models/medication.dart';
import '../domain/models/prevention_program.dart';
import '../domain/models/prevention_record.dart';
import '../domain/reminder_scheduler.dart';
import '../notifications/reminder_notification_adapter.dart';
import 'medication_repository.dart';
import 'prevention_program_repository.dart';
import 'prevention_record_repository.dart';

/// Keeps the device's local reminders in step with what is actually stored.
///
/// It *subscribes* rather than exposing a "reschedule now" call for screens to
/// remember. That is deliberate: the reminders shipped unwired for weeks
/// because the scheduling code existed and nothing called it, and a design
/// where six form screens each have to remember to call something is the same
/// bug waiting to happen again. Firestore already pushes every write back
/// through these streams, so a saved medication reschedules itself.
///
/// Recomputing the whole picture on every change is affordable because it is
/// bounded by one household: a few pets, a few active courses.
class ReminderSyncService {
  // Private initializing formals, passed by their public names
  // (`medicationRepository:` and so on) at the call site -- same idiom as
  // AuthController.
  ReminderSyncService({
    required this._medicationRepository,
    required this._preventionProgramRepository,
    required this._preventionRecordRepository,
    required this._adapter,
    this._preventionScheduler = const ReminderScheduler(),
    this._medicationScheduler = const MedicationReminderScheduler(),
    this.debounce = const Duration(milliseconds: 300),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationRepository _medicationRepository;
  final PreventionProgramRepository _preventionProgramRepository;
  final PreventionRecordRepository _preventionRecordRepository;
  final ReminderNotificationAdapter _adapter;
  final ReminderScheduler _preventionScheduler;
  final MedicationReminderScheduler _medicationScheduler;
  final DateTime Function() _now;

  /// Three streams per pet all fire while the initial snapshots arrive.
  /// Without this, opening the app would cancel and rewrite the whole
  /// schedule several times in a row.
  final Duration debounce;

  final _subscriptions = <StreamSubscription<void>>[];
  final _medicationsByPet = <String, List<Medication>>{};
  final _programsByPet = <String, List<PreventionProgram>>{};
  final _recordsByPet = <String, List<PreventionRecord>>{};

  Timer? _pending;
  List<String> _petIds = const [];

  /// Begins tracking [petIds] under [uid], replacing any previous tracking.
  ///
  /// Safe to call again when the household changes; it tears the old
  /// subscriptions down first.
  Future<void> start({
    required String uid,
    required List<String> petIds,
  }) async {
    await stop();
    if (!_adapter.isSupported) return;

    _petIds = List.unmodifiable(petIds);
    for (final petId in petIds) {
      _listen(
        _medicationRepository.watchMedications(uid, petId),
        (value) => _medicationsByPet[petId] = value,
      );
      _listen(
        _preventionProgramRepository.watchPrograms(uid, petId),
        (value) => _programsByPet[petId] = value,
      );
      _listen(
        _preventionRecordRepository.watchRecords(uid, petId),
        (value) => _recordsByPet[petId] = value,
      );
    }
  }

  void _listen<T>(Stream<T> stream, void Function(T value) store) {
    _subscriptions.add(
      stream.listen(
        (value) {
          store(value);
          _scheduleRecompute();
        },
        // A stream that fails (offline, permission) must not take the app
        // down; the schedule simply keeps whatever it last applied.
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Reminder source failed',
            name: 'ReminderSyncService',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  Future<void> stop() async {
    _pending?.cancel();
    _pending = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _medicationsByPet.clear();
    _programsByPet.clear();
    _recordsByPet.clear();
    _petIds = const [];
  }

  void _scheduleRecompute() {
    _pending?.cancel();
    _pending = Timer(debounce, () {
      unawaited(_applyNow());
    });
  }

  bool _permissionRequested = false;

  Future<void> _applyNow() async {
    try {
      final reminders = computeReminders();
      if (reminders.isNotEmpty && !_permissionRequested) {
        // The first moment the owner actually has something to be reminded
        // about -- which is the only moment a notification prompt makes
        // sense. Asking at app start, before they have entered a single
        // medication, is how you collect a denial you cannot undo.
        _permissionRequested = true;
        await _adapter.requestPermissions();
      }
      await _adapter.applySchedule(reminders);
    } catch (error, stackTrace) {
      // Rescheduling failing must never surface as the save failing.
      developer.log(
        'Could not refresh reminders',
        name: 'ReminderSyncService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The pure half: which reminders should exist given what has been seen so
  /// far. Public so it can be tested without a platform channel.
  List<ScheduledReminder> computeReminders() {
    final now = _now();
    final reminders = <ScheduledReminder>[];

    for (final petId in _petIds) {
      reminders.addAll(
        _medicationScheduler.computeReminders(
          medications: _medicationsByPet[petId] ?? const [],
          now: now,
        ),
      );
      reminders.addAll(
        _preventionScheduler.computeReminders(
          records: _preventionCandidates(petId),
          now: now,
        ),
      );
    }
    return reminders;
  }

  List<ReminderCandidate> _preventionCandidates(String petId) {
    final programsById = {
      for (final program
          in _programsByPet[petId] ?? const <PreventionProgram>[])
        program.programId: program,
    };

    // Only the newest record of each program carries a live next_due_date;
    // older ones describe doses already given, and scheduling from those
    // would resurrect reminders for dates already superseded. watchRecords
    // returns newest first.
    final seen = <String>{};
    final candidates = <ReminderCandidate>[];
    for (final record in _recordsByPet[petId] ?? const <PreventionRecord>[]) {
      if (!seen.add(record.programId)) continue;
      final program = programsById[record.programId];
      // A program the owner switched off should stop reminding them.
      if (program == null || !program.active) continue;
      candidates.add(
        ReminderCandidate(
          recordId: '$petId:${record.programId}',
          type: program.type,
          productName: program.productName,
          nextDueDate: record.nextDueDate,
          reminderEnabled: record.reminderEnabled,
          reminderTime: record.reminderTime,
        ),
      );
    }
    return candidates;
  }

  /// Whether anything is currently scheduled. Used to decide when to ask for
  /// notification permission: asking at app start, before the owner has said
  /// they want to be reminded of anything, is how you earn a denial you
  /// cannot take back.
  bool get hasReminders => computeReminders().isNotEmpty;
}
