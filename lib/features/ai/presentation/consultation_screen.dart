import 'package:flutter/material.dart';

import '../../../shared/models/consultation_reference_record.dart';
import '../../../shared/services/ai_usage_repository.dart';
import '../data/ai_backend_client.dart';
import '../data/consultation_repository.dart';
import '../domain/emergency_keyword_detector.dart';
import '../domain/usage_limit_policy.dart';
import '../models/consultation.dart';
import 'widgets/disclaimer_banner.dart';
import 'widgets/emergency_notice.dart';
import 'widgets/upgrade_prompt_card.dart';

enum _ResultKind { none, emergency, response, needsUpgrade, error }

/// AI consultation screen (spec 6.2): symptom text input with optional
/// chip-prefill from daily_record context, emergency short-circuit, usage
/// gating, backend call, and a Firestore-backed history list.
///
/// Ownership boundaries: this widget accepts a `List<ConsultationReferenceRecord>?`
/// prefill from whatever screen navigated here (e.g. Agent B's daily_record
/// "consult about this record" action) but never imports
/// lib/features/daily_record/ itself. Likewise, [onRequestUpgrade] is the
/// hook Agent E's billing screen plugs into; features/ai never imports
/// lib/features/billing/.
class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.usageRepository,
    required this.backendClient,
    required this.consultationRepository,
    required this.onRequestUpgrade,
    this.prefillRecords,
    this.emergencyDetector = const EmergencyKeywordDetector(),
    this.usageLimitPolicy = const UsageLimitPolicy(),
  });

  final String uid;
  final String petId;
  final AiUsageRepository usageRepository;
  final AiBackendClient backendClient;
  final ConsultationRepository consultationRepository;

  /// Optional context passed in from another feature (e.g. "この記録につい
  /// て相談する" from a daily_record entry). May be null or empty.
  final List<ConsultationReferenceRecord>? prefillRecords;

  /// Stub navigation hook for Agent E's ticket-purchase / subscription
  /// upgrade UI.
  final VoidCallback onRequestUpgrade;

  final EmergencyKeywordDetector emergencyDetector;
  final UsageLimitPolicy usageLimitPolicy;

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _controller = TextEditingController();
  final Set<ConsultationReferenceRecord> _selectedReferences = {};

  bool _submitting = false;
  _ResultKind _resultKind = _ResultKind.none;
  String? _resultText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final questionText = _controller.text.trim();
    if (questionText.isEmpty || _submitting) return;

    // Requirement: emergency detection runs and short-circuits BEFORE any
    // backend/AI call is made.
    if (widget.emergencyDetector.isEmergency(questionText)) {
      setState(() {
        _resultKind = _ResultKind.emergency;
        _resultText = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _resultKind = _ResultKind.none;
      _resultText = null;
    });

    try {
      final decision = await widget.usageLimitPolicy.decideForUser(
        widget.usageRepository,
        widget.uid,
      );
      if (decision == UsageLimitDecision.requireUpgrade) {
        setState(() {
          _resultKind = _ResultKind.needsUpgrade;
        });
        return;
      }

      final responseText = await widget.backendClient.requestConsultation(
        petId: widget.petId,
        questionText: questionText,
        referencedRecords: _selectedReferences.toList(),
      );

      await widget.usageRepository.recordConsultationUsed(widget.uid);
      await widget.consultationRepository.save(
        uid: widget.uid,
        petId: widget.petId,
        questionText: questionText,
        aiResponse: responseText,
        referencedRecordIds: _selectedReferences.map((r) => r.recordId).toList(),
      );

      setState(() {
        _resultKind = _ResultKind.response;
        _resultText = responseText;
      });
    } catch (_) {
      setState(() {
        _resultKind = _ResultKind.error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefill = widget.prefillRecords ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('AI相談')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DisclaimerBanner(),
          const SizedBox(height: 16),
          if (prefill.isNotEmpty) ...[
            const Text('関連する記録を参照する（任意）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prefill
                  .map(
                    (record) => FilterChip(
                      label: Text(record.label),
                      selected: _selectedReferences.contains(record),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedReferences.add(record);
                          } else {
                            _selectedReferences.remove(record);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '気になる症状や様子を入力してください（例：今朝からぐったりしている）',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('相談する'),
          ),
          const SizedBox(height: 16),
          _buildResult(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text('相談履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    switch (_resultKind) {
      case _ResultKind.none:
        return const SizedBox.shrink();
      case _ResultKind.emergency:
        return const EmergencyNotice();
      case _ResultKind.needsUpgrade:
        return UpgradePromptCard(
          message: '今月の無料相談回数とチケットを使い切りました。'
              'チケットを購入するか、有料プランにアップグレードすると引き続きご利用いただけます。',
          onUpgrade: widget.onRequestUpgrade,
        );
      case _ResultKind.error:
        return const Text(
          '相談の送信に失敗しました。通信状況をご確認のうえ、もう一度お試しください。',
          style: TextStyle(color: Colors.red),
        );
      case _ResultKind.response:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_resultText ?? ''),
        );
    }
  }

  Widget _buildHistory() {
    return StreamBuilder<List<Consultation>>(
      stream: widget.consultationRepository.watchHistory(widget.uid, widget.petId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('相談履歴はまだありません。'),
          );
        }
        return Column(
          children: history
              .map(
                (c) => Card(
                  child: ListTile(
                    title: Text(c.questionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(c.aiResponse, maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      '${c.createdAt.month}/${c.createdAt.day}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
