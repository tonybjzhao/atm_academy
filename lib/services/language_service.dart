import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const _key = 'selected_locale';

  final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      localeNotifier.value = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    localeNotifier.value = locale;
  }

  Future<void> clearLocale() async {
    await setLocale(null);
  }
}
