import 'dart:math' as math;

/// Standard veterinary maintenance-energy-requirement (MER) categories,
/// each a multiplier of resting energy requirement (RER). Values follow
/// widely-cited small-animal nutrition guidance (e.g. WSAVA/AAHA):
/// intact adult ~1.8x, neutered adult ~1.6x, weight loss ~1.0x, active/
/// working dogs ~2.5x, growing puppies ~2-3x.
enum DogActivityLevel {
  weightLoss,
  neuteredAdult,
  intactAdult,
  active,
  puppy;

  double get merFactor => switch (this) {
    DogActivityLevel.weightLoss => 1.0,
    DogActivityLevel.neuteredAdult => 1.6,
    DogActivityLevel.intactAdult => 1.8,
    DogActivityLevel.active => 2.5,
    DogActivityLevel.puppy => 3.0,
  };

  String get label => switch (this) {
    DogActivityLevel.weightLoss => '減量中',
    DogActivityLevel.neuteredAdult => '成犬（避妊・去勢済み／室内中心）',
    DogActivityLevel.intactAdult => '成犬（未避妊・未去勢／通常の運動量）',
    DogActivityLevel.active => '運動量が多い・活発',
    DogActivityLevel.puppy => '成長期の子犬',
  };
}

class FoodPortionResult {
  const FoodPortionResult({
    required this.restingEnergyKcal,
    required this.maintenanceEnergyKcal,
    required this.dailyFoodGrams,
  });

  /// RER: resting energy requirement, kcal/day.
  final double restingEnergyKcal;

  /// MER: maintenance energy requirement (RER x activity factor), kcal/day.
  final double maintenanceEnergyKcal;

  /// Recommended daily food amount in grams, derived from MER and the
  /// food's calorie density.
  final double dailyFoodGrams;
}

/// Pure, deterministic dog food-portion calculator -- no AI call needed for
/// the number itself, so it costs zero tokens and returns instantly. An AI
/// call is only used (optionally, elsewhere) to turn this result into
/// free-text feeding advice; the arithmetic itself is well-established
/// veterinary formula, not something an LLM needs to compute.
class FoodPortionCalculator {
  const FoodPortionCalculator();

  FoodPortionResult calculate({
    required double weightKg,
    required DogActivityLevel activityLevel,
    required double foodKcalPer100g,
  }) {
    assert(weightKg > 0, 'weightKg must be positive');
    assert(foodKcalPer100g > 0, 'foodKcalPer100g must be positive');
    final rer = 70 * math.pow(weightKg, 0.75);
    final mer = rer * activityLevel.merFactor;
    final grams = mer / foodKcalPer100g * 100;
    return FoodPortionResult(
      restingEnergyKcal: rer.toDouble(),
      maintenanceEnergyKcal: mer.toDouble(),
      dailyFoodGrams: grams,
    );
  }

  /// Suggests a sensible starting activity level from data already on the
  /// pet's profile (age from birthday, neutered status), so the user isn't
  /// required to look up veterinary terminology just to get a reasonable
  /// default -- they can still override it via the dropdown. This is also
  /// what keeps the eventual AI-advice prompt (see FoodPortionScreen) short:
  /// fewer fields the user has to actively decide on themselves.
  DogActivityLevel suggestDefaultActivityLevel({
    required DateTime birthday,
    required bool neutered,
    required DateTime now,
  }) {
    final ageInDays = now.difference(birthday).inDays;
    if (ageInDays < 365) return DogActivityLevel.puppy;
    return neutered
        ? DogActivityLevel.neuteredAdult
        : DogActivityLevel.intactAdult;
  }
}
