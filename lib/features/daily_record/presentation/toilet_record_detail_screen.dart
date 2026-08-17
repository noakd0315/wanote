import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/models/consultation_reference_record.dart';
import '../data/toilet_record_repository.dart';
import '../models/toilet_record.dart';
import 'widgets/toilet_labels.dart';
import '../../../shared/utils/formatting.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';

/// The full view of one toilet record, and the only place a photo can be
/// seen.
///
/// PM report: a photo could be attached to a stool record and then never
/// looked at again -- the timeline row shows hardness, colour and location,
/// and nothing opened. The photo was stored, uploaded and paid for, and
/// invisible.
///
/// Urine records open here too (PM request: "排尿の詳細画面もほしい"). They
/// were excluded on the grounds that a urine row showed everything a record
/// held, which stopped being true once volume was added -- and the row only
/// ever had space for one of colour and volume anyway.
class ToiletRecordDetailScreen extends StatelessWidget {
  const ToiletRecordDetailScreen({
    super.key,
    required this.uid,
    required this.record,
    required this.repository,
    this.onConsultAi,
  });

  final String uid;
  final ToiletRecord record;
  final ToiletRecordRepository repository;

  /// Starts an AI consultation with this record attached (PM request:
  /// "トイレの詳細画面からAI相談できるようにしたい").
  ///
  /// A callback rather than a push, because features/daily_record must not
  /// import features/ai -- same boundary [AnomalyDetector] observes. The
  /// app shell owns the wiring; null hides the button, so the screen still
  /// stands alone in tests.
  final void Function(ConsultationReferenceRecord reference)? onConsultAi;

  bool get _isUrine => record.type == ToiletType.urine;

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

  /// The record, described in the reader's language, for the AI to read.
  ///
  /// Built here rather than taken from any stored string: the label is shown
  /// back to the owner in the consultation history, and a fixed-language one
  /// is how the warning banner ended up Japanese in the English app.
  ConsultationReferenceRecord _reference(AppLocalizations l10n, BuildContext c) {
    final tags = <String>[];
    final details = <String>[];
    if (_isUrine) {
      if (record.urineColor != null) {
        details.add(urineColorLabel(c, record.urineColor!));
        tags.add(record.urineColor!.wireName);
      }
      if (record.urineVolume != null) {
        details.add(urineVolumeLabel(c, record.urineVolume!));
        tags.add(record.urineVolume!.wireName);
      }
    } else if (record.stoolCondition != null) {
      details.add(stoolHardnessLabel(c, record.stoolCondition!.hardness));
      details.add(stoolColorLabel(c, record.stoolCondition!.color));
      tags.add(record.stoolCondition!.hardness.wireName);
      tags.add(record.stoolCondition!.color.wireName);
    }
    final typeLabel = _isUrine ? l10n.toiletUrineLabel : l10n.toiletStoolLabel;
    return ConsultationReferenceRecord(
      recordId: record.toiletId,
      recordType: ConsultationRecordType.toiletRecord,
      petId: record.petId,
      recordedAt: record.recordedAt,
      label: details.isEmpty
          ? typeLabel
          : '$typeLabel（${details.join('・')}）',
      tags: tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final condition = record.stoolCondition;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isUrine ? l10n.toiletUrineDetailTitle : l10n.toiletStoolDetailTitle,
        ),
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
            subtitle: Text(formatDateTime(context, record.recordedAt)),
          ),
          if (_isUrine) ...[
            if (record.urineColor != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.toiletUrineColorShadeLabel),
                subtitle: Text(urineColorLabel(context, record.urineColor!)),
              ),
            if (record.urineVolume != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.toiletUrineVolumeLabel),
                subtitle: Text(urineVolumeLabel(context, record.urineVolume!)),
              ),
          ] else if (condition != null) ...[
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
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: WanoteLoadingIndicator.centered(),
                      ),
              ),
            ),
          ],
          if (onConsultAi != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onConsultAi!(_reference(l10n, context)),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.toiletConsultAiButtonLabel),
            ),
          ],
        ],
      ),
    );
  }
}
