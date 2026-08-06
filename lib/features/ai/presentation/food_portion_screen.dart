import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/services/ai_usage_repository.dart';
import '../data/ai_backend_client.dart';
import '../domain/food_portion_calculator.dart';
import '../domain/usage_limit_policy.dart';
import 'widgets/upgrade_prompt_card.dart';

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
  late DogLifeStage _lifeStage;
  BodyCondition _bodyCondition = BodyCondition.ideal;
  ActivityLevel _activityLevel = ActivityLevel.normal;

  FoodPortionResult? _result;
  _AdviceState _adviceState = _AdviceState.idle;
  String? _adviceText;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.initialWeightKg?.toString() ?? '',
    );
    _lifeStage = widget.calculator.suggestDefaultLifeStage(
      birthday: widget.birthday,
      now: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _foodDensityController.dispose();
    super.dispose();
  }

  void _calculate() {
    final weightKg = double.tryParse(_weightController.text);
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
    final result = _result;
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
      // Deliberately compact/structured -- just the numbers already
      // computed, not a conversational prompt -- to keep the token cost of
      // this call low per the PM's request.
      final questionText =
          '体重${_weightController.text}kg、${_lifeStage.label}'
          '${isAdult ? '（${widget.neutered ? '避妊・去勢済み' : '未避妊・未去勢'}、体型:${_bodyCondition.label}、活動量:${_activityLevel.label}）' : ''}、'
          '1日の目安摂取カロリー${result.maintenanceEnergyKcal.round()}kcal、'
          '使用フード${_foodDensityController.text}kcal/100gで'
          '1日あたり${result.dailyFoodGrams.round()}g程度と算出しました。'
          '給餌回数の分け方や注意点があれば簡潔に教えてください。';

      final advice = await widget.backendClient.requestConsultation(
        petId: widget.petId,
        questionText: questionText,
        languageCode: languageCode,
      );
      await widget.usageRepository.recordConsultationUsed(widget.uid);
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
