import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/prevention_program_repository.dart';
import '../../domain/models/prevention_program.dart';
import '../prevention_type_label.dart';

/// Create/edit screen for a `prevention_programs` entry (spec 5.3).
class PreventionProgramFormScreen extends StatefulWidget {
  const PreventionProgramFormScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.program,
  });

  final String uid;
  final String petId;
  final PreventionProgramRepository repository;
  final PreventionProgram? program;

  @override
  State<PreventionProgramFormScreen> createState() =>
      _PreventionProgramFormScreenState();
}

class _PreventionProgramFormScreenState
    extends State<PreventionProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  PreventionType _type = PreventionType.vaccine;
  ScheduleType _scheduleType = ScheduleType.single;
  late DateTime _startDate;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final program = widget.program;
    _productNameController.text = program?.productName ?? '';
    _intervalDaysController.text = program?.intervalDays?.toString() ?? '';
    _type = program?.type ?? PreventionType.vaccine;
    _scheduleType = program?.scheduleType ?? ScheduleType.single;
    _startDate = program?.startDate ?? DateTime.now();
    _active = program?.active ?? true;
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _intervalDaysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final intervalDays = _scheduleType == ScheduleType.custom
          ? int.parse(_intervalDaysController.text.trim())
          : null;
      final existing = widget.program;
      if (existing == null) {
        await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          type: _type,
          productName: _productNameController.text.trim(),
          scheduleType: _scheduleType,
          startDate: _startDate,
          active: _active,
          intervalDays: intervalDays,
        );
      } else {
        await widget.repository.update(
          widget.uid,
          existing.copyWith(
            type: _type,
            productName: _productNameController.text.trim(),
            scheduleType: _scheduleType,
            startDate: _startDate,
            active: _active,
            intervalDays: intervalDays,
            clearIntervalDays: intervalDays == null,
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
          widget.program == null
              ? l10n.preventionProgramFormAddTitle
              : l10n.preventionProgramFormEditTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<PreventionType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.preventionTypeFieldLabel,
              ),
              items: [
                DropdownMenuItem(
                  value: PreventionType.vaccine,
                  child: Text(
                    preventionTypeLabel(l10n, PreventionType.vaccine),
                  ),
                ),
                DropdownMenuItem(
                  value: PreventionType.medication,
                  child: Text(
                    preventionTypeLabel(l10n, PreventionType.medication),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            TextFormField(
              controller: _productNameController,
              decoration: InputDecoration(
                labelText: l10n.preventionProductNameLabel,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.requiredFieldValidationError
                  : null,
            ),
            DropdownButtonFormField<ScheduleType>(
              initialValue: _scheduleType,
              decoration: InputDecoration(
                labelText: l10n.scheduleTypeFieldLabel,
              ),
              items: [
                DropdownMenuItem(
                  value: ScheduleType.single,
                  child: Text(l10n.scheduleTypeSingleOption),
                ),
                DropdownMenuItem(
                  value: ScheduleType.monthly,
                  child: Text(l10n.scheduleTypeMonthly),
                ),
                DropdownMenuItem(
                  value: ScheduleType.annual,
                  child: Text(l10n.scheduleTypeAnnual),
                ),
                DropdownMenuItem(
                  value: ScheduleType.custom,
                  child: Text(l10n.scheduleTypeCustomOption),
                ),
              ],
              onChanged: (v) => setState(() => _scheduleType = v!),
            ),
            if (_scheduleType == ScheduleType.custom)
              TextFormField(
                controller: _intervalDaysController,
                decoration: InputDecoration(labelText: l10n.intervalDaysLabel),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_scheduleType != ScheduleType.custom) return null;
                  if (v == null || v.trim().isEmpty) {
                    return l10n.requiredFieldValidationError;
                  }
                  if (int.tryParse(v.trim()) == null) {
                    return l10n.numericValueValidationError;
                  }
                  return null;
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.preventionProgramActiveSwitchLabel),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
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
