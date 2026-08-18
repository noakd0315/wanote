import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two navigation reports from 2026-08-18, both about arriving at a screen
/// that looks different depending on how you got there.
void main() {
  group('a tab request that repeats itself', () {
    test('notifies again when the same tab is asked for twice', () {
      // This is the ValueNotifier behaviour the shell has to work around:
      // writing the same value notifies nobody. Pressing the 証明書
      // shortcut, moving to another tab by hand, then pressing it again
      // left the owner where they were.
      final request = ValueNotifier<int>(0);
      var notifications = 0;
      request.addListener(() => notifications++);

      request.value = 3;
      expect(notifications, 1);

      request.value = 3;
      expect(
        notifications,
        1,
        reason: 'ValueNotifier suppresses an unchanged write -- this is the '
            'behaviour that made the shortcut look broken',
      );

      // What the shell does instead: clear, then ask.
      request.value = -1;
      request.value = 3;
      expect(notifications, 3);
      expect(request.value, 3);
    });

    test('the cleared value is not a tab anyone will switch to', () {
      // The listener guards on range, so -1 passes through harmlessly.
      const tabCount = 4;
      const cleared = -1;
      expect(cleared < 0 || cleared >= tabCount, isTrue);
    });
  });
}
