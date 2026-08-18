import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Asks before removing a record, and returns whether to go ahead.
///
/// The medical lists used to delete by swipe alone. That is invisible --
/// you have to already know it is there -- so the PM reported these screens
/// as having no delete at all (2026-08-18), and the one person who did find
/// it lost a record to a single unconfirmed gesture. Every list now shows a
/// button and every button asks, the same shape the weight and toilet lists
/// settled on.
///
/// [message] says what is about to be lost, because "delete?" is the same
/// question everywhere and a vaccination programme is not a vet visit.
Future<bool> confirmDelete(BuildContext context, String message) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
