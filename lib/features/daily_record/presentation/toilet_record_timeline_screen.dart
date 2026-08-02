import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/consultation_reference_record.dart';
import '../data/toilet_record_repository.dart';
import '../domain/anomaly_detector.dart';
import '../models/toilet_record.dart';
import 'toilet_frequency_chart_screen.dart';
import 'toilet_record_form_screen.dart';

/// Spec 4.2's one-tap timeline, plus the anomaly-driven AI-consultation
/// banner from spec 4.4.
///
/// [onConsultationSuggested] is a hook point only: this feature must not
/// import/depend on features/ai/'s screens directly (see AnomalyDetector's
/// doc comment for why). Wire it up to actual navigation to the AI
/// consultation screen at the app-shell level, passing the
/// [ConsultationSuggestion.reference] through as prefill context.
class ToiletRecordTimelineScreen extends StatefulWidget {
  const ToiletRecordTimelineScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.repository,
    this.anomalyDetector = const AnomalyDetector(),
    this.onConsultationSuggested,
  });

  final String uid;
  final String petId;
  final ToiletRecordRepository repository;
  final AnomalyDetector anomalyDetector;
  final void Function(ConsultationSuggestion suggestion)? onConsultationSuggested;

  @override
  State<ToiletRecordTimelineScreen> createState() => _ToiletRecordTimelineScreenState();
}

class _ToiletRecordTimelineScreenState extends State<ToiletRecordTimelineScreen> {
  /// Per-reason "last shown" timestamps, for AnomalyDetector's dedupe-by-day
  /// input. Held in memory here for simplicity; a production build should
  /// persist this (e.g. shared_preferences or a small Firestore doc) so the
  /// suppression survives app restarts. See AnomalyDetector.detect's doc.
  final Map<ConsultationSuggestionReason, DateTime> _lastSuggestedAt = {};

  Future<void> _recordUrine() async {
    final recordedAt = await showDialog<DateTime>(
      context: context,
      builder: (_) => const _RecordedAtDialog(),
    );
    if (recordedAt == null) return;
    await widget.repository.create(
      uid: widget.uid,
      petId: widget.petId,
      type: ToiletType.urine,
      recordedAt: recordedAt,
    );
  }

  void _handleSuggestions(List<ToiletRecord> records) {
    final now = DateTime.now();
    final suggestions = widget.anomalyDetector.detect(
      records: records,
      now: now,
      lastSuggestedAt: _lastSuggestedAt,
    );
    if (suggestions.isEmpty) return;
    for (final suggestion in suggestions) {
      _lastSuggestedAt[suggestion.reason] = now;
      widget.onConsultationSuggested?.call(suggestion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トイレ記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ToiletFrequencyChartScreen(
                    uid: widget.uid,
                    petId: widget.petId,
                    repository: widget.repository,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ToiletRecord>>(
        stream: widget.repository.watchTimeline(widget.uid, widget.petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <ToiletRecord>[];
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleSuggestions(records));

          final now = DateTime.now();
          final currentSuggestions = widget.anomalyDetector.detect(
            records: records,
            now: now,
            lastSuggestedAt: const {},
          );

          return Column(
            children: [
              if (currentSuggestions.isNotEmpty)
                MaterialBanner(
                  content: Text(currentSuggestions.first.message),
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  actions: [
                    TextButton(
                      onPressed: () => widget.onConsultationSuggested?.call(currentSuggestions.first),
                      child: const Text('AI相談する'),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _recordUrine,
                        icon: const Icon(Icons.water_drop),
                        label: const Text('排尿'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ToiletRecordFormScreen(
                                uid: widget.uid,
                                petId: widget.petId,
                                repository: widget.repository,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.circle),
                        label: const Text('排便'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('記録がまだありません'))
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final isUrine = record.type == ToiletType.urine;
                          return ListTile(
                            leading: Icon(isUrine ? Icons.water_drop : Icons.circle),
                            title: Text(DateFormat('yyyy/MM/dd HH:mm').format(record.recordedAt)),
                            subtitle: isUrine
                                ? null
                                : Text(
                                    '硬さ: ${record.stoolCondition?.hardness.wireName ?? '-'} / 色: ${record.stoolCondition?.color.wireName ?? '-'}',
                                  ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => widget.repository.delete(uid: widget.uid, record: record),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Confirms the timestamp for a one-tap record before saving it. Defaults to
/// "now" so a plain tap-through reproduces the original one-tap behavior
/// (spec 4.2's "記録時刻は自動入力"); the date/time fields are editable for
/// logging something that happened a little earlier.
class _RecordedAtDialog extends StatefulWidget {
  const _RecordedAtDialog();

  @override
  State<_RecordedAtDialog> createState() => _RecordedAtDialogState();
}

class _RecordedAtDialogState extends State<_RecordedAtDialog> {
  late DateTime _recordedAt = DateTime.now();

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('排尿を記録'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_recordedAt),
          child: const Text('記録する'),
        ),
      ],
    );
  }
}
