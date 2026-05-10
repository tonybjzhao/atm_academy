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

  testWidgets('ScenarioResultScreen debrief text is localized in Chinese',
      (tester) async {
    final result = ScoringEngine.mock();

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        home: ScenarioResultScreen(result: result),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('主要复盘'));
    await tester.pumpAndSettle();

    expect(find.textContaining('优秀'), findsNothing);
    expect(find.textContaining('Aircraft remained separated'), findsNothing);
    expect(find.textContaining('Select the aircraft'), findsNothing);
    expect(find.textContaining('Good control'), findsNothing);
    expect(find.textContaining('保持间隔'), findsWidgets);
    expect(find.textContaining('航空器已连续'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
