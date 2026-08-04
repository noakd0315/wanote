import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists an optional manual language override (PM request: default to
/// following the device's own language setting everywhere, but let the
/// sign-in screen and settings screen override it in-app -- e.g. so a
/// Shipaton judge can check the English UI without changing their device's
/// language).
///
/// [locale] is null by default, meaning "no override" -- MaterialApp's
/// `locale` param already falls back to system locale resolution when
/// passed null, so the "follow device setting" behavior needs no special
/// handling here.
class LocaleController extends ChangeNotifier {
  LocaleController({Future<SharedPreferences>? sharedPreferences})
    : _prefsFuture = sharedPreferences ?? SharedPreferences.getInstance() {
    _load();
  }

  static const _prefsKey = 'app.locale_override';

  final Future<SharedPreferences> _prefsFuture;

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  /// Pass null to clear the override and go back to following the device's
  /// own language setting.
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await _prefsFuture;
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}
