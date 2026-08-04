import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Fixed "至急動物病院へ" notice shown instead of an AI response when
/// [EmergencyKeywordDetector] fires (spec 6.5). No AI/backend call happens
/// on this path.
class EmergencyNotice extends StatelessWidget {
  const EmergencyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.aiEmergencyMessage,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
