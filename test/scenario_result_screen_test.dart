import 'package:atm_flutter/l10n/app_localizations.dart';
import 'package:atm_flutter/screens/scenario_result_screen.dart';
import 'package:atm_flutter/services/scoring_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localizedApp({
  required Locale locale,
  required Widget home,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('ScenarioResultScreen localizes after dependencies are ready',
      (tester) async {
    final result = ScoringEngine.mock();

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        home: ScenarioResultScreen(result: result),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.byType(ScenarioResultScreen), findsOneWidget);

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        home: ScenarioResultScreen(result: result),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.byType(ScenarioResultScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
