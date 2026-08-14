import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_scheduler.dart';
import '../domain/reminder_strings.dart';

/// Thin adapter that turns the schedulers' pure output into actual
/// `flutter_local_notifications` calls. All the "what/when to notify"
/// decisions live in [ReminderScheduler] and [MedicationReminderScheduler];
/// this class only knows how to talk to the plugin, so it has no unit tests
/// of its own (untestable without a real platform channel) -- it's kept
/// intentionally tiny, and ReminderSyncService is the part with tests.
///
/// Local, on-device scheduling was chosen over a server-side batch job: a
/// Cloudflare Worker has no free always-on cron (spec section 9 explicitly
/// warns against always-on server costs), and even a paid Cron Trigger would
/// still need its own way to reach APNs/FCM. Since the data needed
/// (next_due_date, reminder_time) is already synced to the device via
/// Firestore, scheduling the local notification directly from that data is
/// the pragmatic, zero-marginal-cost option.
class ReminderNotificationAdapter {
  ReminderNotificationAdapter({
    FlutterLocalNotificationsPlugin? plugin,
    bool? supported,
    this.strings = ReminderStrings.fallback,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _supported = supported ?? platformSupported;

  /// The channel's own name and description are shown in Android's settings
  /// for this app, so they are localized like the notifications themselves.
  final ReminderStrings strings;

  static const String _channelId = 'medical_reminders';

  final FlutterLocalNotificationsPlugin _plugin;

  /// Injected only by tests, which run on the host platform and would
  /// otherwise take the no-op path and assert nothing.
  final bool _supported;
  bool _initialized = false;

  /// Local notifications have no web implementation, and no desktop one we
  /// ship, so every call is a no-op elsewhere rather than a crash. The app
  /// runs on web throughout development, so this path is the common one.
  ///
  /// Deliberately not `dart:io`: importing it breaks the web build outright.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isSupported => _supported;

  Future<void> initialize() async {
    if (_initialized || !_supported) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Deliberately does NOT request permission here -- iOS shows the prompt
    // on the first request, and a prompt during app start (before the owner
    // has any idea what would be notified) gets denied. See
    // [requestPermissions], which the app calls when a reminder is first
    // turned on.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    // flutter_local_notifications 22 made every argument named.
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Asks the OS for permission to post notifications, returning whether it
  /// was granted. Safe to call repeatedly: both platforms return the
  /// existing answer rather than re-prompting.
  ///
  /// Android 13+ requires this at runtime (POST_NOTIFICATIONS); before that
  /// it is granted at install time and this returns true.
  Future<bool> requestPermissions() async {
    if (!_supported) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Replaces the entire set of scheduled reminders with [reminders].
  ///
  /// Cancels everything first rather than diffing against a remembered set:
  /// the schedulers already recompute the full picture from Firestore on
  /// every sync, and a diff would need its own persisted state that could
  /// drift out of step with reality. This app posts no other notifications,
  /// so cancelling all of them is exactly the intended scope.
  Future<void> applySchedule(List<ScheduledReminder> reminders) async {
    if (!_supported) return;
    await initialize();
    await _plugin.cancelAll();

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            strings.channelName,
            channelDescription: strings.channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // uiLocalNotificationDateInterpretation is gone in 22: a TZDateTime
        // is now always interpreted as absolute time, which is what we were
        // asking for anyway.
        //
        // inexact, not exactAllowWhileIdle. Exact alarms need
        // SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM on Android 12+, and Google
        // Play restricts those to apps whose *core* purpose is alarms or
        // calendars -- declaring one invites a policy rejection, and on
        // Android 14 the user has to grant it in Settings anyway, so a
        // silently-denied permission would mean silently missing reminders.
        // A dose reminder that lands within the system's batching window of
        // 09:00 is fine; one that never fires is not.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: reminder.repeatsDaily
            ? DateTimeComponents.time
            : null,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    await _plugin.cancelAll();
  }

  /// The device's IANA zone name. Without this `tz.local` stays UTC, and a
  /// daily reminder set for 08:00 would repeat on UTC's clock -- correct
  /// today in Japan (no DST), wrong twice a year everywhere that has it.
  /// Falls back to UTC if the platform can't say.
  Future<String> _deviceTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}
