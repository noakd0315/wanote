import 'dart:math' as math;

/// Life stage -- auto-derivable from the pet's birthday (see
/// [FoodPortionCalculator.suggestDefaultLifeStage]), but still shown as an
/// overridable dropdown in case the birthday on file is wrong or approximate.
enum DogLifeStage {
  puppy,
  adult;
}

/// Standard veterinary Body Condition Score, simplified to the 3 buckets
/// that actually change the calculation (the real WSAVA scale is 1-9, but
/// this coarser split is what determines whether to aim for weight gain,
/// maintenance, or weight loss -- the clinically meaningful decision here).
/// Unlike life stage/neutered status, this can't be inferred from any data
/// already on file -- it requires a physical assessment (rib/waist
/// palpation), so it's always a direct user input.
enum BodyCondition {
  underweight,
  ideal,
  overweight;
}

/// Exercise/energy-expenditure level -- independent of life stage, neutered
/// status, and body condition, and (unlike those) something only the owner
/// can judge.
enum ActivityLevel {
  low,
  normal,
  high;
}

class FoodPortionResult {
  const FoodPortionResult({
    required this.restingEnergyKcal,
    required this.maintenanceEnergyKcal,
    required this.dailyFoodGrams,
  });

  /// RER: resting energy requirement, kcal/day.
  final double restingEnergyKcal;

  /// MER: maintenance energy requirement (RER x combined factor), kcal/day.
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
    required DogLifeStage lifeStage,
    required bool neutered,
    required BodyCondition bodyCondition,
    required ActivityLevel activityLevel,
    required double foodKcalPer100g,
  }) {
    assert(weightKg > 0, 'weightKg must be positive');
    assert(foodKcalPer100g > 0, 'foodKcalPer100g must be positive');
    final rer = 70 * math.pow(weightKg, 0.75);
    final factor = _merFactor(
      lifeStage: lifeStage,
      neutered: neutered,
      bodyCondition: bodyCondition,
      activityLevel: activityLevel,
    );
    final mer = rer * factor;
    final grams = mer / foodKcalPer100g * 100;
    return FoodPortionResult(
      restingEnergyKcal: rer.toDouble(),
      maintenanceEnergyKcal: mer.toDouble(),
      dailyFoodGrams: grams,
    );
  }

  /// Combined RER multiplier, following widely-cited small-animal nutrition
  /// guidance (e.g. WSAVA/AAHA): growing puppies ~3x regardless of the other
  /// factors (a simplified stand-in for age/expected-adult-weight growth
  /// curves, out of scope here); for adults, neutered ~1.6x / intact ~1.8x
  /// as the baseline, adjusted by activity level, with body condition
  /// taking priority when the dog is overweight (a body already carrying
  /// excess weight should be aimed at gradual loss regardless of its usual
  /// activity level) or nudging the factor up slightly when underweight (a
  /// modest surplus to help it gain).
  double _merFactor({
    required DogLifeStage lifeStage,
    required bool neutered,
    required BodyCondition bodyCondition,
    required ActivityLevel activityLevel,
  }) {
    if (lifeStage == DogLifeStage.puppy) {
      return 3.0;
    }
    if (bodyCondition == BodyCondition.overweight) {
      return 1.0;
    }
    var factor = neutered ? 1.6 : 1.8;
    switch (activityLevel) {
      case ActivityLevel.low:
        factor *= 0.85;
      case ActivityLevel.normal:
        break;
      case ActivityLevel.high:
        factor *= 1.4;
    }
    if (bodyCondition == BodyCondition.underweight) {
      factor += 0.2;
    }
    return factor;
  }

  /// Suggests a sensible starting life stage from data already on the pet's
  /// profile (age from birthday), so the user isn't required to work this
  /// out themselves -- they can still override it via the dropdown (e.g. if
  /// the recorded birthday is only approximate). Neutered status doesn't
  /// need a similar suggestion helper since it's read directly from the
  /// pet's profile as a fixed fact, not a judgment call; body condition and
  /// activity level have no on-file data to infer from at all.
  DogLifeStage suggestDefaultLifeStage({
    required DateTime birthday,
    required DateTime now,
  }) {
    final ageInDays = now.difference(birthday).inDays;
    return ageInDays < 365 ? DogLifeStage.puppy : DogLifeStage.adult;
  }
}
