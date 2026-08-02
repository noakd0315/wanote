import 'package:flutter/material.dart';

import '../../../shared/services/ai_usage_repository.dart';
import '../data/ai_backend_client.dart';
import '../domain/food_portion_calculator.dart';
import '../domain/usage_limit_policy.dart';
import 'widgets/upgrade_prompt_card.dart';

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
    final result = _result;
    final isAdult = _lifeStage == DogLifeStage.adult;
    return Scaffold(
      appBar: AppBar(title: const Text('餌の量を計算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '体重 (kg)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DogLifeStage>(
            initialValue: _lifeStage,
            decoration: const InputDecoration(labelText: 'ライフステージ'),
            items: [
              for (final stage in DogLifeStage.values)
                DropdownMenuItem(value: stage, child: Text(stage.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _lifeStage = value);
            },
          ),
          if (isAdult) ...[
            const SizedBox(height: 12),
            Text(
              '避妊・去勢：${widget.neutered ? '済み' : '未'}（プロフィールの登録内容）',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BodyCondition>(
              initialValue: _bodyCondition,
              decoration: const InputDecoration(
                labelText: '体型（ボディコンディション）',
                helperText: 'あばら骨に触れやすい＝痩せ気味／触れるが見えない＝標準／触れにくい＝ぽっちゃり気味',
                helperMaxLines: 2,
              ),
              items: [
                for (final condition in BodyCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _bodyCondition = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activityLevel,
              decoration: const InputDecoration(labelText: '活動レベル'),
              items: [
                for (final level in ActivityLevel.values)
                  DropdownMenuItem(value: level, child: Text(level.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _activityLevel = value);
              },
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              '※ 成長期の子犬は体型・活動量に関わらず、年齢に応じた係数で算出します。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _foodDensityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'フードのカロリー密度 (kcal/100g)',
              helperText: 'フードのパッケージに記載されている値を入力してください',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _calculate, child: const Text('計算する')),
          if (result != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _ResultRow(
              label: '安静時代謝エネルギー (RER)',
              value: '${result.restingEnergyKcal.round()} kcal/日',
            ),
            _ResultRow(
              label: '1日の目安摂取カロリー (MER)',
              value: '${result.maintenanceEnergyKcal.round()} kcal/日',
            ),
            _ResultRow(
              label: '1日あたりの給餌量',
              value: '${result.dailyFoodGrams.round()} g/日',
              emphasize: true,
            ),
            const SizedBox(height: 8),
            const Text(
              '※ 目安です。体調・体型の変化に応じて調整し、詳しくは獣医師にご相談ください。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildAdviceSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildAdviceSection() {
    switch (_adviceState) {
      case _AdviceState.idle:
        return OutlinedButton.icon(
          onPressed: _requestAdvice,
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('AIに給餌のアドバイスを聞く'),
        );
      case _AdviceState.loading:
        return const Center(child: CircularProgressIndicator());
      case _AdviceState.needsUpgrade:
        return UpgradePromptCard(
          message: 'AI相談の利用回数上限に達しています。',
          onUpgrade: widget.onRequestUpgrade,
        );
      case _AdviceState.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'アドバイスの取得に失敗しました。',
                style: TextStyle(color: Colors.red),
              ),
            ),
            OutlinedButton(onPressed: _requestAdvice, child: const Text('再試行')),
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
