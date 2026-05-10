import 'package:atm_flutter/features/radar_v2/training/radar_training_result_screen.dart';
import 'package:atm_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RadarTrainingResultScreen shows fallback for missing result',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RadarTrainingResultScreen(result: null),
      ),
    );

    await tester.pump();

    expect(find.text('Scenario Result'), findsOneWidget);
    expect(
      find.text('No result data available. Please retry scenario.'),
      findsOneWidget,
    );
  });
}
