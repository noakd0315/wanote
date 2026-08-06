import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_scheduler.dart';

/// Thin adapter that turns [ReminderScheduler]'s pure output into actual
/// scheduled `flutter_local_notifications` calls. All the "what/when to
/// notify" decisions live in [ReminderScheduler]; this class only knows how
/// to talk to the plugin, so it has no unit tests of its own (untestable
/// without a real platform channel) — it's kept intentionally tiny.
///
/// Local, on-device scheduling was chosen over a server-side batch job: a
/// Cloudflare Worker has no free always-on cron (spec section 9 explicitly
/// warns against always-on server costs), and even a paid Cron Trigger would
/// still need its own way to reach APNs/FCM. Since the data needed
/// (next_due_date) is already synced to the device via Firestore, scheduling
/// the local notification directly from that data is the pragmatic,
/// zero-marginal-cost option.
class ReminderNotificationAdapter {
  ReminderNotificationAdapter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medical_prevention_reminders';
  static const String _channelName = '予防医療リマインダー';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    // flutter_local_notifications 22 made every argument named.
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Cancels every previously-scheduled reminder in [previousIds] that is
  /// no longer present in [reminders], then (re)schedules everything in
  /// [reminders]. Since [ScheduledReminder.notificationId] is deterministic
  /// per record, re-scheduling an unchanged reminder is a harmless
  /// overwrite.
  Future<void> applySchedule(
    List<ScheduledReminder> reminders, {
    List<int> previousIds = const [],
  }) async {
    await initialize();

    final nextIds = reminders.map((r) => r.notificationId).toSet();
    for (final staleId in previousIds.where((id) => !nextIds.contains(id))) {
      await _plugin.cancel(id: staleId);
    }

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'ワクチン・フィラリア・ノミダニ予防のリマインダー通知',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // uiLocalNotificationDateInterpretation is gone in 22: a TZDateTime
        // is now always interpreted as absolute time, which is what we were
        // asking for anyway.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
