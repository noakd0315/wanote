import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Permanent, always-visible disclaimer required by spec 6.5: "本機能は医療
/// 診断ではなく、受診目安の参考情報です". Must be shown on every AI response
/// screen, not just on first use — do not gate this behind a dismiss button.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red, not the muted grey it used to be (PM request): this is the
          // "医療診断ではない" notice spec 6.5 requires on every AI screen, and
          // grey-on-grey read as boilerplate the eye skips over.
          Icon(Icons.info_outline, size: 18, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.aiDisclaimerText,
              style: TextStyle(fontSize: 12, color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
