import 'package:flutter/material.dart';

import '../../billing/ads/ad_gate.dart';
import '../../billing/domain/ad_trigger.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ai_answer_text.dart';
import '../../../shared/models/consultation_reference_record.dart';
import '../../../shared/services/ai_usage_repository.dart';
import '../data/ai_backend_client.dart';
import '../data/consultation_repository.dart';
import '../domain/emergency_keyword_detector.dart';
import '../domain/usage_limit_policy.dart';
import '../models/consultation.dart';
import 'widgets/disclaimer_banner.dart';
import 'widgets/ai_usage_badge.dart';
import 'widgets/emergency_notice.dart';
import 'widgets/upgrade_prompt_card.dart';
import '../../../shared/widgets/stream_error_view.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';

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

  /// Whether this screen has already spent its ad impression.
  ///
  /// The ad starts as soon as the request does, so a request that then
  /// fails has still cost the owner an ad. Charging them a second one to
  /// retry the same question would be charging twice for one consultation,
  /// and the failure was not theirs (PM report).
  bool _adAlreadyShown = false;

  /// Bumped whenever a call is spent, so the remaining-count badge re-reads.
  int _usageRefreshToken = 0;

  _ResultKind _resultKind = _ResultKind.none;
  String? _resultText;

  /// The question the answer on screen belongs to.
  ///
  /// The submit button looked identical before and after an answer arrived,
  /// and the answer appears *below* it -- so the natural next move was to
  /// press it again, spending a second call on the same question (PM,
  /// 2026-08-21). Cleared as soon as the text changes, so asking something
  /// else is never blocked.
  String? _answeredQuestion;

  bool get _alreadyAnswered =>
      _answeredQuestion != null &&
      _controller.text.trim() == _answeredQuestion;

  /// Empties the question and the answer together. Clearing one and
  /// leaving the other would read as an answer to a question that is no
  /// longer there.
  void _clear() {
    _controller.clear();
    setState(() {
      _resultKind = _ResultKind.none;
      _resultText = null;
      _answeredQuestion = null;
    });
  }

  @override
  void initState() {
    super.initState();
    // The row below reads _controller.text to decide what to show, and a
    // TextField's own edits do not rebuild this widget on their own.
    _controller.addListener(_onQuestionChanged);
  }

  void _onQuestionChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onQuestionChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Captured before the first await: reading it from the
    // BuildContext afterwards would be a use-after-dispose hazard.
    final languageCode = Localizations.localeOf(context).languageCode;
    // Same reason: read from the context before the first await.
    final adGate = adGateOf(context);
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
      // getStatus directly rather than decideForUser: the same snapshot has
      // to answer both "may they ask?" and "which wallet pays?", and the
      // second question must be asked BEFORE the call is recorded -- after
      // that the balance has moved and a ticket just spent looks like no
      // ticket at all.
      final status = await widget.usageRepository.getStatus(widget.uid);
      if (widget.usageLimitPolicy.decide(status) ==
          UsageLimitDecision.requireUpgrade) {
        setState(() {
          _resultKind = _ResultKind.needsUpgrade;
        });
        return;
      }
      final usageSource = status.nextSource;

      final responseFuture = widget.backendClient.requestConsultation(
        petId: widget.petId,
        questionText: questionText,
        referencedRecords: _selectedReferences.toList(),
        languageCode: languageCode,
      );
      // Started after the request, and awaited after it: the ad plays while
      // the answer is being generated, so it costs no extra waiting.
      //
      // A failed request has still played its ad by then -- the two run
      // concurrently, so there is no way to take it back. What we can do is
      // not play a second one when the owner retries.
      final adFuture = _adAlreadyShown
          ? null
          : adGate?.maybeShow(
              AdTrigger.aiConsultation,
              aiUsageSource: usageSource,
            );
      if (adFuture != null) _adAlreadyShown = true;

      final responseText = await responseFuture;
      await adFuture;

      await widget.usageRepository.recordConsultationUsed(widget.uid);
      if (mounted) setState(() => _usageRefreshToken++);
      await widget.consultationRepository.save(
        uid: widget.uid,
        petId: widget.petId,
        questionText: questionText,
        aiResponse: responseText,
        referencedRecordIds: _selectedReferences
            .map((r) => r.recordId)
            .toList(),
      );

      setState(() {
        _resultKind = _ResultKind.response;
        _resultText = responseText;
        _answeredQuestion = questionText;
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
    final l10n = AppLocalizations.of(context)!;
    final prefill = widget.prefillRecords ?? const [];
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through this tab-root screen, per the PM's
      // request to scatter the pattern across each screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.consultationScreenAppBarTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DisclaimerBanner(),
          const SizedBox(height: 16),
          if (prefill.isNotEmpty) ...[
            Text(
              l10n.consultationReferenceRecordsLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
            // Rebuilds so the clear button appears with the first character
            // typed rather than after the next unrelated rebuild.
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l10n.consultationInputHintText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _submitting || _alreadyAnswered ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      // Says why it is disabled. A greyed-out button with
                      // its original label reads as a fault.
                      : Text(
                          _alreadyAnswered
                              ? l10n.consultationAlreadyAnsweredButton
                              : l10n.consultationSubmitButton,
                        ),
                ),
              ),
              // The question and its answer used to stay on screen with no
              // way to dismiss them, so returning to this tab opened onto
              // the last conversation (PM report). Hidden while there is
              // nothing to clear, so it never sits there doing nothing.
              if (!_submitting &&
                  (_controller.text.isNotEmpty ||
                      _resultKind != _ResultKind.none)) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _clear,
                  child: Text(l10n.consultationClearButton),
                ),
              ],
            ],
          ),
          // Under the button that spends it (PM, 2026-08-18). At the top of
          // the screen it was a fact about the account; here it is the
          // price of the thing being pressed.
          AiUsageBadge(
            uid: widget.uid,
            usageRepository: widget.usageRepository,
            refreshToken: _usageRefreshToken,
          ),
          const SizedBox(height: 16),
          _buildResult(l10n),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            l10n.consultationHistoryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildHistory(),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Consultation consultation) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.consultationHistoryDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.consultationHistoryDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.consultationRepository.delete(
      uid: widget.uid,
      petId: widget.petId,
      consultationId: consultation.consultationId,
    );
  }

  Future<void> _showConsultation(Consultation consultation) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.consultationHistoryDetailTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.consultationHistoryQuestionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(consultation.questionText),
              const SizedBox(height: 16),
              Text(
                l10n.consultationHistoryAnswerLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // Selectable: advice worth keeping is worth copying into a
              // message to the clinic.
              AiAnswerText(consultation.aiResponse, selectable: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(AppLocalizations l10n) {
    switch (_resultKind) {
      case _ResultKind.none:
        return const SizedBox.shrink();
      case _ResultKind.emergency:
        return const EmergencyNotice();
      case _ResultKind.needsUpgrade:
        return UpgradePromptCard(
          message: l10n.consultationUsageLimitMessage,
          onUpgrade: widget.onRequestUpgrade,
        );
      case _ResultKind.error:
        return Text(
          l10n.consultationSubmitFailedMessage,
          style: const TextStyle(color: Colors.red),
        );
      case _ResultKind.response:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AiAnswerText(_resultText ?? '', selectable: true),
        );
    }
  }

  Widget _buildHistory() {
    return StreamBuilder<List<Consultation>>(
      stream: widget.consultationRepository.watchHistory(
        widget.uid,
        widget.petId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamErrorView(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: WanoteLoadingIndicator.centered(),
          );
        }
        final history = snapshot.data!;
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              AppLocalizations.of(context)!.consultationHistoryEmptyMessage,
            ),
          );
        }
        return Column(
          children: history
              .map(
                (c) => Card(
                  child: ListTile(
                    // The answer was stored all along and shown truncated to
                    // three lines, with no way to read the rest -- which is
                    // why the history looked not worth keeping (PM: "回答が
                    // 見れないのであれば履歴として残す必要はない").
                    onTap: () => _showConsultation(c),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: AppLocalizations.of(
                        context,
                      )!.consultationHistoryDeleteButton,
                      onPressed: () => _confirmDelete(c),
                    ),
                    title: Text(
                      c.questionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      // Plain, not rendered: a heading at heading size
                      // inside a three-line snippet reads worse, but the
                      // markers should not show either.
                      aiAnswerPlainText(c.aiResponse),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
