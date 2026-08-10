import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:wanote/features/medical/domain/reminder_scheduler.dart';
import 'package:wanote/features/medical/notifications/reminder_notification_adapter.dart';

/// Pins the flutter_local_notifications 22.x call shape. That upgrade turned
/// every positional argument into a named one and removed
/// uiLocalNotificationDateInterpretation, so a mis-migration would compile
/// happily against the old positional order only to schedule the wrong
/// notification (or none) at runtime -- vaccination reminders silently not
/// firing is exactly the failure a user would never report as a bug.
class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeTZDateTime extends Fake implements tz.TZDateTime {}

class _FakeNotificationDetails extends Fake implements NotificationDetails {}

class _FakeInitializationSettings extends Fake
    implements InitializationSettings {}

ScheduledReminder _reminder({
  required int id,
  required DateTime fireAt,
  String title = 'ワクチン',
  String body = '接種の予定です',
}) => ScheduledReminder(
  notificationId: id,
  recordId: 'rec-$id',
  fireAt: fireAt,
  title: title,
  body: body,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeTZDateTime());
    registerFallbackValue(_FakeNotificationDetails());
    registerFallbackValue(_FakeInitializationSettings());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  });

  late _MockPlugin plugin;
  late ReminderNotificationAdapter adapter;

  setUp(() {
    plugin = _MockPlugin();
    adapter = ReminderNotificationAdapter(plugin: plugin);

    when(
      () => plugin.initialize(settings: any(named: 'settings')),
    ).thenAnswer((_) async => true);
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).thenAnswer((_) async {});
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
  });

  test('schedules each reminder with its own id, title and body', () async {
    await adapter.applySchedule([
      _reminder(id: 11, fireAt: DateTime(2026, 9, 1, 9), title: '狂犬病'),
      _reminder(id: 22, fireAt: DateTime(2026, 10, 1, 9), title: '混合'),
    ]);

    final captured = verify(
      () => plugin.zonedSchedule(
        id: captureAny(named: 'id'),
        title: captureAny(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: captureAny(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: captureAny(named: 'androidScheduleMode'),
      ),
    ).captured;

    // mocktail captures named arguments in the order the METHOD declares
    // them (id, scheduledDate, androidScheduleMode, title), not the order
    // they appear in this verify() call.
    expect(captured, hasLength(8));
    expect(captured[0], 11);
    expect(captured[3], '狂犬病');
    expect(captured[4], 22);
    expect(captured[7], '混合');
    // Reminders must be exact: an inexact alarm can slip by hours, which for
    // a "接種予定日です" notification means the wrong day.
    expect(captured[2], AndroidScheduleMode.exactAllowWhileIdle);
  });

  test('converts the fire time into the local timezone', () async {
    await adapter.applySchedule([
      _reminder(id: 1, fireAt: DateTime(2026, 9, 1, 9)),
    ]);

    final scheduled =
        verify(
              () => plugin.zonedSchedule(
                id: any(named: 'id'),
                title: any(named: 'title'),
                body: any(named: 'body'),
                scheduledDate: captureAny(named: 'scheduledDate'),
                notificationDetails: any(named: 'notificationDetails'),
                androidScheduleMode: any(named: 'androidScheduleMode'),
              ),
            ).captured.single
            as tz.TZDateTime;

    // Asserting the instant, not the wall clock: tz.local is UTC under test,
    // so a 09:00 local DateTime legitimately renders as a different hour.
    // What must hold is that no time was lost in the conversion.
    expect(
      scheduled.millisecondsSinceEpoch,
      DateTime(2026, 9, 1, 9).millisecondsSinceEpoch,
    );
  });

  test('cancels reminders that are no longer scheduled', () async {
    await adapter.applySchedule(
      [_reminder(id: 2, fireAt: DateTime(2026, 9, 1))],
      previousIds: [1, 2, 3],
    );

    // 2 survives; only the dropped ids are cancelled.
    final cancelled = verify(
      () => plugin.cancel(id: captureAny(named: 'id')),
    ).captured;
    expect(cancelled, unorderedEquals([1, 3]));
  });

  test('initializes once, not per applySchedule call', () async {
    await adapter.applySchedule([
      _reminder(id: 1, fireAt: DateTime(2026, 9, 1)),
    ]);
    await adapter.applySchedule([
      _reminder(id: 1, fireAt: DateTime(2026, 9, 2)),
    ]);

    verify(() => plugin.initialize(settings: any(named: 'settings'))).called(1);
  });
}
