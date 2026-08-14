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

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _administeredAt = record?.administeredAt ?? DateTime.now();
    _nextDueDate = record?.nextDueDate;
    _nextDueDateManuallyEdited = _nextDueDate != null;
    _hospitalController.text = record?.hospitalName ?? '';
    _existingCertificateUrl = record?.certificateFile;
    _ocrExtractedData = record?.ocrExtractedData;
    _ocrConfidence = record?.ocrConfidence;
  }

  @override
  void dispose() {
    _hospitalController.dispose();
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
      if (outcome == OcrValidationOutcome.prefillForReview) {
        setState(() {
          if (result.administeredAt != null) {
            _administeredAt = result.administeredAt!;
          }
          if (result.nextDueDate != null) {
            _nextDueDate = result.nextDueDate;
            _nextDueDateManuallyEdited = true;
          }
          if (result.hospitalName != null) {
            _hospitalController.text = result.hospitalName!;
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

    // One ad for the capture and the reading together: to the owner that was
    // a single action (PLAN_ads decision 3). After the OCR, not before --
    // an ad in front of a scan that then failed would have taken their
    // attention for nothing.
    //
    // Not exempted by an AI ticket balance: the scan does not consume one
    // (tickets are sold as AI相談チケット and the OCR route is bounded
    // server-side instead) -- PM decision, 2026-08-12.
    await adGate?.maybeShow(AdTrigger.certificateCapture);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final hospitalName = _hospitalController.text.trim().isEmpty
          ? null
          : _hospitalController.text.trim();

      final existing = widget.record;
      String? certificateUrl = _existingCertificateUrl;

      if (existing == null) {
        final created = await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          programId: widget.program.programId,
          administeredAt: _administeredAt,
          hospitalName: hospitalName,
          nextDueDate: _nextDueDate,
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
            hospitalName: hospitalName,
            nextDueDate: _nextDueDate,
            clearNextDueDate: _nextDueDate == null,
            certificateFile: certificateUrl,
            ocrExtractedData: _ocrExtractedData,
            ocrConfidence: _ocrConfidence,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
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
          title: Text(
            widget.record == null
                ? l10n.preventionRecordFormAddTitle
                : l10n.preventionRecordFormEditTitle,
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.administeredAtLabel),
                subtitle: Text(
                  _administeredAt.toLocal().toString().split(' ').first,
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(
                  initial: _administeredAt,
                  onPicked: (d) {
                    setState(() => _administeredAt = d);
                    _recalculateNextDueDateIfNotManuallyEdited();
                  },
                ),
              ),
              TextFormField(
                controller: _hospitalController,
                decoration: InputDecoration(
                  labelText: l10n.hospitalNameOptionalLabel,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.nextDueDateLabel),
                subtitle: Text(
                  _nextDueDate == null
                      ? l10n.notSetLabel
                      : _nextDueDate!.toLocal().toString().split(' ').first,
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(
                  initial: _nextDueDate,
                  onPicked: (d) {
                    setState(() {
                      _nextDueDate = d;
                      _nextDueDateManuallyEdited = true;
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
                          : const SizedBox(
                              height: 160,
                              child: Center(child: CircularProgressIndicator()),
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
