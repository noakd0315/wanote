import 'package:flutter/material.dart';

import '../../data/visit_repository.dart';
import '../../domain/models/visit.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.visit == null ? '通院記録を追加' : '通院記録を編集'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('通院日'),
              subtitle: Text(_visitedAt.toLocal().toString().split(' ').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _visitedAt,
                onPicked: (d) => setState(() => _visitedAt = d),
              ),
            ),
            TextFormField(
              controller: _hospitalController,
              decoration: const InputDecoration(labelText: '動物病院名'),
            ),
            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(labelText: '診断内容'),
              maxLines: 3,
            ),
            TextFormField(
              controller: _costController,
              decoration: const InputDecoration(labelText: '費用（円）'),
              keyboardType: TextInputType.number,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('次回通院予定日'),
              subtitle: Text(
                _nextVisitDate == null
                    ? '未設定'
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
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
