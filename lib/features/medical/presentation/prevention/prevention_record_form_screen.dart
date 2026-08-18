import 'dart:developer' as developer;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../billing/ads/ad_gate.dart';
import '../../../billing/domain/ad_trigger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/image_source_sheet.dart';
import '../../data/certificate_ocr_service.dart';
import '../../data/certificate_storage_service.dart';
import '../../data/prevention_record_repository.dart';
import '../../domain/models/prevention_program.dart';
import '../../domain/models/prevention_record.dart';
import '../../domain/ocr_result_validator.dart';
import '../../domain/prevention_due_date_calculator.dart';
import '../../../../shared/utils/image_picking.dart';
import '../../../../shared/app_messenger.dart';
import '../../domain/models/medication.dart' show ReminderTime;
import '../../../../shared/widgets/wanote_loading_indicator.dart';
import '../widgets/history_copy_picker.dart';
import '../../domain/reminder_scheduler.dart';

/// Create/edit screen for a `prevention_records` entry (spec 5.3), including
/// the AI-OCR capture-and-review flow (spec 5.4).
///
/// Per spec 5.4 step 4, OCR output is never auto-saved: it only prefills the
/// same editable text fields the user would fill in manually, and the user
/// must press the save button to commit -- identical code path whether the
/// fields were typed or prefilled.
class PreventionRecordFormScreen extends StatefulWidget {
  PreventionRecordFormScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.program,
    required this.repository,
    this.record,
    this.ocrService,
    CertificateStorageService? storageService,
    OcrResultValidator? ocrValidator,
    ImagePicker? imagePicker,
    PreventionDueDateCalculator? calculator,
  }) : storageService = storageService ?? FirebaseCertificateStorageService(),
       ocrValidator = ocrValidator ?? const OcrResultValidator(),
       imagePicker = imagePicker ?? ImagePicker(),
       calculator = calculator ?? const PreventionDueDateCalculator();

  final String uid;
  final String petId;
  final PreventionProgram program;
  final PreventionRecordRepository repository;
  final PreventionRecord? record;

  /// Nullable because no backend URL/Anthropic key exists yet in this repo
  /// (see report) -- when null, the OCR button just attaches the photo
  /// without calling the backend, instead of crashing on a network call.
  final CertificateOcrService? ocrService;
  final CertificateStorageService storageService;
  final OcrResultValidator ocrValidator;
  final ImagePicker imagePicker;
  final PreventionDueDateCalculator calculator;

  @override
  State<PreventionRecordFormScreen> createState() =>
      _PreventionRecordFormScreenState();
}

class _PreventionRecordFormScreenState
    extends State<PreventionRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();

  /// The vaccine type, or the drug name -- see the field's comment in
  /// build(). Also the landing place for the OCR's `product_name`, which
  /// used to be read off the certificate and discarded.
  final _productNameController = TextEditingController();

  /// PM request: heartworm and flea/tick treatments are medicine, so the
  /// form asks what any other medicine asks.
  final _dosageController = TextEditingController();

  bool get _isVaccine => widget.program.type == PreventionType.vaccine;

  /// The reminder for the next dose. On by default -- the point of
  /// recording a due date is not to miss it -- but a one-off vaccine or a
  /// course that has ended does not need one.
  bool _reminderEnabled = false;

  /// PM: a reminder just after midnight is no use to anyone, so the hour is
  /// the owner's to choose.
  ReminderTime _reminderTime = const ReminderTime(9, 0);

  /// Which "how far ahead" reminders the owner wants, in days before the
  /// due date. 0 is the due date itself.
  ///
  /// Empty means the type's default (a week for vaccines, three days for
  /// medication). Kept as a set: the same lead time twice is one reminder.
  Set<int> _reminderLeadDays = <int>{};
  late DateTime _administeredAt;
  DateTime? _nextDueDate;
  bool _nextDueDateManuallyEdited = false;

  Uint8List? _pickedImageBytes;
  String? _pickedImageContentType;
  String? _existingCertificateUrl;

  Map<String, dynamic>? _ocrExtractedData;
  double? _ocrConfidence;
  bool _ocrRunning = false;
  String? _ocrFallbackMessage;

  /// Which fields currently hold a value the OCR put there, rather than one
  /// the owner typed (PM request: OCRが入れた項目に要確認マークがほしい).
  ///
  /// A certificate scan is a good guess, not a reading -- a smudged 8 comes
  /// back as a 3 and nothing about the filled-in form says which numbers
  /// were guessed. Marks clear as soon as the field is touched: looking at
  /// it and deciding it is right is the confirmation being asked for.
  final Set<_OcrField> _needsReview = {};

  void _clearReview(_OcrField field) {
    if (_needsReview.remove(field)) setState(() {});
  }

  /// Whether this screen has already spent its ad impression.
  ///
  /// One ad per record, not per attempt: rescanning a certificate that did
  /// not read the first time is the owner fixing our failure, and charging
  /// them again for it is charging twice for one action (PM request).
  bool _adAlreadyShown = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Get an ad on the shelf while the form is being filled in.
    //
    // Only one interstitial is held at a time and the refill is a network
    // fetch, so a session that already spent its ad somewhere else finds
    // nothing loaded when the scan starts -- and a missing ad is silent by
    // design, which is why "広告が出ない" survived two rounds of fixes aimed
    // at the showing code (PM, 2026-08-18). Preloading here uses the minute
    // or so between opening this screen and pressing the shutter. No-ops if
    // one is already loaded or the owner is premium.
    //
    // Scheduled rather than called inline: adGateOf reads an inherited
    // widget, which initState cannot do.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(adGateOf(context)?.preload() ?? Future<void>.value());
    });
    final record = widget.record;
    _administeredAt = record?.administeredAt ?? DateTime.now();
    _nextDueDate = record?.nextDueDate;
    _nextDueDateManuallyEdited = _nextDueDate != null;
    _hospitalController.text = record?.hospitalName ?? '';
    // Falls back to the programme's own product name: a new dose of an
    // existing programme is almost always the same product, and retyping
    // it every month is work the app can do.
    _productNameController.text =
        record?.productName ?? widget.program.productName;
    _dosageController.text = record?.dosage ?? '';
    _reminderEnabled = record?.reminderEnabled ?? false;
    _reminderTime = record?.reminderTime ?? const ReminderTime(9, 0);
    _reminderLeadDays = {...?record?.reminderLeadDays};
    _existingCertificateUrl = record?.certificateFile;
    _ocrExtractedData = record?.ocrExtractedData;
    _ocrConfidence = record?.ocrConfidence;
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _productNameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _recalculateNextDueDateIfNotManuallyEdited() {
    if (_nextDueDateManuallyEdited) return;
    if (widget.program.scheduleType == ScheduleType.single) {
      // Spec 5.3: single-schedule (typical for vaccine) never auto-calculates.
      return;
    }
    setState(() {
      _nextDueDate = widget.calculator.calculateNextDueDate(
        scheduleType: widget.program.scheduleType,
        administeredAt: _administeredAt,
        intervalDays: widget.program.intervalDays,
      );
    });
  }

  void _pickAndAnalyzeCertificate() {
    showImageSourceSheet(
      context: context,
      onCamera: () => unawaited(_captureAndAnalyze(ImageSource.camera)),
      onGallery: () => unawaited(_captureAndAnalyze(ImageSource.gallery)),
    );
  }

  Future<void> _captureAndAnalyze(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    // Read before the first await, like l10n above.
    final adGate = adGateOf(context);
    final picked = await widget.imagePicker.pickImageDownscaled(
      source: source,
      maxDimension: kPickedCertificateMaxDimension,
    );
    if (picked == null) return;

    // Resize/compress client-side BEFORE any upload/API call (spec 5.4 step
    // 2 -- mandatory, both for upload bandwidth and OCR API cost).
    final compressed = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) return;

    setState(() {
      _pickedImageBytes = compressed;
      _pickedImageContentType = 'image/jpeg';
      _ocrFallbackMessage = null;
    });

    final ocrService = widget.ocrService;
    if (ocrService == null) {
      // No backend configured yet in this environment -- user can still
      // attach the photo and fill everything in manually.
      return;
    }

    setState(() => _ocrRunning = true);
    // Started with the scan, not after it (PM request, 2026-08-17).
    //
    // Waiting for the reading to finish meant the owner watched a spinner
    // and *then* an ad -- two waits back to back, when the ad could have
    // covered the first one. Every other screen already plays it over the
    // work for that reason.
    //
    // The cost of the change: a scan that then fails has still spent its
    // impression, which the previous order avoided. Retrying is still
    // free, and that is the part worth keeping -- rescanning a certificate
    // that did not read is the owner fixing our failure.
    final adFuture = _adAlreadyShown
        ? null
        : adGate?.maybeShow(AdTrigger.certificateCapture);
    if (adFuture != null) _adAlreadyShown = true;

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        throw StateError('Not signed in.');
      }
      final result = await ocrService.extractCertificateData(
        base64Image: base64Encode(compressed),
        mediaType: 'image/jpeg',
        idToken: idToken,
      );

      // Stored regardless of confidence (spec 5.4 step 5).
      _ocrExtractedData = result.extractedData;
      _ocrConfidence = result.confidence;

      final outcome = widget.ocrValidator.evaluate(result.confidence);
      // The confidence decides whether anything is prefilled at all, and
      // nothing on screen says what it was -- so a scan that reads fine to
      // a person but scores 0.55 looks like the feature is broken (PM:
      // 要確認マークが見られなかった, 2026-08-18). Logged so the threshold
      // can be tuned against what real certificates actually score, rather
      // than against the guess it was set from.
      developer.log(
        'OCR confidence=${result.confidence} -> ${outcome.name} '
        '(threshold ${OcrResultValidator.defaultConfidenceThreshold}); '
        'fields: administeredAt=${result.administeredAt != null} '
        'nextDueDate=${result.nextDueDate != null} '
        'hospitalName=${result.hospitalName != null} '
        'productName=${result.productName != null}',
        name: 'CertificateOcr',
      );
      if (outcome == OcrValidationOutcome.prefillForReview) {
        setState(() {
          _needsReview.clear();
          if (result.administeredAt != null) {
            _administeredAt = result.administeredAt!;
            _needsReview.add(_OcrField.administeredAt);
          }
          if (result.nextDueDate != null) {
            _nextDueDate = result.nextDueDate;
            _nextDueDateManuallyEdited = true;
            _needsReview.add(_OcrField.nextDueDate);
          }
          if (result.hospitalName != null) {
            _hospitalController.text = result.hospitalName!;
            _needsReview.add(_OcrField.hospitalName);
          }
          // The service has always extracted this; the form had nowhere to
          // put it until the vaccine-type / drug-name field existed, so it
          // was read off the certificate and thrown away (PM request).
          if (result.productName != null) {
            _productNameController.text = result.productName!;
            _needsReview.add(_OcrField.productName);
          }
          _ocrFallbackMessage = null;
        });
      } else {
        setState(() {
          _ocrFallbackMessage = l10n.ocrReadFailedMessage;
        });
      }
    } on CertificateOcrException catch (e) {
      // Distinguish the reasons the user can act on from the ones they
      // cannot. "Couldn't read it" and "you have used today's ten scans" ask
      // for completely different responses, and showing the same sentence
      // for both leaves someone retrying a limit that will not lift until
      // tomorrow -- the same problem the sign-in screen had.
      setState(() {
        _ocrFallbackMessage = switch (e.statusCode) {
          429 => l10n.ocrRateLimitedMessage,
          413 => l10n.ocrImageTooLargeMessage,
          _ => l10n.ocrReadFailedMessage,
        };
      });
    } catch (_) {
      setState(() {
        _ocrFallbackMessage = l10n.ocrReadFailedMessage;
      });
    } finally {
      if (mounted) setState(() => _ocrRunning = false);
    }

    // Awaited, not skipped: the ad was started above and has to be given
    // the chance to finish before the form is usable again.
    await adFuture;

  }

  String _title(AppLocalizations l10n) {
    final isVaccine = widget.program.type == PreventionType.vaccine;
    if (widget.record == null) {
      return isVaccine
          ? l10n.preventionRecordFormAddTitleVaccine
          : l10n.preventionRecordFormAddTitleMedication;
    }
    return isVaccine
        ? l10n.preventionRecordFormEditTitleVaccine
        : l10n.preventionRecordFormEditTitleMedication;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Read before the first await, like everything else taken from context.
    final savedMessage = AppLocalizations.of(context)!.commonSavedMessage;
    final saveFailedMessage =
        AppLocalizations.of(context)!.saveFailedRetryMessage;
    setState(() => _saving = true);
    try {
      final hospitalName = _hospitalController.text.trim().isEmpty
          ? null
          : _hospitalController.text.trim();
      final productName = _productNameController.text.trim().isEmpty
          ? null
          : _productNameController.text.trim();
      // A vaccine has no dose field on screen, so whatever a previous
      // medication edit left in the controller must not be written back.
      final dosage = (_isVaccine || _dosageController.text.trim().isEmpty)
          ? null
          : _dosageController.text.trim();

      final existing = widget.record;
      String? certificateUrl = _existingCertificateUrl;

      if (existing == null) {
        final created = await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          programId: widget.program.programId,
          administeredAt: _administeredAt,
          productName: productName,
          dosage: dosage,
          hospitalName: hospitalName,
          nextDueDate: _nextDueDate,
          reminderEnabled: _reminderEnabled,
          reminderTime: _reminderTime,
          reminderLeadDays: _reminderLeadDays.toList()..sort(),
          ocrExtractedData: _ocrExtractedData,
          ocrConfidence: _ocrConfidence,
        );
        // A new record has no id until create() returns, so the certificate
        // upload (keyed by record id) has to happen as a follow-up update.
        if (_pickedImageBytes != null) {
          final url = await widget.storageService.upload(
            uid: widget.uid,
            petId: widget.petId,
            recordId: created.recordId,
            bytes: _pickedImageBytes!,
            contentType: _pickedImageContentType ?? 'image/jpeg',
          );
          await widget.repository.update(
            widget.uid,
            created.copyWith(certificateFile: url),
          );
        }
      } else {
        if (_pickedImageBytes != null) {
          certificateUrl = await widget.storageService.upload(
            uid: widget.uid,
            petId: widget.petId,
            recordId: existing.recordId,
            bytes: _pickedImageBytes!,
            contentType: _pickedImageContentType ?? 'image/jpeg',
          );
        }
        await widget.repository.update(
          widget.uid,
          existing.copyWith(
            administeredAt: _administeredAt,
            productName: productName,
            dosage: dosage,
            hospitalName: hospitalName,
            nextDueDate: _nextDueDate,
            clearNextDueDate: _nextDueDate == null,
            reminderEnabled: _reminderEnabled,
            reminderTime: _reminderTime,
            reminderLeadDays: _reminderLeadDays.toList()..sort(),
            certificateFile: certificateUrl,
            ocrExtractedData: _ocrExtractedData,
            ocrConfidence: _ocrConfidence,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
      // Same reason as the daily-record forms: the screen is gone by the
      // time this is said, so it is said through the app-level messenger.
      showAppMessage(savedMessage);
    } catch (error, stackTrace) {
      // Stay put, with everything still filled in. Closing the form on a
      // failure would throw away what the owner typed and leave them to
      // enter it again from memory (PM request).
      developer.log(
        'Could not save the prevention record',
        name: 'PreventionRecordFormScreen',
        error: error,
        stackTrace: stackTrace,
      );
      showAppMessage(saveFailedMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  /// The lead times offered. Not free numeric entry: these are the ones
  /// that correspond to something real -- the day itself, the day before,
  /// a few days to notice, a week to book an appointment, two for a course
  /// that needs ordering in.
  static const List<int> _leadDayChoices = [0, 1, 3, 7, 14];

  int get _defaultLeadDays =>
      const ReminderScheduler().defaultLeadDaysFor(widget.program.type);

  String _leadDayLabel(AppLocalizations l10n, int days) => days == 0
      ? l10n.preventionReminderLeadSameDay
      : l10n.preventionReminderLeadDaysBefore(days);

  /// Fills the form from an earlier dose of this same programme, keeping
  /// today's date.
  ///
  /// Scoped to this programme rather than every prevention record: the
  /// thing being repeated is the annual booster or the monthly heartworm
  /// tablet, and the useful copy is always the last one of the same kind.
  /// The dates are left alone -- the next-due date is recalculated from
  /// today's, which is the entire reason the schedule exists.
  Future<void> _copyFromHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showHistoryCopyPicker<PreventionRecord>(
      context: context,
      options: widget.repository
          .watchRecordsForProgram(
            widget.uid,
            widget.petId,
            widget.program.programId,
          )
          .map(
            (records) => records
                .map(
                  (record) => HistoryCopyOption(
                    value: record,
                    title: record.productName ?? widget.program.productName,
                    subtitle: [
                      record.administeredAt
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first,
                      if (record.hospitalName != null) record.hospitalName!,
                    ].join(' - '),
                  ),
                )
                .toList(),
          ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _productNameController.text =
          chosen.productName ?? widget.program.productName;
      _dosageController.text = chosen.dosage ?? '';
      _hospitalController.text = chosen.hospitalName ?? '';
      // Copied values are the owner's own from last time, not a machine's
      // guess, so they carry no review marks.
      _needsReview.clear();
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.historyCopyAppliedMessage)),
    );
  }

  /// The mark itself, for fields whose value sits in a tile rather than an
  /// InputDecoration. Empty (not hidden behind a conditional at each call
  /// site) so the four uses read the same.
  Widget _reviewChip(AppLocalizations l10n, _OcrField field) {
    if (!_needsReview.contains(field)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 2),
          Text(
            l10n.ocrNeedsReviewLabel,
            style: _reviewHelperStyle(context),
          ),
        ],
      ),
    );
  }

  String? _reviewHelperText(AppLocalizations l10n, _OcrField field) =>
      _needsReview.contains(field) ? l10n.ocrNeedsReviewHelper : null;

  TextStyle? _reviewHelperStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.tertiary);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // See daily_record's health_record_form_screen.dart build() for why
    // this guard exists (PM report about photos not saving if you
    // navigate away mid-upload).
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
          // Vaccines are given, medicines are administered, and calling a
          // vaccination a dose of medicine reads as the wrong screen (PM
          // report). The programme already knows which this is.
          title: Text(_title(l10n)),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // New records only -- on an existing one this would overwrite
              // what is being edited.
              if (widget.record == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _copyFromHistory,
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: Text(l10n.historyCopyButtonLabel),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.administeredAtLabel),
                subtitle: Row(
                  children: [
                    Text(
                      _administeredAt.toLocal().toString().split(' ').first,
                    ),
                    _reviewChip(l10n, _OcrField.administeredAt),
                  ],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(
                  initial: _administeredAt,
                  onPicked: (d) {
                    setState(() => _administeredAt = d);
                    _needsReview.remove(_OcrField.administeredAt);
                    _recalculateNextDueDateIfNotManuallyEdited();
                  },
                ),
              ),
              // A vaccination records which vaccine; a medication records
              // which drug and how much of it. Both name the substance, so
              // one controller carries both and only the label and the
              // company it keeps change (PM request).
              TextFormField(
                controller: _productNameController,
                onChanged: (_) => _clearReview(_OcrField.productName),
                decoration: InputDecoration(
                  labelText: _isVaccine
                      ? l10n.preventionVaccineTypeLabel
                      : l10n.medicationNameLabel,
                  helperText: _reviewHelperText(l10n, _OcrField.productName),
                  helperStyle: _reviewHelperStyle(context),
                ),
              ),
              // Dose is a medication idea. A vaccine is one shot of whatever
              // the vet drew up, and asking "how much" invites a guess.
              if (!_isVaccine)
                TextFormField(
                  controller: _dosageController,
                  decoration: InputDecoration(
                    labelText: l10n.medicationDosageLabel,
                  ),
                ),
              TextFormField(
                controller: _hospitalController,
                onChanged: (_) => _clearReview(_OcrField.hospitalName),
                decoration: InputDecoration(
                  labelText: l10n.hospitalNameOptionalLabel,
                  helperText: _reviewHelperText(l10n, _OcrField.hospitalName),
                  helperStyle: _reviewHelperStyle(context),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reminderEnabled,
                onChanged: (value) =>
                    setState(() => _reminderEnabled = value),
                title: Text(l10n.medicationReminderSwitchLabel),
              ),
              if (_reminderEnabled) ...[
                Text(
                  l10n.preventionReminderLeadLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: _leadDayChoices.map((days) {
                    final selected = _reminderLeadDays.isEmpty
                        ? days == _defaultLeadDays
                        : _reminderLeadDays.contains(days);
                    return FilterChip(
                      label: Text(_leadDayLabel(l10n, days)),
                      selected: selected,
                      onSelected: (isOn) => setState(() {
                        // The first touch turns the implicit default into
                        // an explicit choice, so unticking it means "not
                        // that one" rather than "back to the default".
                        if (_reminderLeadDays.isEmpty) {
                          _reminderLeadDays = {_defaultLeadDays};
                        }
                        if (isOn) {
                          _reminderLeadDays.add(days);
                        } else {
                          _reminderLeadDays.remove(days);
                        }
                        // Nothing selected would mean "remind me, but
                        // never" -- fall back rather than store a silent
                        // no-op.
                        if (_reminderLeadDays.isEmpty) {
                          _reminderLeadDays = {_defaultLeadDays};
                        }
                      }),
                    );
                  }).toList(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.medicationReminderTimeLabel),
                  subtitle: Text(
                    TimeOfDay(
                      hour: _reminderTime.hour,
                      minute: _reminderTime.minute,
                    ).format(context),
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _reminderTime.hour,
                        minute: _reminderTime.minute,
                      ),
                    );
                    if (picked == null) return;
                    setState(
                      () => _reminderTime = ReminderTime(
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  },
                ),
                // The rules are not guessable from the controls, and both
                // halves have surprised the PM: the notification arrives
                // *before* the due date, and the due date only moves when
                // the next dose is recorded (PM asked, 2026-08-18).
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.preventionReminderExplanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.nextDueDateLabel),
                subtitle: Row(
                  children: [
                    Text(
                      _nextDueDate == null
                          ? l10n.notSetLabel
                          : _nextDueDate!.toLocal().toString().split(' ').first,
                    ),
                    _reviewChip(l10n, _OcrField.nextDueDate),
                  ],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(
                  initial: _nextDueDate,
                  onPicked: (d) {
                    setState(() {
                      _nextDueDate = d;
                      _nextDueDateManuallyEdited = true;
                      _needsReview.remove(_OcrField.nextDueDate);
                    });
                  },
                ),
              ),
              const Divider(height: 32),
              Text(
                l10n.certificateImageSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_pickedImageBytes != null)
                Image.memory(_pickedImageBytes!, height: 160)
              else if (_existingCertificateUrl != null)
                // PM report: an already-saved certificate was described in
                // words but never actually drawn, so there was no way to
                // check the registered image from this screen -- the whole
                // point of spec 5.3's "証明書を即座に確認できるようにする".
                // A newly picked image was rendered (above), which made the
                // gap easy to miss during development.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.certificateAlreadyRegisteredMessage),
                    const SizedBox(height: 8),
                    Image.network(
                      _existingCertificateUrl!,
                      height: 160,
                      errorBuilder: (context, error, stackTrace) =>
                          Text(l10n.certificateImageLoadFailedMessage),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : SizedBox(
                              height: 160,
                              child: WanoteLoadingIndicator.centered(),
                            ),
                    ),
                  ],
                )
              else
                Text(l10n.certificateNotRegisteredMessage),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _ocrRunning ? null : _pickAndAnalyzeCertificate,
                icon: _ocrRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(
                  widget.ocrService == null
                      ? l10n.certificateCaptureManualLabel
                      : l10n.certificateCaptureAiLabel,
                ),
              ),
              if (_ocrFallbackMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _ocrFallbackMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_ocrConfidence != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.ocrConfidenceLabel(
                      (_ocrConfidence! * 100).toStringAsFixed(0),
                    ),
                    // Red (PM request): this asks the user to double-check
                    // AI-extracted values before saving them as medical
                    // history, so it must not read as a passive stat.
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.saveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The fields the certificate OCR can fill in, for tracking which of them
/// still hold a machine's guess.
enum _OcrField { administeredAt, nextDueDate, hospitalName, productName }
