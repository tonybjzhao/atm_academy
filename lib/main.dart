import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/radar_v2/radar_v2_debug_screen.dart';
import 'features/radar_v2/radar_v2_feature_flags.dart';
import 'features/radar_v2/training/radar_training_beta_screen.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/daily_challenge_service.dart';
import 'services/language_service.dart';
import 'data/radar_levels.dart';
import 'models/radar_level_config.dart';
import 'screens/onboarding_screen.dart';
import 'services/progression_service.dart';

final _languageService = LanguageService();
final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the status bar transparent so the app draws behind it,
  // and keep the system navigation area aligned with the app background.
  // This avoids content being hidden behind a transparent nav bar without
  // needing SafeArea changes in every screen.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF07111E), // == AppTheme.background
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  RadarLevelConfig.setResolver(
      (n) => allLevels[(n - 1).clamp(0, allLevels.length - 1)]);
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
          routes: kDebugMode
              ? {
                  '/debug/radar-v2': (_) => const RadarV2DebugScreen(),
                  if (kRadarTrainingBetaEnabled)
                    '/debug/radar-training-beta': (_) =>
                        const RadarTrainingBetaScreen(),
                }
              : const {},
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
