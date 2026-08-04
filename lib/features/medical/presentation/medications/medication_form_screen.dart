import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/medication_repository.dart';
import '../../domain/models/medication.dart';

/// Create/edit screen for spec 5.2 (薬の記録).
class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.medication,
  });

  final String uid;
  final String petId;
  final MedicationRepository repository;
  final Medication? medication;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  late DateTime _startDate;
  DateTime? _endDate;
  bool _ongoing = true;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    _nameController.text = medication?.name ?? '';
    _dosageController.text = medication?.dosage ?? '';
    _startDate = medication?.startDate ?? DateTime.now();
    _endDate = medication?.endDate;
    _ongoing = medication == null ? true : medication.isOngoing;
    _reminderEnabled = medication?.reminderEnabled ?? false;
    if (medication?.reminderHour != null &&
        medication?.reminderMinute != null) {
      _reminderTime = TimeOfDay(
        hour: medication!.reminderHour!,
        minute: medication.reminderMinute!,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final existing = widget.medication;
      final dosage = _dosageController.text.trim().isEmpty
          ? null
          : _dosageController.text.trim();
      final endDate = _ongoing ? null : _endDate;
      final reminderHour = _reminderEnabled ? _reminderTime.hour : null;
      final reminderMinute = _reminderEnabled ? _reminderTime.minute : null;

      if (existing == null) {
        await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          name: _nameController.text.trim(),
          dosage: dosage,
          startDate: _startDate,
          endDate: endDate,
          reminderEnabled: _reminderEnabled,
          reminderHour: reminderHour,
          reminderMinute: reminderMinute,
        );
      } else {
        await widget.repository.update(
          widget.uid,
          existing.copyWith(
            name: _nameController.text.trim(),
            dosage: dosage,
            startDate: _startDate,
            endDate: endDate,
            clearEndDate: endDate == null,
            reminderEnabled: _reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.medication == null
              ? l10n.medicationFormAddTitle
              : l10n.medicationFormEditTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.medicationNameLabel),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.requiredFieldValidationError
                  : null,
            ),
            TextFormField(
              controller: _dosageController,
              decoration: InputDecoration(
                labelText: l10n.medicationDosageLabel,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.medicationStartDateLabel),
              subtitle: Text(_startDate.toLocal().toString().split(' ').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _startDate,
                onPicked: (d) => setState(() => _startDate = d),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.medicationOngoingSwitchLabel),
              value: _ongoing,
              onChanged: (v) => setState(() => _ongoing = v),
            ),
            if (!_ongoing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.medicationEndDateLabel),
                subtitle: Text(
                  _endDate == null
                      ? l10n.notSetLabel
                      : _endDate!.toLocal().toString().split(' ').first,
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(
                  initial: _endDate,
                  onPicked: (d) => setState(() => _endDate = d),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.medicationReminderSwitchLabel),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
            if (_reminderEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.medicationReminderTimeLabel),
                subtitle: Text(_reminderTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime,
                  );
                  if (picked != null) setState(() => _reminderTime = picked);
                },
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
    );
  }
}
