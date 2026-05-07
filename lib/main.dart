import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/daily_challenge_service.dart';
import 'services/language_service.dart';
import 'data/radar_levels.dart';
import 'models/radar_level_config.dart';
import 'screens/onboarding_screen.dart';
import 'services/progression_service.dart';

final _languageService  = LanguageService();
final _navigatorKey     = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  RadarLevelConfig.setResolver((n) => allLevels[(n - 1).clamp(0, allLevels.length - 1)]);
  await _languageService.load();
  await DailyChallengeService.instance.load();
  await ProgressionService.instance.load();
  final showOnboarding = !(await hasSeenOnboarding());
  runApp(AtmAcademyApp(showOnboarding: showOnboarding));
}

class AtmAcademyApp extends StatelessWidget {
  final bool showOnboarding;
  const AtmAcademyApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _languageService.localeNotifier,
      builder: (context, locale, _) {
        final languageCode = locale?.languageCode ?? 'en';
        final homeScreen = HomeScreen(
          languageService: _languageService,
          languageCode: languageCode,
        );
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
          home: showOnboarding
              ? OnboardingScreen(
                  onComplete: () => Navigator.of(
                    // Use a global key or push replacement via the navigator
                    // The simplest approach: replace via the root navigator
                    _navigatorKey.currentContext!,
                  ).pushReplacement(
                    MaterialPageRoute(builder: (_) => homeScreen),
                  ),
                )
              : homeScreen,
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
