import 'package:atm_flutter/l10n/app_localizations.dart';
import 'package:atm_flutter/models/replay_data.dart';
import 'package:atm_flutter/screens/unity_replay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('replay score breakdown is localized in Chinese', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UnityReplayScreen(replayData: _sampleReplay()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Safe separation maintained'), findsNothing);
    expect(find.textContaining('Correct aircraft selected'), findsNothing);
    expect(find.textContaining('保持间隔'), findsOneWidget);
    expect(find.textContaining('航空器选择正确'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

ScenarioReplayData _sampleReplay() {
  const initial = AircraftReplayState(
    callsign: 'QFA123',
    x: 80,
    y: 300,
    heading: 45,
    speed: 250,
    altitude: 32000,
    wasSelected: true,
    wasConflicting: true,
  );
  const finalState = AircraftReplayState(
    callsign: 'QFA123',
    x: 120,
    y: 270,
    heading: 30,
    speed: 230,
    altitude: 32000,
    wasSelected: true,
    wasConflicting: true,
  );
  return const ScenarioReplayData(
    scenarioId: 'test',
    scenarioTitle: 'Test',
    initialAircraft: [initial],
    finalAircraft: [finalState],
    conflictPairCallsigns: ['QFA123', 'UAE406'],
    closestPointPxX: 185,
    closestPointPxY: 215,
    closestPointTimeSec: 3,
    thresholdHorizontalPx: 60,
    thresholdVerticalFt: 1000,
    actionTimeSec: 2,
    userCommandSummary: '对 QFA123 执行减速',
    minHorizDist: 250,
    hadLOS: false,
    score: 100,
    ratingKey: 'ratingSafe',
    penaltyBreakdown: ['None'],
    bonusBreakdown: [
      'Safe separation maintained: +10',
      'Correct aircraft selected: +10',
    ],
  );
}
