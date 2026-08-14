import 'package:flutter/material.dart';

/// The app-level [ScaffoldMessenger], for messages that have to outlive the
/// screen that produced them.
///
/// Most messages can use `ScaffoldMessenger.of(context)`: the screen is still
/// there to hold them. This key exists for the case where it is not.
///
/// Account deletion is that case. A failed deletion can have already removed
/// the account's pets, which empties the pet list, which makes
/// LaunchGateScreen swap the whole app shell out for the "add a pet" screen
/// -- taking the deletion screen, and any error shown on it, with it. The
/// owner was left looking at an empty app with no explanation of where their
/// data went. Attached to MaterialApp, this messenger sits above all of that
/// and survives the swap.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows [message] on whichever screen the user ends up on.
///
/// No-ops if the app-level messenger is not mounted (widget tests that build
/// a screen without a MaterialApp), so a message can never be the thing that
/// crashes a screen.
void showAppMessage(String message) {
  appMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}
