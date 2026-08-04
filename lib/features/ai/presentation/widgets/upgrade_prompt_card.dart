import 'package:flutter/material.dart';

/// Shown in place of an AI result when [UsageLimitPolicy] (or the
/// hasUnlimitedSubscription gate on the report screen) says the caller can't
/// proceed. This is a stub hook point for Agent E's billing UI: features/ai
/// does not import lib/features/billing/ directly, so the actual
/// navigation/paywall is supplied by the caller via [onUpgrade].
class UpgradePromptCard extends StatelessWidget {
  const UpgradePromptCard({
    super.key,
    required this.message,
    required this.onUpgrade,
  });

  final String message;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onUpgrade,
            child: const Text('チケットを購入 / 有料プランを見る'),
          ),
        ],
      ),
    );
  }
}
