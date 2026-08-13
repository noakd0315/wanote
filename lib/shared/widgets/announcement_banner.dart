import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/announcement.dart';
import '../services/announcement_repository.dart';

/// Shows the newest notice the owner has not dismissed yet.
///
/// Renders nothing at all when there is no notice, when they have all been
/// dismissed, or while the first snapshot is still loading -- a banner that
/// flickers an empty box on every launch would be worse than no banner.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({
    super.key,
    required this.repository,
    this.readState,
    this.importantOnly = false,
    this.onSeeAll,
  });

  final AnnouncementRepository repository;
  final AnnouncementReadState? readState;

  /// Used on the sign-in screen, which shows only what people need to know
  /// when they cannot get into the app.
  final bool importantOnly;

  /// Shown as a "see all" action when the app has somewhere to send them.
  /// Omitted on the sign-in screen, which has no settings to open.
  final VoidCallback? onSeeAll;

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  late final AnnouncementReadState _readState =
      widget.readState ?? AnnouncementReadState();

  Set<String> _dismissed = const {};
  bool _loadedDismissed = false;

  /// Opened once rather than per build: a StreamBuilder handed a fresh
  /// stream on every rebuild re-subscribes to Firestore each time.
  late final Stream<List<Announcement>> _announcements = _open();

  Stream<List<Announcement>> _open() {
    try {
      return widget.repository.watchVisible();
    } catch (error) {
      // No Firebase app (widget tests), or the query was rejected. Notices
      // are the last thing that should be able to break a screen.
      return Stream<List<Announcement>>.error(error);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final dismissed = await _readState.dismissedIds();
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _loadedDismissed = true;
    });
  }

  Future<void> _dismiss(Announcement announcement) async {
    setState(() => _dismissed = {..._dismissed, announcement.id});
    await _readState.dismiss(announcement.id);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedDismissed) return const SizedBox.shrink();

    return StreamBuilder<List<Announcement>>(
      stream: _announcements,
      builder: (context, snapshot) {
        final announcements = snapshot.data;
        // Also the error case: a notice failing to load must never be
        // something the owner has to look at.
        if (announcements == null) return const SizedBox.shrink();

        final candidates = announcements.where(
          (a) =>
              !_dismissed.contains(a.id) &&
              (!widget.importantOnly || a.important),
        );
        if (candidates.isEmpty) return const SizedBox.shrink();

        return _BannerCard(
          announcement: candidates.first,
          onDismiss: () => _dismiss(candidates.first),
          onSeeAll: widget.onSeeAll,
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.announcement,
    required this.onDismiss,
    this.onSeeAll,
  });

  final Announcement announcement;
  final VoidCallback onDismiss;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final onColor = announcement.important
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: announcement.important
          ? colors.errorContainer
          : colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  announcement.important
                      ? Icons.warning_amber_rounded
                      : Icons.campaign_outlined,
                  color: onColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement.titleFor(language),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: onColor),
                  tooltip: l10n.announcementDismissTooltip,
                  onPressed: onDismiss,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 8),
              child: Text(
                announcement.bodyFor(language),
                style: TextStyle(color: onColor),
              ),
            ),
            if (onSeeAll != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(foregroundColor: onColor),
                  child: Text(l10n.announcementSeeAllButton),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
