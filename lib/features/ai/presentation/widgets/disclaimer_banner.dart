import 'package:flutter/material.dart';

/// Permanent, always-visible disclaimer required by spec 6.5: "本機能は医療
/// 診断ではなく、受診目安の参考情報です". Must be shown on every AI response
/// screen, not just on first use — do not gate this behind a dismiss button.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  static const String text =
      '本機能は医療診断ではなく、受診目安の参考情報です。'
      '症状が続く場合や心配な場合は、必ず動物病院を受診してください。';

  @override
  Widget build(BuildContext context) {
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
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
