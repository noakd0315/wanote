import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/medication_repository.dart';
import '../../domain/models/medication.dart';
import '../widgets/history_copy_picker.dart';

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

  /// Every time of day this medicine is due, in order.
  ///
  /// A list because a course is often more than once a day -- morning and
  /// evening, or with each meal (PM request). A single time could only ever
  /// describe a once-daily medicine.
  List<ReminderTime> _reminderTimes = const [ReminderTime(8, 0)];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    _nameController.text = medication?.name ?? '';
    _dosageController.text = medication?.dosage ?? '';
    _startDate = medication?.startDate ?? DateTime.now();
    _endDate = medication?.endDate;
    _ongoing = medication == null ? true : medication.hasNoEndDate;
    _reminderEnabled = medication?.reminderEnabled ?? false;
    if (medication != null && medication.reminderTimes.isNotEmpty) {
      _reminderTimes = List.of(medication.reminderTimes);
    }
  }

  /// Fills the form from an earlier course of medication, keeping today's
  /// start date.
  ///
  /// A repeat prescription is the same name and the same dose, starting
  /// now. Copying the old start date would date this course to whenever the
  /// last one began; copying the end date would end it before it starts.
  Future<void> _copyFromHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showHistoryCopyPicker<Medication>(
      context: context,
      options: widget.repository
          .watchMedications(widget.uid, widget.petId)
          .map(
            (medications) => medications
                .map(
                  (medication) => HistoryCopyOption(
                    value: medication,
                    title: medication.name,
                    subtitle: [
                      medication.startDate
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first,
                      if (medication.dosage != null) medication.dosage!,
                    ].join(' - '),
                  ),
                )
                .toList(),
          ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _nameController.text = chosen.name;
      _dosageController.text = chosen.dosage ?? '';
      _reminderEnabled = chosen.reminderEnabled;
      if (chosen.reminderTimes.isNotEmpty) {
        _reminderTimes = List.of(chosen.reminderTimes);
      }
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.historyCopyAppliedMessage)),
    );
  }

  /// Adds a time, or replaces one when [replacing] is given.
  ///
  /// Duplicates are dropped rather than refused: two reminders at the same
  /// minute would fire as one anyway, since the time is part of the
  /// notification id.
  Future<void> _pickTime({ReminderTime? replacing}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: replacing == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: replacing.hour, minute: replacing.minute),
    );
    if (picked == null) return;
    final added = ReminderTime(picked.hour, picked.minute);
    setState(() {
      final next = <ReminderTime>[
        for (final time in _reminderTimes)
          if (time != replacing) time,
      ];
      if (!next.contains(added)) next.add(added);
      _reminderTimes = next..sort();
    });
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
      final reminderTimes = _reminderEnabled
          ? (List.of(_reminderTimes)..sort())
          : const <ReminderTime>[];

      if (existing == null) {
        await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          name: _nameController.text.trim(),
          dosage: dosage,
          startDate: _startDate,
          endDate: endDate,
          reminderEnabled: _reminderEnabled,
          reminderTimes: reminderTimes,
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
            reminderTimes: reminderTimes,
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
            // New records only -- on an existing one this would overwrite
            // what is being edited.
            if (widget.medication == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _copyFromHistory,
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: Text(l10n.historyCopyButtonLabel),
                ),
              ),
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
            if (_reminderEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.medicationReminderTimeLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final time in _reminderTimes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    TimeOfDay(
                      hour: time.hour,
                      minute: time.minute,
                    ).format(context),
                  ),
                  leading: const Icon(Icons.access_time),
                  // The last one cannot be removed while reminders are on:
                  // a reminder with no time would never fire, and nothing on
                  // screen would say why.
                  trailing: _reminderTimes.length > 1
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(
                            () => _reminderTimes = [
                              for (final other in _reminderTimes)
                                if (other != time) other,
                            ],
                          ),
                        )
                      : null,
                  onTap: () => _pickTime(replacing: time),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pickTime(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.medicationAddReminderTimeButton),
                ),
              ),
            ],
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
