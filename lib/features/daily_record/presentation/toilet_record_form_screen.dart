import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/image_source_sheet.dart';
import '../data/toilet_record_repository.dart';
import '../models/toilet_record.dart';

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
  });

  final String uid;
  final String petId;
  final ToiletRecordRepository repository;

  @override
  State<ToiletRecordFormScreen> createState() => _ToiletRecordFormScreenState();
}

class _ToiletRecordFormScreenState extends State<ToiletRecordFormScreen> {
  StoolHardness _hardness = StoolHardness.normal;
  StoolColor _color = StoolColor.normal;
  Uint8List? _photoBytes;
  bool _saving = false;

  // PM request: 排便の記録も日時が欲しい -- defaults to now like the urine
  // one-tap dialog, but editable for logging something noticed after the
  // fact.
  DateTime _recordedAt = DateTime.now();

  // PM request: 排尿、排便とも任意項目で場所の入力欄が欲しい.
  final _locationController = TextEditingController();

  final _imagePicker = ImagePicker();

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
    final file = await _imagePicker.pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final location = _locationController.text.trim();
      await widget.repository.create(
        uid: widget.uid,
        petId: widget.petId,
        type: ToiletType.stool,
        stoolCondition: StoolCondition(hardness: _hardness, color: _color),
        photoBytes: _photoBytes,
        recordedAt: _recordedAt,
        location: location.isEmpty ? null : location,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // See health_record_form_screen.dart's build() for why this guard
    // exists (PM report about photos not saving if you navigate away
    // mid-upload).
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存中です。しばらくお待ちください')));
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('排便を記録')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日付'),
              subtitle: Text(DateFormat('yyyy/MM/dd').format(_recordedAt)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('時刻'),
              subtitle: Text(DateFormat('HH:mm').format(_recordedAt)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            const Text('硬さ', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: StoolHardness.values.map((h) {
                return ChoiceChip(
                  label: Text(h.wireName),
                  selected: _hardness == h,
                  onSelected: (_) => setState(() => _hardness = h),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('色', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: StoolColor.values.map((c) {
                return ChoiceChip(
                  label: Text(c.wireName),
                  selected: _color == c,
                  onSelected: (_) => setState(() => _color = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: '場所（任意）'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_photoBytes == null ? '写真を追加（任意）' : '写真を変更'),
            ),
            if (_photoBytes != null)
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
