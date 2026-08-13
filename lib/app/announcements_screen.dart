import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../shared/models/announcement.dart';
import '../shared/services/announcement_repository.dart';

/// The full list of current notices, reachable from 設定.
///
/// The banner on Home can be dismissed, so without this there would be no
/// way back to something the owner closed by accident -- including the one
/// telling them support cannot answer them this week.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key, required this.repository});

  final AnnouncementRepository repository;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.announcementsMenuTitle)),
      body: StreamBuilder<List<Announcement>>(
        stream: repository.watchVisible(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.announcementsLoadFailed));
          }
          final announcements = snapshot.data;
          if (announcements == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (announcements.isEmpty) {
            return Center(child: Text(l10n.announcementsEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            separatorBuilder: (_, _) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (announcement.important) ...[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          announcement.titleFor(language),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(announcement.publishedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(announcement.bodyFor(language)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
