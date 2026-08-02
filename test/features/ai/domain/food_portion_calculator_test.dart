import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/ai/domain/food_portion_calculator.dart';

void main() {
  const calculator = FoodPortionCalculator();

  group('calculate', () {
    test('10kg neutered adult on a 350 kcal/100g food', () {
      final result = calculator.calculate(
        weightKg: 10,
        activityLevel: DogActivityLevel.neuteredAdult,
        foodKcalPer100g: 350,
      );
      // RER = 70 * 10^0.75 ≈ 393.65
      expect(result.restingEnergyKcal, closeTo(393.65, 0.5));
      // MER = RER * 1.6 ≈ 629.85
      expect(result.maintenanceEnergyKcal, closeTo(629.85, 0.5));
      // grams = MER / 350 * 100 ≈ 179.96
      expect(result.dailyFoodGrams, closeTo(179.96, 0.5));
    });

    test('higher activity factor yields more food for the same weight/food', () {
      final sedentary = calculator.calculate(
        weightKg: 10,
        activityLevel: DogActivityLevel.weightLoss,
        foodKcalPer100g: 350,
      );
      final active = calculator.calculate(
        weightKg: 10,
        activityLevel: DogActivityLevel.active,
        foodKcalPer100g: 350,
      );
      expect(active.dailyFoodGrams, greaterThan(sedentary.dailyFoodGrams));
    });

    test('denser food yields fewer grams for the same energy need', () {
      final lowDensity = calculator.calculate(
        weightKg: 10,
        activityLevel: DogActivityLevel.neuteredAdult,
        foodKcalPer100g: 300,
      );
      final highDensity = calculator.calculate(
        weightKg: 10,
        activityLevel: DogActivityLevel.neuteredAdult,
        foodKcalPer100g: 400,
      );
      expect(highDensity.dailyFoodGrams, lessThan(lowDensity.dailyFoodGrams));
    });

    test('heavier dogs need more food than lighter dogs, same other inputs', () {
      final small = calculator.calculate(
        weightKg: 5,
        activityLevel: DogActivityLevel.neuteredAdult,
        foodKcalPer100g: 350,
      );
      final large = calculator.calculate(
        weightKg: 25,
        activityLevel: DogActivityLevel.neuteredAdult,
        foodKcalPer100g: 350,
      );
      expect(large.dailyFoodGrams, greaterThan(small.dailyFoodGrams));
    });
  });

  group('suggestDefaultActivityLevel', () {
    final now = DateTime(2026, 8, 2);

    test('a dog under 1 year old defaults to puppy regardless of neutered status', () {
      expect(
        calculator.suggestDefaultActivityLevel(
          birthday: DateTime(2026, 1, 1),
          neutered: true,
          now: now,
        ),
        DogActivityLevel.puppy,
      );
      expect(
        calculator.suggestDefaultActivityLevel(
          birthday: DateTime(2026, 1, 1),
          neutered: false,
          now: now,
        ),
        DogActivityLevel.puppy,
      );
    });

    test('an adult (1yr+), neutered dog defaults to neuteredAdult', () {
      expect(
        calculator.suggestDefaultActivityLevel(
          birthday: DateTime(2020, 1, 1),
          neutered: true,
          now: now,
        ),
        DogActivityLevel.neuteredAdult,
      );
    });

    test('an adult (1yr+), intact dog defaults to intactAdult', () {
      expect(
        calculator.suggestDefaultActivityLevel(
          birthday: DateTime(2020, 1, 1),
          neutered: false,
          now: now,
        ),
        DogActivityLevel.intactAdult,
      );
    });

    test('exactly 365 days old is treated as an adult, not a puppy', () {
      final birthday = now.subtract(const Duration(days: 365));
      expect(
        calculator.suggestDefaultActivityLevel(birthday: birthday, neutered: true, now: now),
        DogActivityLevel.neuteredAdult,
      );
    });
  });
}
