import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/services/ai_usage_repository.dart';

/// How many AI calls the owner has left, shown on the screens that spend
/// them (PM request: "AIの残り回数を表示してほしい").
///
/// Before this, the only way to find out was to run out: the free
/// allowance is silent until it is gone, and then the screen refuses. With
/// five a month, knowing whether this is the second or the last one is the
/// difference between asking and saving it.
///
/// Says the one number that answers "can I ask again", not all three.
/// Which pot the next call comes out of is [AiUsageStatus.nextSource]'s
/// business, and free is always spent before tickets -- so the free count
/// is the live one until it hits zero, at which point tickets become it.
///
/// Watches rather than reads. The parent used to hand down a token it
/// bumped after spending a call, which covered the one change it made
/// itself and no other: a ticket bought on the paywall landed in Firestore
/// and never reached the badge, so a purchase looked like it had gone
/// missing (PM, 2026-08-21).
class AiUsageBadge extends StatefulWidget {
  const AiUsageBadge({
    super.key,
    required this.uid,
    required this.usageRepository,
  });

  final String uid;
  final AiUsageRepository usageRepository;

  @override
  State<AiUsageBadge> createState() => _AiUsageBadgeState();
}

class _AiUsageBadgeState extends State<AiUsageBadge> {
  late Stream<AiUsageStatus> _status = widget.usageRepository.watchStatus(
    widget.uid,
  );

  @override
  void didUpdateWidget(AiUsageBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      setState(() {
        _status = widget.usageRepository.watchStatus(widget.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<AiUsageStatus>(
      stream: _status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        // Nothing while it loads, and nothing if it fails. This is a
        // convenience, not a gate -- the screen's own check is what decides
        // whether a call may be made, and an error box here would be
        // alarming about something that does not block anything.
        if (status == null) return const SizedBox.shrink();

        final labelled = _label(l10n, status);
        if (labelled == null) return const SizedBox.shrink();
        final (label, isEmpty) = labelled;
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Icon(
                isEmpty ? Icons.error_outline : Icons.auto_awesome,
                size: 16,
                color: isEmpty ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isEmpty ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The badge's text, or null when there is nothing worth saying.
  ///
  /// Null while the allowance is unlimited *and* nothing was paid for. The
  /// badge exists to answer "how many do I have left?", and there is no
  /// answer when the count does not move -- "使い放題プラン" sat where a
  /// number used to be and read as a status line nobody asked for (PM,
  /// 2026-08-21).
  ///
  /// Tickets are the exception. They were bought, they do not expire, and
  /// they still matter once the unlimited period ends -- hiding them made a
  /// purchase look like it had gone missing (PM, 2026-08-21: チケット課金
  /// したら残回数が出なくなった).
  (String, bool)? _label(AppLocalizations l10n, AiUsageStatus status) {
    final free = status.freeConsultationsRemainingThisMonth;
    final tickets = status.ticketsRemaining;
    if (status.hasUnlimitedSubscription) {
      if (tickets <= 0) return null;
      // Tickets only: the free count is not being spent either, so showing
      // it beside them would just be another number that never moves.
      return (l10n.aiUsageTicketsOnlyLabel(tickets), false);
    }

    // Both counts whenever tickets are held (PM request), not just the one
    // being spent next. Someone who has bought tickets wants to see they
    // still have them -- a badge that hid them until the free allowance ran
    // out would look like the purchase had gone missing. Showing free at 0
    // beside them also explains why tickets are the ones going down.
    if (tickets > 0) {
      return (
        l10n.aiUsageFreeAndTicketsLabel(
          free,
          FirestoreAiUsageRepository.freeMonthlyQuota,
          tickets,
        ),
        false,
      );
    }
    if (free > 0) {
      return (
        l10n.aiUsageFreeRemainingLabel(
          free,
          FirestoreAiUsageRepository.freeMonthlyQuota,
        ),
        false,
      );
    }
    return (l10n.aiUsageNoneRemainingLabel, true);
  }
}
