import 'package:atm_flutter/features/radar_v2/training/radar_training_beta_screen.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_briefing_screen.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_catalog.dart';
import 'package:atm_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Radar Training i18n', () {
    const locales = [
      Locale('en'),
      Locale('zh'),
      Locale('fr'),
    ];

    testWidgets('all supported locales load for RadarTrainingBetaScreen',
        (tester) async {
      for (final locale in locales) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RadarTrainingBetaScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RadarTrainingBetaScreen), findsOneWidget);
        expect(find.textContaining('radarTraining'), findsNothing);
      }
    });

    testWidgets('briefing screen renders in all supported locales',
        (tester) async {
      for (final locale in locales) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return RadarTrainingBriefingScreen(
                  scenario: RadarTrainingCatalog.byIdLocalized(
                    'beginner_crossing_conflict',
                    l10n,
                  ),
                  onStart: () {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RadarTrainingBriefingScreen), findsOneWidget);
        expect(find.textContaining('radarTraining'), findsNothing);
      }
    });
  });
}
