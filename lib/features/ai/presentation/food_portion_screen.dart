import 'package:flutter/material.dart';

import '../../billing/ads/ad_gate.dart';
import '../../billing/domain/ad_trigger.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/ai_usage_repository.dart';
import '../data/ai_backend_client.dart';
import '../domain/food_portion_calculator.dart';
import '../domain/usage_limit_policy.dart';
import 'widgets/upgrade_prompt_card.dart';
import '../../../shared/utils/formatting.dart';
import '../data/consultation_repository.dart';

/// Display labels for [DogLifeStage], kept here (not on the enum itself)
/// since the enum lives in the framework-free domain layer and can't call
/// [AppLocalizations.of] -- see the model's `.label` getter, which is left
/// in place for the non-UI AI-prompt use in [_FoodPortionScreenState._requestAdvice].
String _lifeStageLabel(AppLocalizations l10n, DogLifeStage stage) =>
    switch (stage) {
      DogLifeStage.puppy => l10n.dogLifeStagePuppyLabel,
      DogLifeStage.adult => l10n.dogLifeStageAdultLabel,
    };

/// Display labels for [BodyCondition] -- see [_lifeStageLabel] for why this
/// lives in the presentation layer instead of on the enum.
String _bodyConditionLabel(AppLocalizations l10n, BodyCondition condition) =>
    switch (condition) {
      BodyCondition.underweight => l10n.bodyConditionUnderweightLabel,
      BodyCondition.ideal => l10n.bodyConditionIdealLabel,
      BodyCondition.overweight => l10n.bodyConditionOverweightLabel,
    };

/// Display labels for [ActivityLevel] -- see [_lifeStageLabel] for why this
/// lives in the presentation layer instead of on the enum.
String _activityLevelLabel(AppLocalizations l10n, ActivityLevel level) =>
    switch (level) {
      ActivityLevel.low => l10n.activityLevelLowLabel,
      ActivityLevel.normal => l10n.activityLevelNormalLabel,
      ActivityLevel.high => l10n.activityLevelHighLabel,
    };

/// Dog food-portion calculator, reachable from the home screen icon per the
/// PM's request.
///
/// The actual gram calculation (RER/MER, [FoodPortionCalculator]) is a
/// well-established veterinary formula computed entirely in Dart -- it
/// costs zero AI tokens and returns instantly, no network round-trip
/// needed. AI is only invoked for the *optional* "give me feeding advice"
/// step below the result, and even then the prompt sent is a short,
/// structured one-liner built from numbers already on screen rather than
/// free-form text, per the PM's explicit ask to keep token usage down.
/// Inputs that can be pre-filled/inferred from data the app already has
/// (weight, life stage from birthday, neutered status from the pet
/// profile) are pre-filled/hidden from manual entry; body condition and
/// activity level have no such source and are always asked directly, since
/// both are genuine judgment calls only the owner can make.
class FoodPortionScreen extends StatefulWidget {
  const FoodPortionScreen({
    super.key,
    required this.uid,
    required this.petId,
    required this.birthday,
    required this.neutered,
    required this.usageRepository,
    required this.backendClient,
    required this.consultationRepository,
    required this.onRequestUpgrade,
    this.initialWeightKg,
    this.calculator = const FoodPortionCalculator(),
    this.usageLimitPolicy = const UsageLimitPolicy(),
  });

  final String uid;
  final String petId;
  final DateTime birthday;
  final bool neutered;
  final AiUsageRepository usageRepository;
  final AiBackendClient backendClient;

  /// The advice is written to the same history as a typed consultation.
  ///
  /// PM request. It is an AI answer about this dog that the owner paid a
  /// quota slot for, and it used to vanish the moment the screen closed --
  /// while a typed question asking the same thing would have been kept.
  final ConsultationRepository consultationRepository;
  final VoidCallback onRequestUpgrade;

  /// Latest known weight (from features/daily_record's weight records),
  /// resolved by whoever builds this screen -- kept as a plain nullable
  /// double rather than this screen importing WeightRecordRepository
  /// itself, mirroring how ReportScreen receives MonthlyReportInputStats
  /// instead of reaching into daily_record directly.
  final double? initialWeightKg;

  final FoodPortionCalculator calculator;
  final UsageLimitPolicy usageLimitPolicy;

  @override
  State<FoodPortionScreen> createState() => _FoodPortionScreenState();
}

enum _AdviceState { idle, loading, ready, needsUpgrade, error }

class _FoodPortionScreenState extends State<FoodPortionScreen> {
  late final TextEditingController _weightController;
  final _foodDensityController = TextEditingController();

  /// What the dog is actually being fed today. Optional.
  ///
  /// Without it the advice had nothing to work with beyond the figure the
  /// app had just calculated, so it could only restate it -- which is why
  /// it read as a canned answer (PM report). With it, there is a gap to
  /// talk about, and how to close it.
  final _currentAmountController = TextEditingController();
  late DogLifeStage _lifeStage;
  BodyCondition _bodyCondition = BodyCondition.ideal;
  ActivityLevel _activityLevel = ActivityLevel.normal;

  FoodPortionResult? _result;
  _AdviceState _adviceState = _AdviceState.idle;
  String? _adviceText;

  /// Whether this screen has already spent its ad impression -- see
  /// consultation_screen.dart for why a retry must not cost a second one.
  bool _adAlreadyShown = false;

  @override
  void initState() {
    super.initState();
    // Filled in didChangeDependencies: the unit follows the language, and
    // Localizations is not available yet here.
    _weightController = TextEditingController();
    _lifeStage = widget.calculator.suggestDefaultLifeStage(
      birthday: widget.birthday,
      now: DateTime.now(),
    );
  }

  /// The sentence describing what the dog is fed now, or nothing at all.
  ///
  /// Nothing at all when the field is blank or not a number: an invented or
  /// misread figure would have the advice reason from something the owner
  /// never said.
  /// What goes into the consultation history for a food-portion enquiry.
  ///
  /// Deliberately a second rendering of the same figures rather than a
  /// reuse of the prompt. The prompt is English, carries stored units, and
  /// ends with instructions aimed at the model; none of that belongs in
  /// something the owner opens and reads months later. The duplication is
  /// the point, and was accepted knowingly (PM decision, 2026-08-15).
  String _historyText(
    BuildContext context,
    AppLocalizations l10n,
    double? weightKg,
    FoodPortionResult result,
  ) {
    final profile = [
      _lifeStageLabel(l10n, _lifeStage),
      if (_lifeStage == DogLifeStage.adult) ...[
        _bodyConditionLabel(l10n, _bodyCondition),
        _activityLevelLabel(l10n, _activityLevel),
      ],
    ].join('・');

    final summary = l10n.foodPortionHistorySummary(
      weightKg == null ? '-' : formatWeight(context, weightKg),
      profile,
      formatFoodQuantity(context, result.dailyFoodGrams),
      result.maintenanceEnergyKcal.round().toString(),
      _foodDensityController.text.trim(),
    );

    final current = double.tryParse(_currentAmountController.text.trim());
    if (current == null || current <= 0) return summary;
    return summary +
        l10n.foodPortionHistoryCurrentAmount(
          formatFoodQuantity(context, current),
        );
  }

  String _currentAmountText() {
    final grams = double.tryParse(_currentAmountController.text.trim());
    if (grams == null || grams <= 0) return '';
    return 'The dog is currently fed ${grams.round()}g per day. '
        'Say whether that should change, given the calculated figure. ';
  }

  bool _weightPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weightPrefilled) return;
    _weightPrefilled = true;
    _weightController.text = weightInputText(context, widget.initialWeightKg);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _foodDensityController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  void _calculate() {
    final weightKg = parseWeightToKilograms(context, _weightController.text);
    final foodKcalPer100g = double.tryParse(_foodDensityController.text);
    if (weightKg == null ||
        weightKg <= 0 ||
        foodKcalPer100g == null ||
        foodKcalPer100g <= 0) {
      setState(() => _result = null);
      return;
    }
    setState(() {
      _result = widget.calculator.calculate(
        weightKg: weightKg,
        lifeStage: _lifeStage,
        neutered: widget.neutered,
        bodyCondition: _bodyCondition,
        activityLevel: _activityLevel,
        foodKcalPer100g: foodKcalPer100g,
      );
      // A fresh calculation invalidates any previously-generated advice.
      _adviceState = _AdviceState.idle;
      _adviceText = null;
    });
  }

  Future<void> _requestAdvice() async {
    // Captured before the first await: reading it from the
    // BuildContext afterwards would be a use-after-dispose hazard.
    final languageCode = Localizations.localeOf(context).languageCode;
    // Same reason: read from the context before the first await.
    final adGate = adGateOf(context);
    final l10n = AppLocalizations.of(context)!;
    final historyPrefix = l10n.consultationHistoryFoodPortionPrefix;
    // Same again: the weight is read in the field's unit and converted here,
    // while the context is still safe to touch.
    final weightKg = parseWeightToKilograms(context, _weightController.text);
    final result = _result;
    // Built here, from the context, for the same reason as everything else
    // above -- and kept apart from the prompt on purpose. See _historyText.
    final historyText = result == null
        ? null
        : _historyText(context, l10n, weightKg, result);
    if (result == null) return;

    setState(() => _adviceState = _AdviceState.loading);
    try {
      final decision = await widget.usageLimitPolicy.decideForUser(
        widget.usageRepository,
        widget.uid,
      );
      if (decision == UsageLimitDecision.requireUpgrade) {
        setState(() => _adviceState = _AdviceState.needsUpgrade);
        return;
      }

      final isAdult = _lifeStage == DogLifeStage.adult;
      // English, like every other prompt the app sends: one language for
      // everything we write, so a change lands in one place. Nothing here is
      // the owner's own words -- it is entirely figures this screen just
      // calculated -- so there is nothing to lose by writing it in English.
      // The answer's language is pinned separately by languageCode.
      //
      // Deliberately compact and structured rather than conversational, to
      // keep the token cost of this call low per the PM's request.
      final questionText =
          // Stored units, not the display ones: the prompt is not read by
          // the owner, and mixing units into it would only invite mistakes.
          'Weight ${weightKg?.toStringAsFixed(1)}kg, ${_lifeStage.name}'
          '${isAdult ? ' (${widget.neutered ? 'neutered' : 'not neutered'}, '
                'body condition: ${_bodyCondition.name}, '
                'activity: ${_activityLevel.name})' : ''}. '
          'Daily maintenance energy ${result.maintenanceEnergyKcal.round()}kcal. '
          'Food is ${_foodDensityController.text}kcal/100g, '
          'so about ${result.dailyFoodGrams.round()}g per day was calculated. '
          '${_currentAmountText()}'
          'How should this be split across meals, and is there anything to '
          'watch out for? Keep it brief.';

      // Read before recording the use -- see consultation_screen.dart.
      final usageSource = (await widget.usageRepository.getStatus(
        widget.uid,
      )).nextSource;

      final adviceFuture = widget.backendClient.requestConsultation(
        petId: widget.petId,
        questionText: questionText,
        languageCode: languageCode,
      );
      // Not a second time on a retry -- see consultation_screen.dart.
      final adFuture = _adAlreadyShown
          ? null
          : adGate?.maybeShow(
              AdTrigger.aiFoodPortion,
              aiUsageSource: usageSource,
            );
      if (adFuture != null) _adAlreadyShown = true;

      final advice = await adviceFuture;
      await adFuture;

      await widget.usageRepository.recordConsultationUsed(widget.uid);
      // Prefixed so the two kinds are told apart in the list: this one was
      // assembled by a calculator, not typed by the owner.
      await widget.consultationRepository.save(
        uid: widget.uid,
        petId: widget.petId,
        // NOT the prompt. The prompt is English and ends in instructions to
        // the model ("Keep it brief"), which is exactly what the owner saw
        // in their own history (PM report, 2026-08-15). What gets stored is
        // a localized summary of what they entered, in their display units.
        questionText: '$historyPrefix$historyText',
        aiResponse: advice,
        referencedRecordIds: const [],
      );
      setState(() {
        _adviceText = advice;
        _adviceState = _AdviceState.ready;
      });
    } catch (_) {
      setState(() => _adviceState = _AdviceState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final isAdult = _lifeStage == DogLifeStage.adult;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.foodPortionAppBarTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.foodPortionWeightLabel),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DogLifeStage>(
            initialValue: _lifeStage,
            decoration: InputDecoration(
              labelText: l10n.foodPortionLifeStageLabel,
            ),
            items: [
              for (final stage in DogLifeStage.values)
                DropdownMenuItem(
                  value: stage,
                  child: Text(_lifeStageLabel(l10n, stage)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _lifeStage = value);
            },
          ),
          if (isAdult) ...[
            const SizedBox(height: 12),
            Text(
              l10n.foodPortionNeuteredStatusLabel(
                widget.neutered
                    ? l10n.neuteredStatusDone
                    : l10n.neuteredStatusNotDone,
              ),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BodyCondition>(
              initialValue: _bodyCondition,
              decoration: InputDecoration(
                labelText: l10n.foodPortionBodyConditionLabel,
                helperText: l10n.foodPortionBodyConditionHelperText,
                helperMaxLines: 2,
              ),
              items: [
                for (final condition in BodyCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(_bodyConditionLabel(l10n, condition)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _bodyCondition = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activityLevel,
              decoration: InputDecoration(
                labelText: l10n.foodPortionActivityLevelLabel,
              ),
              items: [
                for (final level in ActivityLevel.values)
                  DropdownMenuItem(
                    value: level,
                    child: Text(_activityLevelLabel(l10n, level)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _activityLevel = value);
              },
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              l10n.foodPortionPuppyNoteText,
              // Red like the other cautions (PM request) -- grey made these
              // read as decoration rather than something to act on.
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _foodDensityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.foodPortionCalorieDensityLabel,
              helperText: l10n.foodPortionCalorieDensityHelperText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currentAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.foodPortionCurrentAmountLabel,
              helperText: l10n.foodPortionCurrentAmountHelperText,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _calculate,
            child: Text(l10n.foodPortionCalculateButton),
          ),
          if (result != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _ResultRow(
              label: l10n.foodPortionRerLabel,
              value: l10n.foodPortionKcalPerDayValue(
                result.restingEnergyKcal.round(),
              ),
            ),
            _ResultRow(
              label: l10n.foodPortionMerLabel,
              value: l10n.foodPortionKcalPerDayValue(
                result.maintenanceEnergyKcal.round(),
              ),
            ),
            _ResultRow(
              label: l10n.foodPortionDailyFoodLabel,
              value: l10n.foodPortionGramsPerDayValue(
                result.dailyFoodGrams.round(),
              ),
              emphasize: true,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.foodPortionResultDisclaimerText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdviceSection(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildAdviceSection(AppLocalizations l10n) {
    switch (_adviceState) {
      case _AdviceState.idle:
        return OutlinedButton.icon(
          onPressed: _requestAdvice,
          icon: const Icon(Icons.smart_toy_outlined),
          label: Text(l10n.foodPortionRequestAdviceButton),
        );
      case _AdviceState.loading:
        return const Center(child: CircularProgressIndicator());
      case _AdviceState.needsUpgrade:
        return UpgradePromptCard(
          message: l10n.foodPortionAdviceUsageLimitMessage,
          onUpgrade: widget.onRequestUpgrade,
        );
      case _AdviceState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.foodPortionAdviceFailedMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            OutlinedButton(
              onPressed: _requestAdvice,
              child: Text(l10n.foodPortionAdviceRetryButton),
            ),
          ],
        );
      case _AdviceState.ready:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_adviceText ?? ''),
        );
    }
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: emphasize
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                : const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
