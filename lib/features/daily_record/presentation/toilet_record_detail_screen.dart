import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/toilet_record_repository.dart';
import '../models/toilet_record.dart';
import 'widgets/toilet_labels.dart';

/// The full view of a stool record, and the only place its photo can be
/// seen.
///
/// PM report: a photo could be attached to a stool record and then never
/// looked at again -- the timeline row shows hardness, colour and location,
/// and nothing opened. The photo was stored, uploaded and paid for, and
/// invisible.
///
/// Stool only. A urine record carries no photo and holds nothing the list
/// row does not already show, so its rows do not open.
class ToiletRecordDetailScreen extends StatelessWidget {
  const ToiletRecordDetailScreen({
    super.key,
    required this.uid,
    required this.record,
    required this.repository,
  });

  final String uid;
  final ToiletRecord record;
  final ToiletRecordRepository repository;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.toiletStoolDeleteConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.toiletStoolDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.delete(uid: uid, record: record);
    // The record this screen is about no longer exists, so neither should
    // the screen.
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final condition = record.stoolCondition;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.toiletStoolDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.commonDateLabel),
            subtitle: Text(
              DateFormat('yyyy/MM/dd HH:mm').format(record.recordedAt),
            ),
          ),
          if (condition != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.toiletHardnessSectionLabel),
              subtitle: Text(stoolHardnessLabel(context, condition.hardness)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.toiletColorSectionLabel),
              subtitle: Text(stoolColorLabel(context, condition.color)),
            ),
          ],
          if (record.location != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.toiletLocationOptionalLabel),
              subtitle: Text(record.location!),
            ),
          if (record.photo != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                record.photo!,
                fit: BoxFit.contain,
                // A photo that will not load must not leave a broken box
                // with no explanation of what happened.
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image_outlined, size: 48),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
