import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/daily_challenge_service.dart';
import 'services/language_service.dart';

final _languageService = LanguageService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _languageService.load();
  await DailyChallengeService.instance.load();
  runApp(const AtmAcademyApp());
}

class AtmAcademyApp extends StatelessWidget {
  const AtmAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _languageService.localeNotifier,
      builder: (context, locale, _) {
        final languageCode = locale?.languageCode ?? 'en';
        return MaterialApp(
          title: 'ATM Academy',
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: HomeScreen(
            languageService: _languageService,
            languageCode: languageCode,
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
