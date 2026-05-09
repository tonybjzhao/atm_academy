import 'dart:io';

import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_expectation_state.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/scenario_pressure_phase.dart';
import 'package:atm_flutter/features/radar_v2/radar_v2_debug_screen.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_loader.dart';
import 'package:atm_flutter/features/radar_v2/scoring/radar_v2_score.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_catalog.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_beta_screen.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_briefing_screen.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_progress_store.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_result.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Radar Training Beta', () {
    test('scenario list exposes exactly three polished scenarios', () {
      const scenarios = RadarTrainingCatalog.scenarios;

      expect(scenarios, hasLength(3));
      expect(
        scenarios.map((scenario) => scenario.title),
        containsAll([
          'Beginner Crossing Conflict',
          'Arrival Spacing Under Weather',
          'False Recovery / Tunnel Vision',
        ]),
      );
    });

    test('briefing data exists for every scenario', () {
      for (final scenario in RadarTrainingCatalog.scenarios) {
        expect(scenario.objective, isNotEmpty);
        expect(scenario.trafficSituation, isNotEmpty);
        expect(scenario.expectedTechnique, isNotEmpty);
        expect(scenario.riskFactors, isNotEmpty);
        expect(scenario.successCriteria, isNotEmpty);
      }
    });

    test('scenario assets load through the V2 scenario loader', () {
      const loader = ScenarioLoader();

      for (final scenario in RadarTrainingCatalog.scenarios) {
        final source = File(scenario.assetPath).readAsStringSync();
        final definition = loader.parse(source);

        expect(definition.title, isNotEmpty);
        expect(definition.aircraft, isNotEmpty);
        expect(definition.winConditions, isNotEmpty);
      }
    });

    test('result summary is generated from final score and snapshot', () {
      final result = RadarTrainingResultBuilder.build(
        scenarioTitle: 'Test Scenario',
        scenarioId: 'test_scenario',
        score: const RadarV2ScoreSnapshot(
          score: 82,
          commandCount: 5,
          separationLossCount: 0,
          lateResolutionCount: 1,
          spacingStability: 88,
          throughputEfficiency: 76,
          weatherManagement: 90,
          commandEfficiency: 95,
          anticipationScore: 72,
          lastDelta: 0,
          lastReason: null,
          penalties: [],
        ),
        snapshot: const SimulationSnapshot(
          tick: 1,
          elapsed: Duration(seconds: 130),
          aircraft: [],
          separation: [],
        ),
      );

      expect(result.score.grade, 'B');
      expect(result.replayExplanation, isNotEmpty);
      expect(result.topMistake, isNotEmpty);
      expect(result.bestRecovery, isNotEmpty);
      expect(result.timelineSummary, isNotEmpty);
    });

    test(
        'replay explanation includes attention, psychology and expectation lines',
        () {
      final explanation = RadarTrainingResultBuilder.buildReplayExplanation(
        SimulationSnapshot(
          tick: 1,
          elapsed: const Duration(seconds: 184),
          aircraft: [],
          separation: [],
          attentionFocus: const AttentionFocusState(
            reportLines: [
              'Tunnel vision detected while focusing on QFA214.',
            ],
          ),
          attentionReportLines: const [
            'Ignored critical alert for 21s.',
          ],
          psychologyState: const ScenarioPsychologyState(
            phase: ScenarioPressurePhase.unstable,
            pressureMultiplier: 1.4,
            eventDensityFactor: 1.1,
            alertTimingFactor: 0.8,
            spacingInstabilityProbability: 0.3,
            reportLines: [
              'Workload rose after weather deviation at 130s.',
            ],
          ),
          expectationState: ControllerExpectationState(
            runwayFlow: ControllerExpectationState.idle.runwayFlow,
            spacingStability: ControllerExpectationState.idle.spacingStability,
            aircraftSequencing:
                ControllerExpectationState.idle.aircraftSequencing,
            alertPatterns: ControllerExpectationState.idle.alertPatterns,
            weatherBehavior: ControllerExpectationState.idle.weatherBehavior,
            driftScore: 0.34,
            confirmationBiasActive: true,
            falseRecoveryActive: false,
            attentionAnchored: false,
            threatSensitivity: 0.74,
            driftLevel: MentalModelDriftLevel.biased,
            reportLines: [
              'Expectation drift occurred before spacing compression.',
            ],
          ),
        ),
      );

      expect(explanation.join(' '), contains('Ignored critical'));
      expect(explanation.join(' '), contains('weather deviation'));
      expect(explanation.join(' '), contains('Expectation drift'));
    });

    test('debug overlays are hidden by default in beta play mode', () {
      const screen = RadarV2DebugScreen(betaMode: true);

      expect(screen.betaMode, isTrue);
      expect(screen.showDebugOverlays, isFalse);
    });

    test('progress shell maps best scores to completion stars', () {
      expect(RadarTrainingProgress.starsForScore(0), 0);
      expect(RadarTrainingProgress.starsForScore(60), 1);
      expect(RadarTrainingProgress.starsForScore(76), 2);
      expect(RadarTrainingProgress.starsForScore(92), 3);
    });

    test('progress save and load persists best result and completions',
        () async {
      SharedPreferences.setMockInitialValues({});
      const store = RadarTrainingProgressStore();

      await store.saveResult(
        scenarioId: 'scenario_a',
        score: 78,
        grade: 'B',
      );
      await store.saveResult(
        scenarioId: 'scenario_a',
        score: 62,
        grade: 'C',
      );
      final progress = await store.load('scenario_a');

      expect(progress.bestScore, 78);
      expect(progress.bestGrade, 'B');
      expect(progress.completedCount, 2);
      expect(progress.stars, 2);
    });

    test('onboarding seen flag is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      const store = RadarTrainingProgressStore();

      expect(await store.shouldShowOnboarding(), isTrue);
      await store.markOnboardingSeen();

      expect(await store.shouldShowOnboarding(), isFalse);
    });

    test('result builder top mistake prioritizes separation loss', () {
      final mistake = RadarTrainingResultBuilder.buildTopMistake(
        const RadarV2ScoreSnapshot(
          score: 55,
          commandCount: 4,
          separationLossCount: 1,
          lateResolutionCount: 0,
          spacingStability: 40,
          throughputEfficiency: 70,
          weatherManagement: 80,
          commandEfficiency: 90,
          anticipationScore: 50,
          lastDelta: -25,
          lastReason: 'Separation loss',
          penalties: ['Separation loss'],
        ),
        const SimulationSnapshot(
          tick: 1,
          elapsed: Duration(seconds: 90),
          aircraft: [],
          separation: [],
        ),
      );

      expect(mistake, contains('Separation'));
    });

    test('replay moment extraction includes alerts and cognitive lines', () {
      final moments = RadarTrainingResultBuilder.buildReplayMoments(
        const SimulationSnapshot(
          tick: 1,
          elapsed: Duration(seconds: 160),
          aircraft: [],
          separation: [],
          events: [
            SimulationEvent(
              elapsed: Duration(seconds: 42),
              type: 'separationLoss',
              label: 'Separation warning',
            ),
          ],
          psychologyState: ScenarioPsychologyState(
            phase: ScenarioPressurePhase.overload,
            pressureMultiplier: 1.6,
            eventDensityFactor: 0.8,
            alertTimingFactor: 0.7,
            spacingInstabilityProbability: 0.3,
            reportLines: ['Peak overload occurred at 148s.'],
          ),
        ),
      );

      expect(moments.map((moment) => moment.type), contains('separationLoss'));
      expect(moments.map((moment) => moment.type), contains('overload'));
    });

    testWidgets('scenario list and briefing open for all 3 scenarios',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: RadarTrainingBetaScreen()),
      );
      await tester.pumpAndSettle();

      for (final scenario in RadarTrainingCatalog.scenarios) {
        expect(find.text('Radar Training Beta'), findsOneWidget);
        await tester.ensureVisible(find.text(scenario.title));
        expect(find.text(scenario.title), findsOneWidget);

        await tester.tap(find.text(scenario.title));
        await tester.pumpAndSettle();

        expect(find.text('Scenario Briefing'), findsOneWidget);
        expect(find.text(scenario.objective), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Start Scenario'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Start Scenario'), findsOneWidget);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('briefing start button triggers scenario start', (tester) async {
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RadarTrainingBriefingScreen(
            scenario: RadarTrainingCatalog.scenarios.first,
            onStart: () => started = true,
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Start Scenario'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Start Scenario'), findsOneWidget);
      await tester.tap(find.text('Start Scenario'));
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('progress stars update from persisted best score', (tester) async {
      SharedPreferences.setMockInitialValues({
        'radar_beta_best_score_beginner_crossing_conflict': 92,
        'radar_beta_best_grade_beginner_crossing_conflict': 'A',
        'radar_beta_completed_beginner_crossing_conflict': 1,
      });

      await tester.pumpWidget(
        const MaterialApp(home: RadarTrainingBetaScreen()),
      );
      await tester.pumpAndSettle();

      final firstTitle = RadarTrainingCatalog.scenarios.first.title;
      expect(find.text(firstTitle), findsOneWidget);
      expect(find.textContaining('Best A 92'), findsOneWidget);

      // Stars are rendered as icons; for score 92 we expect 3 filled stars.
      final starIcons = find.byIcon(Icons.star);
      expect(starIcons, findsWidgets);
    });

    testWidgets('friendly scenario-load error shows retry action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RadarV2DebugScreen(
            betaMode: true,
            initialScenarioName: 'Broken Scenario',
            scenarioAssets: {
              'Broken Scenario': 'assets/scenarios/v2/does_not_exist.json',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Scenario could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
