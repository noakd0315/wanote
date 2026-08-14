import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../billing/ads/ad_gate.dart';
import '../../billing/domain/ad_trigger.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/image_source_sheet.dart';
import '../data/health_record_repository.dart';
import '../models/health_record.dart';
import 'widgets/health_record_labels.dart';
import '../../../shared/utils/image_picking.dart';
import '../../../shared/app_messenger.dart';

/// Spec 2.2: "新規記録画面：写真添付（複数枚、最大4〜6枚程度を想定）、
/// カテゴリタグ選択、コメント入力". Also doubles as the edit form when
/// [existingRecord] is provided (spec 2.2's detail-screen edit action).
class HealthRecordFormScreen extends StatefulWidget {
  const HealthRecordFormScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.existingRecord,
  });

  final String uid;
  final String petId;
  final HealthRecordRepository repository;
  final HealthRecord? existingRecord;

  @override
  State<HealthRecordFormScreen> createState() => _HealthRecordFormScreenState();
}

class _HealthRecordFormScreenState extends State<HealthRecordFormScreen> {
  final _memoController = TextEditingController();
  final _picker = ImagePicker();
  final Set<HealthRecordTag> _selectedTags = {};

  /// Existing (already-uploaded) photo URLs kept from the record being
  /// edited, plus newly-picked-but-not-yet-uploaded photo bytes.
  List<String> _retainedPhotoUrls = [];
  final List<Uint8List> _newPhotoBytes = [];
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;

  int get _totalPhotoCount => _retainedPhotoUrls.length + _newPhotoBytes.length;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRecord;
    if (existing != null) {
      _memoController.text = existing.memo ?? '';
      _selectedTags.addAll(existing.tags);
      _retainedPhotoUrls = [...existing.photos];
      _recordedAt = existing.recordedAt;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _pickPhotos() {
    if (_totalPhotoCount >= HealthRecord.maxPhotos) return;
    showImageSourceSheet(
      context: context,
      onCamera: () => unawaited(_pickFromCamera()),
      onGallery: () => unawaited(_pickFromGallery()),
    );
  }

  // Camera capture is inherently one photo at a time, unlike the gallery
  // multi-select below.
  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImageDownscaled(source: ImageSource.camera);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _newPhotoBytes.add(bytes));
  }

  Future<void> _pickFromGallery() async {
    final remaining = HealthRecord.maxPhotos - _totalPhotoCount;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImageDownscaled(limit: remaining);
    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      _newPhotoBytes.add(bytes);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Read before the first await; used after the save completes.
    final adGate = adGateOf(context);
    final savedMessage = AppLocalizations.of(context)!.commonSavedMessage;
    final hasNewPhotos = _newPhotoBytes.isNotEmpty;
    try {
      final existing = widget.existingRecord;
      if (existing == null) {
        await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          recordedAt: _recordedAt,
          photoBytes: _newPhotoBytes,
          tags: _selectedTags.toList(),
          memo: _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
        );
      } else {
        await widget.repository.update(
          uid: widget.uid,
          record: existing,
          recordedAt: _recordedAt,
          tags: _selectedTags.toList(),
          memo: _memoController.text.trim().isEmpty
              ? null
              : _memoController.text.trim(),
          retainedPhotoUrls: _retainedPhotoUrls,
          newPhotoBytes: _newPhotoBytes,
        );
      }
      // Only after the write has returned. An ad shown between the tap and
      // the write landing would, if the app died behind it, lose the record
      // the owner just entered -- and losing someone's data to show them an
      // ad is not a trade this app makes. What can be lost here is the ad
      // impression, which is the right thing to risk.
      //
      // Photos only: a text-only record is the everyday act this app exists
      // for, and putting an ad in front of it daily would make the core
      // feature unpleasant (PLAN_ads decision 2).
      // Leave first, then confirm, then the ad. The record is already
      // written by this point, so nothing is at risk in closing the screen,
      // and the owner ends up back at the list with their entry in it --
      // which is the answer to "did that work?".
      //
      // Previously the ad went up while the form was still on screen and
      // there was no message at all, so there was no way to tell a saved
      // record from a lost one (PM report). The message goes through the
      // app-level messenger because the screen that would have shown it is
      // deliberately gone by then.
      if (mounted) Navigator.of(context).pop();
      showAppMessage(savedMessage);
      if (hasNewPhotos) {
        await adGate?.maybeShow(AdTrigger.healthRecordUpload);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Blocks back-navigation while saving (incl. photo upload) is in
    // flight -- otherwise leaving mid-upload could land the user on
    // another screen before the photos are actually persisted, making it
    // look like they silently failed to save (PM report: "写真データの
    // 送信が完了する前にほかの画面に移ると、写真登録がされません").
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.savingInProgressMessage)));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingRecord == null
                ? l10n.healthRecordFormTitleNew
                : l10n.healthRecordFormTitleEdit,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.healthRecordDateTimeLabel),
              subtitle: Text(_recordedAt.toString()),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _recordedAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _recordedAt = date);
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.healthRecordTagsSectionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: HealthRecordTag.values.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(healthRecordTagLabel(context, tag)),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.healthRecordPhotosSectionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in _retainedPhotoUrls)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _retainedPhotoUrls.remove(url)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                for (final bytes in _newPhotoBytes)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          bytes,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _newPhotoBytes.remove(bytes)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_totalPhotoCount < HealthRecord.maxPhotos)
                  InkWell(
                    onTap: _pickPhotos,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
              ],
            ),
            Text(
              l10n.healthRecordPhotoCount(
                _totalPhotoCount,
                HealthRecord.maxPhotos,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.healthRecordCommentLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
