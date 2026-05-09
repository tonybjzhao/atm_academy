import 'package:atm_flutter/features/radar_v2/training/radar_training_beta_screen.dart';
import 'package:atm_flutter/l10n/app_localizations.dart';
import 'package:atm_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Radar Training route visibility', () {
    test('Radar Training route exists when feature flag is enabled', () {
      final routes = buildAppRoutes(
        enableRadarTraining: true,
        enableDebugTools: false,
      );

      expect(routes, contains(kRadarTrainingRouteName));
    });

    test('Debug radar route is absent in release-like configuration', () {
      final routes = buildAppRoutes(
        enableRadarTraining: true,
        enableDebugTools: false,
      );

      expect(routes, isNot(contains(kRadarDebugRouteName)));
    });

    testWidgets('Radar Training screen opens in non-debug/internal mode',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox.shrink(),
          routes: buildAppRoutes(
            enableRadarTraining: true,
            enableDebugTools: false,
          ),
        ),
      );

      navigatorKey.currentState!.pushNamed(kRadarTrainingRouteName);
      await tester.pumpAndSettle();

      expect(find.byType(RadarTrainingBetaScreen), findsOneWidget);
    });
  });
}
