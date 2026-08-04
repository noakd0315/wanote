import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/health_record_repository.dart';
import '../models/health_record.dart';
import 'health_record_form_screen.dart';
import 'widgets/health_record_labels.dart';

/// Spec 2.2: "記録詳細画面：編集・削除".
class HealthRecordDetailScreen extends StatelessWidget {
  const HealthRecordDetailScreen({
    super.key,
    required this.uid,
    required this.record,
    required this.repository,
  });

  final String uid;
  final HealthRecord record;
  final HealthRecordRepository repository;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.healthRecordDeleteConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.delete(uid: uid, record: record);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through, per the PM's request to scatter the
      // pattern across every non-input-form screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(DateFormat('yyyy/MM/dd HH:mm').format(record.recordedAt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HealthRecordFormScreen(
                    uid: uid,
                    petId: record.petId,
                    repository: repository,
                    existingRecord: record,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (record.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: record.tags
                  .map(
                    (t) => Chip(label: Text(healthRecordTagLabel(context, t))),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          if (record.photos.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: record.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    record.photos[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(record.memo ?? l10n.healthRecordNoCommentPlaceholder),
        ],
      ),
    );
  }
}
