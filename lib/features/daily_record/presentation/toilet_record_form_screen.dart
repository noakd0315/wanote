import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/toilet_record_repository.dart';
import '../models/toilet_record.dart';

/// Spec 4.2: "便の状態選択（硬さ：正常／軟便／下痢／硬い、色：正常／血便疑い
/// ／白っぽい 等）" plus optional photo attachment for abnormal findings.
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

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.create(
        uid: widget.uid,
        petId: widget.petId,
        type: ToiletType.stool,
        stoolCondition: StoolCondition(hardness: _hardness, color: _color),
        photoBytes: _photoBytes,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('排便を記録')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
    );
  }
}
