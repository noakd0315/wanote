import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/visit_repository.dart';
import '../../domain/models/visit.dart';
import '../widgets/history_copy_picker.dart';

/// Create/edit screen for spec 5.1 (通院履歴). Pass [visit] to edit an
/// existing entry, or omit it to create a new one.
class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.visit,
  });

  final String uid;
  final String petId;
  final VisitRepository repository;
  final Visit? visit;

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _visitedAt;
  DateTime? _nextVisitDate;
  final _hospitalController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _costController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final visit = widget.visit;
    _visitedAt = visit?.visitedAt ?? DateTime.now();
    _nextVisitDate = visit?.nextVisitDate;
    _hospitalController.text = visit?.hospitalName ?? '';
    _diagnosisController.text = visit?.diagnosis ?? '';
    _costController.text = visit?.cost?.toString() ?? '';
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _diagnosisController.dispose();
    _costController.dispose();
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
      final cost = _costController.text.trim().isEmpty
          ? null
          : int.tryParse(_costController.text.trim());
      final hospitalName = _hospitalController.text.trim().isEmpty
          ? null
          : _hospitalController.text.trim();
      final diagnosis = _diagnosisController.text.trim().isEmpty
          ? null
          : _diagnosisController.text.trim();

      final existing = widget.visit;
      if (existing == null) {
        await widget.repository.create(
          uid: widget.uid,
          petId: widget.petId,
          visitedAt: _visitedAt,
          hospitalName: hospitalName,
          diagnosis: diagnosis,
          cost: cost,
          nextVisitDate: _nextVisitDate,
        );
      } else {
        await widget.repository.update(
          widget.uid,
          existing.copyWith(
            visitedAt: _visitedAt,
            hospitalName: hospitalName,
            diagnosis: diagnosis,
            cost: cost,
            nextVisitDate: _nextVisitDate,
            clearHospitalName: hospitalName == null,
            clearDiagnosis: diagnosis == null,
            clearCost: cost == null,
            clearNextVisitDate: _nextVisitDate == null,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Fills the form from an earlier visit, keeping today's date.
  ///
  /// The same clinic and the same diagnosis come round again -- a recheck,
  /// a repeat of a chronic problem. Only [Visit.visitedAt] and
  /// [Visit.nextVisitDate] are left alone: copying those would record this
  /// visit as having happened when the old one did.
  Future<void> _copyFromHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showHistoryCopyPicker<Visit>(
      context: context,
      options: widget.repository.watchVisits(widget.uid, widget.petId).map(
        (visits) => visits
            .map(
              (visit) => HistoryCopyOption(
                value: visit,
                title: visit.hospitalName ?? l10n.visitFallbackTitle,
                subtitle: [
                  visit.visitedAt.toLocal().toString().split(' ').first,
                  if (visit.diagnosis != null) visit.diagnosis!,
                ].join(' - '),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _hospitalController.text = chosen.hospitalName ?? '';
      _diagnosisController.text = chosen.diagnosis ?? '';
      _costController.text = chosen.cost?.toString() ?? '';
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.historyCopyAppliedMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.visit == null
              ? l10n.visitFormAddTitle
              : l10n.visitFormEditTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // New records only. On an existing one this would overwrite
            // what is being edited, which is not what "copy" means here.
            if (widget.visit == null)
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
              title: Text(l10n.visitedAtLabel),
              subtitle: Text(_visitedAt.toLocal().toString().split(' ').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _visitedAt,
                onPicked: (d) => setState(() => _visitedAt = d),
              ),
            ),
            TextFormField(
              controller: _hospitalController,
              decoration: InputDecoration(labelText: l10n.hospitalNameLabel),
            ),
            TextFormField(
              controller: _diagnosisController,
              decoration: InputDecoration(labelText: l10n.diagnosisLabel),
              maxLines: 3,
            ),
            TextFormField(
              controller: _costController,
              decoration: InputDecoration(labelText: l10n.visitCostLabel),
              keyboardType: TextInputType.number,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.nextVisitDateLabel),
              subtitle: Text(
                _nextVisitDate == null
                    ? l10n.notSetLabel
                    : _nextVisitDate!.toLocal().toString().split(' ').first,
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _nextVisitDate,
                onPicked: (d) => setState(() => _nextVisitDate = d),
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
    );
  }
}
