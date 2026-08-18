import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two ARB files have to describe the same app.
///
/// wanote/.claude/CLAUDE.md asks for every new key to be added to both, and
/// the failure when that is missed is quiet: `flutter gen-l10n` falls back
/// to the template, so an English build silently shows Japanese and nothing
/// says so until someone reads that screen in English. This is the check
/// that says so.
void main() {
  Map<String, dynamic> load(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final ja = load('lib/l10n/app_ja.arb');
  final en = load('lib/l10n/app_en.arb');

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('every message exists in both languages', () {
    final jaKeys = messageKeys(ja);
    final enKeys = messageKeys(en);
    expect(
      jaKeys.difference(enKeys),
      isEmpty,
      reason: 'These have no English translation',
    );
    expect(
      enKeys.difference(jaKeys),
      isEmpty,
      reason: 'These have no Japanese translation',
    );
  });

  test('translations are not left as copies of the Japanese', () {
    // A handful genuinely read the same in both. Listed rather than
    // pattern-matched, so adding one is a decision someone makes on
    // purpose.
    const identicalOnPurpose = {
      'emailLabel', // "Email"
      'passwordLabel', // "Password"
      'orDivider', // "or"
      'commonLoadingLabel', // "loading...", styled as part of the mark
    };
    final copied = messageKeys(ja)
        .where((k) => ja[k] == en[k])
        .where((k) => !identicalOnPurpose.contains(k))
        .toList();
    expect(
      copied,
      isEmpty,
      reason: 'English still holds the Japanese string for these',
    );
  });

  test('placeholders match between the two', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in messageKeys(ja)) {
      final jaSlots = placeholder
          .allMatches(ja[key] as String)
          .map((m) => m.group(1))
          .toSet();
      final enSlots = placeholder
          .allMatches(en[key] as String)
          .map((m) => m.group(1))
          .toSet();
      expect(
        enSlots,
        jaSlots,
        reason: 'Placeholders differ for "$key" -- one language would '
            'render a literal {name} or drop a value',
      );
    }
  });
}
