import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications on iOS. Without a delegate,
    // iOS has nowhere to hand a notification that comes due while the app
    // is in the foreground, so scheduled reminders simply never appear --
    // which is what the PM saw on iPhone while Android worked (2026-08-17).
    // Android needs no equivalent; this is the whole of the difference.
    //
    // Set before super, so the delegate is in place by the time the plugins
    // register. firebase_messaging also claims this delegate, but it keeps
    // whatever was already there and forwards callbacks it does not handle
    // -- so ours has to be installed first, not after registration.
    //
    // Conditional cast rather than a plain `self`, per the plugin's own iOS
    // setup instructions: it compiles whether or not FlutterAppDelegate
    // declares the conformance, which this machine cannot check (no iOS
    // artifacts on Windows -- Codemagic builds it).
    if let notificationDelegate = self as? UNUserNotificationCenterDelegate {
      UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
