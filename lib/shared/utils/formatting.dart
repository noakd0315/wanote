import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Dates and measurements written the way the reader expects them.
///
/// Both used to be fixed: `yyyy/MM/dd` everywhere and kilograms everywhere.
/// Neither is wrong in Japan and both are wrong in most of the English-
/// speaking world, where a date reads month-first and a dog's weight is
/// given in pounds. The app is entered into Shipaton, so English speakers
/// are not a hypothetical audience.
///
/// Only the display changes. Weights are stored, computed and sent to the
/// backend in kilograms exactly as before -- a stored unit that depends on
/// who was looking at the time is a bug waiting to happen, and the records
/// outlive any one language setting.
String _localeOf(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// e.g. `2026/08/14` in Japanese, `8/14/2026` in English.
String formatDate(BuildContext context, DateTime value) =>
    DateFormat.yMd(_localeOf(context)).format(value);

/// The same, with the time of day.
String formatDateTime(BuildContext context, DateTime value) =>
    DateFormat.yMd(_localeOf(context)).add_Hm().format(value);

/// Day and month only, for chart axes where the year is implied.
String formatShortDate(BuildContext context, DateTime value) =>
    DateFormat.Md(_localeOf(context)).format(value);

/// Time of day alone.
String formatTime(BuildContext context, DateTime value) =>
    DateFormat.Hm(_localeOf(context)).format(value);

/// Whether this reader expects pounds rather than kilograms.
///
/// Language, not country: the app has no country to go on, and the language
/// picker is the only statement the owner has made about how they want to
/// read things.
bool usesImperialWeight(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en';

const double _poundsPerKilogram = 2.2046226218;
const double _ouncesPerGram = 0.0352739619;

double kilogramsToPounds(double kg) => kg * _poundsPerKilogram;

double poundsToKilograms(double lb) => lb / _poundsPerKilogram;

double gramsToOunces(double grams) => grams * _ouncesPerGram;

/// A weight with its unit, converted for display.
///
/// [kilograms] is always the stored value; what comes back may be pounds.
String formatWeight(BuildContext context, double kilograms, {int digits = 1}) {
  if (usesImperialWeight(context)) {
    return '${kilogramsToPounds(kilograms).toStringAsFixed(digits)} lb';
  }
  return '${kilograms.toStringAsFixed(digits)} kg';
}

/// A food quantity, converted for display. Grams are the stored unit.
String formatFoodQuantity(BuildContext context, double grams) {
  if (usesImperialWeight(context)) {
    return '${gramsToOunces(grams).toStringAsFixed(1)} oz';
  }
  return '${grams.round()} g';
}

/// The unit a weight input is asking for, so its label and its parsing
/// cannot drift apart.
String weightInputUnit(BuildContext context) =>
    usesImperialWeight(context) ? 'lb' : 'kg';

/// Reads a weight the owner typed in whichever unit the field is showing,
/// and returns kilograms. Null when the text is not a positive number.
double? parseWeightToKilograms(BuildContext context, String text) {
  final value = double.tryParse(text.trim());
  if (value == null || value <= 0) return null;
  return usesImperialWeight(context) ? poundsToKilograms(value) : value;
}

/// Renders a stored weight into the unit the input field expects, for
/// pre-filling it. The inverse of [parseWeightToKilograms].
String weightInputText(BuildContext context, double? kilograms) {
  if (kilograms == null) return '';
  final shown = usesImperialWeight(context)
      ? kilogramsToPounds(kilograms)
      : kilograms;
  // Trailing zeros removed: "12" reads better than "12.0" in a field the
  // owner is about to edit.
  final text = shown.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
