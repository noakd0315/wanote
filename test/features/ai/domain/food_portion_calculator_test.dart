import 'package:flutter_test/flutter_test.dart';
import 'package:wanote/features/ai/domain/food_portion_calculator.dart';

void main() {
  const calculator = FoodPortionCalculator();

  group('calculate', () {
    test(
      '10kg neutered adult, ideal body condition, normal activity, 350 kcal/100g food',
      () {
        final result = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        // RER = 70 * 10^0.75 ≈ 393.65
        expect(result.restingEnergyKcal, closeTo(393.65, 0.5));
        // MER = RER * 1.6 ≈ 629.85
        expect(result.maintenanceEnergyKcal, closeTo(629.85, 0.5));
        // grams = MER / 350 * 100 ≈ 179.96
        expect(result.dailyFoodGrams, closeTo(179.96, 0.5));
      },
    );

    test('higher activity level yields more food for the same weight/food', () {
      final low = calculator.calculate(
        weightKg: 10,
        lifeStage: DogLifeStage.adult,
        neutered: true,
        bodyCondition: BodyCondition.ideal,
        activityLevel: ActivityLevel.low,
        foodKcalPer100g: 350,
      );
      final high = calculator.calculate(
        weightKg: 10,
        lifeStage: DogLifeStage.adult,
        neutered: true,
        bodyCondition: BodyCondition.ideal,
        activityLevel: ActivityLevel.high,
        foodKcalPer100g: 350,
      );
      expect(high.dailyFoodGrams, greaterThan(low.dailyFoodGrams));
    });

    test(
      'overweight body condition forces a weight-loss factor regardless of activity level',
      () {
        final overweightActive = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.overweight,
          activityLevel: ActivityLevel.high,
          foodKcalPer100g: 350,
        );
        final idealLow = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.low,
          foodKcalPer100g: 350,
        );
        // Overweight always clamps to the RER*1.0 weight-loss factor, so it
        // should recommend less food even than an otherwise-lighter-eating
        // (low activity, ideal condition) adult.
        expect(
          overweightActive.dailyFoodGrams,
          lessThan(idealLow.dailyFoodGrams),
        );
      },
    );

    test(
      'underweight body condition yields more food than ideal, same other inputs',
      () {
        final ideal = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        final underweight = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.underweight,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        expect(underweight.dailyFoodGrams, greaterThan(ideal.dailyFoodGrams));
      },
    );

    test(
      'intact adults need more food than neutered adults, same other inputs',
      () {
        final neutered = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        final intact = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.adult,
          neutered: false,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        expect(intact.dailyFoodGrams, greaterThan(neutered.dailyFoodGrams));
      },
    );

    test(
      'puppy life stage ignores body condition/activity level and uses the fixed growth factor',
      () {
        final asOverweightHigh = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.puppy,
          neutered: false,
          bodyCondition: BodyCondition.overweight,
          activityLevel: ActivityLevel.high,
          foodKcalPer100g: 350,
        );
        final asUnderweightLow = calculator.calculate(
          weightKg: 10,
          lifeStage: DogLifeStage.puppy,
          neutered: false,
          bodyCondition: BodyCondition.underweight,
          activityLevel: ActivityLevel.low,
          foodKcalPer100g: 350,
        );
        expect(
          asOverweightHigh.dailyFoodGrams,
          asUnderweightLow.dailyFoodGrams,
        );
        // MER = RER * 3.0 fixed puppy factor.
        expect(
          asOverweightHigh.maintenanceEnergyKcal,
          closeTo(393.65 * 3.0, 0.5),
        );
      },
    );

    test('denser food yields fewer grams for the same energy need', () {
      final lowDensity = calculator.calculate(
        weightKg: 10,
        lifeStage: DogLifeStage.adult,
        neutered: true,
        bodyCondition: BodyCondition.ideal,
        activityLevel: ActivityLevel.normal,
        foodKcalPer100g: 300,
      );
      final highDensity = calculator.calculate(
        weightKg: 10,
        lifeStage: DogLifeStage.adult,
        neutered: true,
        bodyCondition: BodyCondition.ideal,
        activityLevel: ActivityLevel.normal,
        foodKcalPer100g: 400,
      );
      expect(highDensity.dailyFoodGrams, lessThan(lowDensity.dailyFoodGrams));
    });

    test(
      'heavier dogs need more food than lighter dogs, same other inputs',
      () {
        final small = calculator.calculate(
          weightKg: 5,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        final large = calculator.calculate(
          weightKg: 25,
          lifeStage: DogLifeStage.adult,
          neutered: true,
          bodyCondition: BodyCondition.ideal,
          activityLevel: ActivityLevel.normal,
          foodKcalPer100g: 350,
        );
        expect(large.dailyFoodGrams, greaterThan(small.dailyFoodGrams));
      },
    );
  });

  group('suggestDefaultLifeStage', () {
    final now = DateTime(2026, 8, 2);

    test('a dog under 1 year old defaults to puppy', () {
      expect(
        calculator.suggestDefaultLifeStage(
          birthday: DateTime(2026, 1, 1),
          now: now,
        ),
        DogLifeStage.puppy,
      );
    });

    test('a dog 1 year or older defaults to adult', () {
      expect(
        calculator.suggestDefaultLifeStage(
          birthday: DateTime(2020, 1, 1),
          now: now,
        ),
        DogLifeStage.adult,
      );
    });

    test('exactly 365 days old is treated as an adult, not a puppy', () {
      final birthday = now.subtract(const Duration(days: 365));
      expect(
        calculator.suggestDefaultLifeStage(birthday: birthday, now: now),
        DogLifeStage.adult,
      );
    });
  });
}
