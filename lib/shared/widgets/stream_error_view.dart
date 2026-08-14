import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shown in place of a list when its query fails.
///
/// Every list in the app used to branch only on "no data yet", and a failed
/// stream never has data -- so any failure became a spinner that turned
/// forever. PM report: the prevention record history did exactly that, with
/// records saved and visible in the console.
///
/// A spinner is a promise that something is coming. When nothing is coming,
/// say so and offer the one action that can help.
class StreamErrorView extends StatelessWidget {
  const StreamErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The owner gets a plain sentence; the detail goes where a developer can
    // find it. Firestore's messages name collections and index URLs, which
    // is exactly what should not appear on someone's phone.
    developer.log('Stream failed', name: 'StreamErrorView', error: error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.listLoadFailedMessage, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.listLoadFailedRetryButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
