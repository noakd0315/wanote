import 'package:flutter/material.dart';

import '../../data/prevention_program_repository.dart';
import '../../domain/models/prevention_program.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program == null ? '予防プログラムを追加' : '予防プログラムを編集'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<PreventionType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '種別'),
              items: const [
                DropdownMenuItem(
                  value: PreventionType.vaccine,
                  child: Text('ワクチン'),
                ),
                DropdownMenuItem(
                  value: PreventionType.heartworm,
                  child: Text('フィラリア予防'),
                ),
                DropdownMenuItem(
                  value: PreventionType.fleaTick,
                  child: Text('ノミ・ダニ予防'),
                ),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            TextFormField(
              controller: _productNameController,
              decoration: const InputDecoration(labelText: 'ワクチン名／予防薬名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必須項目です' : null,
            ),
            DropdownButtonFormField<ScheduleType>(
              initialValue: _scheduleType,
              decoration: const InputDecoration(labelText: '頻度'),
              items: const [
                DropdownMenuItem(
                  value: ScheduleType.single,
                  child: Text('単発（都度登録）'),
                ),
                DropdownMenuItem(
                  value: ScheduleType.monthly,
                  child: Text('毎月'),
                ),
                DropdownMenuItem(
                  value: ScheduleType.annual,
                  child: Text('毎年'),
                ),
                DropdownMenuItem(
                  value: ScheduleType.custom,
                  child: Text('カスタム間隔'),
                ),
              ],
              onChanged: (v) => setState(() => _scheduleType = v!),
            ),
            if (_scheduleType == ScheduleType.custom)
              TextFormField(
                controller: _intervalDaysController,
                decoration: const InputDecoration(labelText: '間隔（日数）'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_scheduleType != ScheduleType.custom) return null;
                  if (v == null || v.trim().isEmpty) return '必須項目です';
                  if (int.tryParse(v.trim()) == null) return '数値を入力してください';
                  return null;
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開始日'),
              subtitle: Text(_startDate.toLocal().toString().split(' ').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('有効'),
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
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
