import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../billing/ads/ad_gate.dart';
import '../../billing/domain/ad_trigger.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/image_source_sheet.dart';
import '../data/toilet_record_repository.dart';
import '../models/toilet_record.dart';
import 'widgets/toilet_labels.dart';
import '../../../shared/utils/image_picking.dart';
import 'dart:developer' as developer;
import '../../../shared/app_messenger.dart';
import '../data/health_record_repository.dart';
import '../models/health_record.dart';
import '../../../shared/utils/formatting.dart';

/// Spec 4.2: "便の状態選択（硬さ：正常／軟便／下痢／硬い、色：正常／血便疑い
/// ／白っぽい 等）" plus optional photo attachment for abnormal findings, plus
/// editable date/time and an optional location (PM requests: 排便の記録も
/// 日時が欲しい／排尿、排便とも任意項目で場所の入力欄が欲しい).
/// Shown when the user taps the "排便" one-tap button — urine records skip
/// this screen entirely and are created directly (spec 4.2's "ワンタップ記録").
class ToiletRecordFormScreen extends StatefulWidget {
  const ToiletRecordFormScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.type = ToiletType.stool,
    this.healthRecordRepository,
    this.imagePicker,
  });

  final String uid;
  final String petId;

  /// Which kind of record this form writes.
  ///
  /// Urine used to be entered in a dialog, which the keyboard broke when the
  /// location field was focused. Fixing the dialog kept it fast but left two
  /// different ways to record the same kind of thing; the PM asked for one
  /// screen, matching stool. The form adapts rather than being duplicated --
  /// the date, the location and the save are identical, and only the
  /// condition fields differ.
  final ToiletType type;
  final ToiletRecordRepository repository;

  /// Supplied only when the daily log is reachable from here. Null in tests
  /// that build this screen alone, and the copy toggle is hidden then --
  /// an offer the app cannot honour should not be on screen.
  final HealthRecordRepository? healthRecordRepository;

  /// Injectable so a test can drive the photo path, the way
  /// PreventionRecordFormScreen already allows. Without it the
  /// photo-and-ad ordering is untestable: the picker is the only way a
  /// photo ever gets attached.
  final ImagePicker? imagePicker;

  @override
  State<ToiletRecordFormScreen> createState() => _ToiletRecordFormScreenState();
}

class _ToiletRecordFormScreenState extends State<ToiletRecordFormScreen> {
  StoolHardness _hardness = StoolHardness.normal;
  StoolColor _color = StoolColor.normal;
  UrineColor _urineColor = UrineColor.normal;

  bool get _isUrine => widget.type == ToiletType.urine;
  Uint8List? _photoBytes;

  /// Off by default, deliberately. Most bowel movements are unremarkable,
  /// and copying every one into the daily log would bury the entries the
  /// owner made because something was wrong. PM: the owner decides.
  bool _copyToDailyLog = false;

  /// Whether this form has already spent its ad impression.
  ///
  /// A failed save leaves the owner on the screen to try again, and making
  /// them sit through a second ad for the same record would be charging
  /// them twice for one action -- the failure was not theirs (PM request).
  bool _adAlreadyShown = false;

  bool _saving = false;

  // PM request: 排便の記録も日時が欲しい -- defaults to now like the urine
  // one-tap dialog, but editable for logging something noticed after the
  // fact.
  DateTime _recordedAt = DateTime.now();

  // PM request: 排尿、排便とも任意項目で場所の入力欄が欲しい.
  final _locationController = TextEditingController();

  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _recordedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _recordedAt.hour,
        _recordedAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (picked == null) return;
    setState(() {
      _recordedAt = DateTime(
        _recordedAt.year,
        _recordedAt.month,
        _recordedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _pickPhoto() {
    showImageSourceSheet(
      context: context,
      onCamera: () => unawaited(_pickAndSet(ImageSource.camera)),
      onGallery: () => unawaited(_pickAndSet(ImageSource.gallery)),
    );
  }

  Future<void> _pickAndSet(ImageSource source) async {
    final file = await _imagePicker.pickImageDownscaled(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  /// The tags a copied entry gets. Mapped, not inferred: both come from
  /// choices the owner made on this form.
  List<HealthRecordTag> _copiedTags() => [
    if (_hardness == StoolHardness.diarrhea) HealthRecordTag.diarrhea,
    if (_color == StoolColor.bloodSuspected) HealthRecordTag.bloodyStool,
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    // Read before the first await; used after the save completes.
    final adGate = adGateOf(context);
    final l10n = AppLocalizations.of(context)!;
    final copyMemo = l10n.toiletStoolCopyMemo(
      stoolHardnessLabel(context, _hardness),
      stoolColorLabel(context, _color),
    );
    final copyFailedMessage = l10n.toiletCopyToDailyLogFailedMessage;
    final savedMessage = l10n.commonSavedMessage;
    final saveFailedMessage = l10n.saveFailedRetryMessage;
    final hasPhoto = _photoBytes != null;
    try {
      final location = _locationController.text.trim();
      // The ad goes up on the tap and the write runs behind it, rather than
      // the write finishing first and the ad following. Waiting for the
      // upload before showing anything left a gap with nothing in it (PM:
      // "変なタイムラグ"), and the ad now fills exactly the time the upload
      // takes instead of being added on top of it.
      //
      // The trade this makes: if Android kills the process while the ad is
      // up, an in-flight write can be lost. Previously that could not
      // happen, because nothing was in flight. It is the owner's call, and
      // the window is the length of one upload.
      final adShown = (hasPhoto && !_adAlreadyShown)
          ? adGate?.maybeShow(AdTrigger.toiletRecordUpload)
          : null;
      if (adShown != null) _adAlreadyShown = true;
      final saved = await widget.repository.create(
        uid: widget.uid,
        petId: widget.petId,
        type: widget.type,
        stoolCondition: _isUrine
            ? null
            : StoolCondition(hardness: _hardness, color: _color),
        urineColor: _isUrine ? _urineColor : null,
        photoBytes: _photoBytes,
        recordedAt: _recordedAt,
        location: location.isEmpty ? null : location,
      );
      // The copy comes after the record it copies. If this fails the record
      // still exists, which is the half that matters; the owner is told so
      // they do not enter it again.
      //
      // The photo is referenced, not duplicated: the copy points at the file
      // this record already uploaded. One image, one place, so the two
      // entries can never end up showing different pictures, and the storage
      // is paid for once (PM: 一元管理が好ましい).
      final healthRecords = widget.healthRecordRepository;
      if (_copyToDailyLog && healthRecords != null && !_isUrine) {
        try {
          await healthRecords.create(
            uid: widget.uid,
            petId: widget.petId,
            recordedAt: _recordedAt,
            photoBytes: const [],
            linkedPhotoUrls: [if (saved.photo != null) saved.photo!],
            tags: _copiedTags(),
            memo: location.isEmpty ? copyMemo : '$copyMemo / $location',
          );
        } catch (error, stackTrace) {
          developer.log(
            'Could not copy the stool record into the daily log',
            name: 'ToiletRecordFormScreen',
            error: error,
            stackTrace: stackTrace,
          );
          showAppMessage(copyFailedMessage);
        }
      }
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
      // Waits for the ad to be dismissed, not merely shown. The message
      // below is the whole point of this ordering, and behind a full-screen
      // ad nobody would ever see it.
      await adShown;
      if (mounted) Navigator.of(context).pop();
      showAppMessage(savedMessage);
    } catch (error, stackTrace) {
      // Stay put, with everything still filled in. Closing on a failure
      // would throw away what the owner typed and leave them to enter it
      // again from memory.
      developer.log(
        'Could not save the toilet record',
        name: 'ToiletRecordFormScreen',
        error: error,
        stackTrace: stackTrace,
      );
      showAppMessage(saveFailedMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // See health_record_form_screen.dart's build() for why this guard
    // exists (PM report about photos not saving if you navigate away
    // mid-upload).
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.savingInProgressMessage)));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.toiletRecordStoolFormTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.commonDateLabel),
              subtitle: Text(formatDate(context, _recordedAt)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.commonTimeLabel),
              subtitle: Text(formatTime(context, _recordedAt)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            if (_isUrine) ...[
              Text(
                l10n.toiletUrineColorShadeLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: UrineColor.values.map((c) {
                  return ChoiceChip(
                    label: Text(urineColorLabel(context, c)),
                    selected: _urineColor == c,
                    onSelected: (_) => setState(() => _urineColor = c),
                  );
                }).toList(),
              ),
            ] else ...[
              Text(
                l10n.toiletHardnessSectionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: StoolHardness.values.map((h) {
                  return ChoiceChip(
                    label: Text(stoolHardnessLabel(context, h)),
                    selected: _hardness == h,
                    onSelected: (_) => setState(() => _hardness = h),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.toiletColorSectionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: StoolColor.values.map((c) {
                  return ChoiceChip(
                    label: Text(stoolColorLabel(context, c)),
                    selected: _color == c,
                    onSelected: (_) => setState(() => _color = c),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.toiletLocationOptionalLabel,
              ),
            ),
            const SizedBox(height: 16),
            // Urine records take no photo -- the PM confirmed there is
            // nothing to look at -- so the button, the preview and the ad
            // that follows an upload are all absent for them.
            if (!_isUrine)
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _photoBytes == null
                      ? l10n.toiletPhotoAddLabel
                      : l10n.toiletPhotoChangeLabel,
                ),
              ),
            if (!_isUrine && _photoBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    _photoBytes!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (widget.healthRecordRepository != null && !_isUrine)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _copyToDailyLog,
                onChanged: (value) =>
                    setState(() => _copyToDailyLog = value),
                title: Text(l10n.toiletCopyToDailyLogLabel),
                subtitle: Text(l10n.toiletCopyToDailyLogDescription),
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
