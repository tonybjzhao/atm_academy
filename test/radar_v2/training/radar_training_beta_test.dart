import 'dart:io';

import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/cognitive_cascade_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_expectation_state.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/scenario_pressure_phase.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/arrival_flow.dart';
import 'package:atm_flutter/features/radar_v2/models/departure_flow.dart';
import 'package:atm_flutter/features/radar_v2/radar_v2_debug_screen.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_loader.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_runtime.dart';
import 'package:atm_flutter/features/radar_v2/scoring/radar_v2_score.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_catalog.dart';
import 'package:atm_flutter/features/radar_v2/training/cognitive_cascade_propagation.dart';
import 'package:atm_flutter/features/radar_v2/training/cognitive_timeline.dart';
import 'package:atm_flutter/features/radar_v2/training/debrief_insight.dart';
import 'package:atm_flutter/features/radar_v2/training/debrief_salience_engine.dart';
import 'package:atm_flutter/features/radar_v2/training/environmental_pressure_ecology.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_beta_screen.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_briefing_screen.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_progress_store.dart';
import 'package:atm_flutter/features/radar_v2/training/radar_training_result.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_event.dart';
import 'package:atm_flutter/features/radar_v2/models/weather_zone.dart';
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
          'Melbourne Storm Arrival Rush',
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

    test('Melbourne Storm Arrival Rush briefing is polished', () {
      final scenario =
          RadarTrainingCatalog.byId('melbourne_storm_arrival_rush');

      expect(scenario.title, 'Melbourne Storm Arrival Rush');
      expect(scenario.objective, contains('arrival compression'));
      expect(scenario.trafficSituation, contains('storm'));
      expect(scenario.expectedTechnique, contains('broad scan'));
      expect(scenario.riskFactors, hasLength(greaterThanOrEqualTo(4)));
      expect(scenario.successCriteria, contains('No separation loss'));
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

    test('Melbourne Storm Arrival Rush scenario loads with ecology inputs', () {
      const loader = ScenarioLoader();
      final scenario =
          RadarTrainingCatalog.byId('melbourne_storm_arrival_rush');
      final source = File(scenario.assetPath).readAsStringSync();
      final definition = loader.parse(source);

      expect(definition.title, 'Melbourne Storm Arrival Rush');
      expect(definition.weatherZones, isNotEmpty);
      expect(definition.arrivalFlows, isNotEmpty);
      expect(definition.departureFlows, isNotEmpty);
      expect(definition.attentionManagementEvents, isNotEmpty);
      expect(definition.aircraft, hasLength(greaterThanOrEqualTo(6)));
    });

    test('Melbourne Storm Arrival Rush result builds with replay systems', () {
      const loader = ScenarioLoader();
      final scenario =
          RadarTrainingCatalog.byId('melbourne_storm_arrival_rush');
      final definition =
          loader.parse(File(scenario.assetPath).readAsStringSync());
      final runtime = ScenarioRuntime(definition: definition);
      for (var i = 0; i < 230; i++) {
        runtime.tick();
      }

      final result = RadarTrainingResultBuilder.build(
        scenarioTitle: scenario.title,
        scenarioId: scenario.id,
        score: const RadarV2ScoreSnapshot(
          score: 72,
          commandCount: 8,
          separationLossCount: 0,
          lateResolutionCount: 1,
          spacingStability: 60,
          throughputEfficiency: 72,
          weatherManagement: 66,
          commandEfficiency: 70,
          anticipationScore: 58,
          lastDelta: -5,
          lastReason: 'Late resolution',
          penalties: ['Late resolution'],
          totalOverloadDuration: Duration(seconds: 20),
        ),
        snapshot: runtime.tick(),
      );

      expect(result.replayExplanation, isNotEmpty);
      expect(
          result.debriefSalience.primaryInsights.length, lessThanOrEqualTo(3));
      expect(
        result.environmentalEcology.windows.map((window) => window.source),
        containsAll([
          EnvironmentalPressureSource.arrivalWave,
          EnvironmentalPressureSource.weatherReroute,
        ]),
      );
    });

    test('beginner crossing conflict remains playable with aircraft realism',
        () {
      const loader = ScenarioLoader();
      final scenario = RadarTrainingCatalog.byId('beginner_crossing_conflict');
      final definition =
          loader.parse(File(scenario.assetPath).readAsStringSync());
      final runtime = ScenarioRuntime(definition: definition);

      SimulationSnapshot snapshot = runtime.tick();
      for (var i = 0; i < 90; i++) {
        snapshot = runtime.tick();
      }
      final result = RadarTrainingResultBuilder.build(
        scenarioTitle: scenario.title,
        scenarioId: scenario.id,
        score: const RadarV2ScoreSnapshot(
          score: 80,
          commandCount: 4,
          separationLossCount: 0,
          lateResolutionCount: 0,
          spacingStability: 82,
          throughputEfficiency: 78,
          weatherManagement: 90,
          commandEfficiency: 84,
          anticipationScore: 70,
          lastDelta: 0,
          lastReason: null,
          penalties: [],
        ),
        snapshot: snapshot,
      );

      expect(snapshot.aircraft, isNotEmpty);
      expect(result.replayExplanation, isNotEmpty);
      expect(
          result.debriefSalience.primaryInsights.length, lessThanOrEqualTo(3));
    });

    test('false recovery tunnel vision remains playable with aircraft realism',
        () {
      const loader = ScenarioLoader();
      final scenario =
          RadarTrainingCatalog.byId('false_recovery_tunnel_vision');
      final definition =
          loader.parse(File(scenario.assetPath).readAsStringSync());
      final runtime = ScenarioRuntime(definition: definition);

      SimulationSnapshot snapshot = runtime.tick();
      for (var i = 0; i < 150; i++) {
        snapshot = runtime.tick();
      }
      final result = RadarTrainingResultBuilder.build(
        scenarioTitle: scenario.title,
        scenarioId: scenario.id,
        score: const RadarV2ScoreSnapshot(
          score: 74,
          commandCount: 6,
          separationLossCount: 0,
          lateResolutionCount: 1,
          spacingStability: 70,
          throughputEfficiency: 72,
          weatherManagement: 68,
          commandEfficiency: 76,
          anticipationScore: 66,
          lastDelta: -5,
          lastReason: 'Late resolution',
          penalties: ['Late resolution'],
          totalOverloadDuration: Duration(seconds: 12),
        ),
        snapshot: snapshot,
      );

      expect(snapshot.aircraft, isNotEmpty);
      expect(result.replayExplanation, isNotEmpty);
      expect(result.timelineSummary, isNotEmpty);
    });

    test('Storm Arrival Rush produces meaningful operational replay lines', () {
      const loader = ScenarioLoader();
      final scenario =
          RadarTrainingCatalog.byId('melbourne_storm_arrival_rush');
      final definition =
          loader.parse(File(scenario.assetPath).readAsStringSync());
      final runtime = ScenarioRuntime(definition: definition);
      SimulationSnapshot snapshot = runtime.tick();
      for (var i = 0; i < 260; i++) {
        snapshot = runtime.tick();
      }

      final explanation =
          RadarTrainingResultBuilder.buildReplayExplanation(snapshot).join(' ');

      expect(
        explanation,
        anyOf(
          contains('Weather compression'),
          contains('Late speed control'),
          contains('Runway occupancy extended'),
          contains('Pilot response delay'),
        ),
      );
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

    test('replay explanation includes operational behavior lines', () {
      final explanation = RadarTrainingResultBuilder.buildReplayExplanation(
        const SimulationSnapshot(
          tick: 1,
          elapsed: Duration(seconds: 120),
          aircraft: [],
          separation: [],
          events: [
            SimulationEvent(
              elapsed: Duration(seconds: 80),
              type: 'weatherCompression',
              label:
                  'Weather compression reduced spacing stability near the merge.',
            ),
            SimulationEvent(
              elapsed: Duration(seconds: 96),
              type: 'lateSpeedControl',
              label: 'Late speed control allowed closure rate to build.',
            ),
          ],
        ),
      );

      expect(explanation.join(' '), contains('Weather compression'));
      expect(explanation.join(' '), contains('Late speed control'));
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

    testWidgets('briefing start button triggers scenario start',
        (tester) async {
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

    testWidgets('progress stars update from persisted best score',
        (tester) async {
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

    testWidgets('friendly scenario-load error shows retry action',
        (tester) async {
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

  group('Debrief salience filter', () {
    const engine = DebriefSalienceEngine();

    test('highest severity insight appears first', () {
      final result = engine.rankInsights([
        _insight(
          id: 'medium',
          body: 'Command count was higher than ideal.',
          severity: DebriefInsightSeverity.medium,
        ),
        _insight(
          id: 'critical',
          title: 'Separation Risk',
          body: 'Separation loss occurred at T+82s.',
          severity: DebriefInsightSeverity.critical,
          category: DebriefInsightCategory.safety,
        ),
      ]);

      expect(result.primaryInsights.first.id, 'critical');
    });

    test('duplicate insights are merged', () {
      final result = engine.rankInsights([
        _insight(
          id: 'a',
          title: 'Ignored Alert',
          body: 'Critical alert ignored for 21s.',
          severity: DebriefInsightSeverity.high,
        ),
        _insight(
          id: 'b',
          title: 'Ignored Alert',
          body: 'Critical alert ignored for 22s.',
          severity: DebriefInsightSeverity.high,
        ),
      ]);

      expect(
        [
          ...result.primaryInsights,
          ...result.secondaryInsights,
          ...result.hiddenInsights,
        ],
        hasLength(1),
      );
    });

    test('only top 3 primary insights are shown', () {
      final result = engine.rankInsights([
        _insight(
          id: 'safety-separation',
          title: 'Separation Risk',
          body: 'Separation loss occurred at T+42s.',
          severity: DebriefInsightSeverity.critical,
          category: DebriefInsightCategory.safety,
        ),
        _insight(
          id: 'safety-runway',
          title: 'Runway Flow Risk',
          body: 'Runway occupancy alert ignored at T+51s.',
          severity: DebriefInsightSeverity.high,
          category: DebriefInsightCategory.safety,
        ),
        _insight(
          id: 'safety-overload',
          title: 'Workload Spike',
          body: 'Overload spike compressed arrival sequencing at T+64s.',
          severity: DebriefInsightSeverity.high,
          category: DebriefInsightCategory.workload,
        ),
        for (var i = 0; i < 3; i++)
          _insight(
            id: 'attention-$i',
            title: 'Attention $i',
            body: 'Attention scan warning $i at T+${80 + i}s.',
            severity: DebriefInsightSeverity.high,
            category: DebriefInsightCategory.attention,
          ),
      ]);

      expect(result.primaryInsights, hasLength(3));
      expect(result.secondaryInsights, isNotEmpty);
    });

    test('low-confidence insights go to details', () {
      final result = engine.rankInsights([
        _insight(
          id: 'low-confidence',
          body: 'Trait profile may have contributed to scan narrowing.',
          severity: DebriefInsightSeverity.high,
          confidence: 0.32,
        ),
        _insight(
          id: 'strong',
          body: 'Runway occupancy alert ignored for 18s.',
          severity: DebriefInsightSeverity.high,
          category: DebriefInsightCategory.safety,
        ),
      ]);

      expect(
        result.primaryInsights.map((insight) => insight.id),
        isNot(contains('low-confidence')),
      );
      expect(
        result.secondaryInsights.map((insight) => insight.id),
        contains('low-confidence'),
      );
    });

    test('trait-scenario lines do not overwhelm safety-critical lines', () {
      final result = engine.rank(
        traitScenarioReports: [
          'Trait profile amplified cascade propagation.',
          'Trait handled well under pressure.',
          'Recovery tendency delayed recovery initiation.',
        ],
        attentionReports: [
          'Critical alert ignored for 21s while scanning narrowed.',
        ],
      );

      expect(
          result.primaryInsights.first.category, DebriefInsightCategory.safety);
      expect(
        result.primaryInsights.map((insight) => insight.sourceSystem),
        isNot(everyElement('trait-scenario')),
      );
    });
  });

  group('Cognitive timeline visualizer data', () {
    test('builds operational layers for cognitive replay', () {
      final result = _timelineResult();
      final timeline = const CognitiveTimelineBuilder().build(result);

      expect(timeline.layers, hasLength(9));
      expect(
        timeline.layers.map((layer) => layer.type),
        containsAll([
          CognitiveTimelineLayerType.workload,
          CognitiveTimelineLayerType.attentionQuality,
          CognitiveTimelineLayerType.workingMemory,
          CognitiveTimelineLayerType.surpriseLoad,
          CognitiveTimelineLayerType.fixation,
          CognitiveTimelineLayerType.scanBlind,
          CognitiveTimelineLayerType.recovery,
          CognitiveTimelineLayerType.expectationConfidence,
          CognitiveTimelineLayerType.selfAssessment,
        ]),
      );
    });

    test('extracts replay event markers for warnings and cascade onset', () {
      final result = _timelineResult();
      final timeline = const CognitiveTimelineBuilder().build(result);

      expect(
        timeline.markers.map((marker) => marker.type),
        containsAll([
          CognitiveTimelineEventType.separationWarning,
          CognitiveTimelineEventType.cascadeOnset,
        ]),
      );
    });

    test('primary debrief insights highlight timeline regions', () {
      final result = _timelineResult();
      final timeline = const CognitiveTimelineBuilder().build(result);

      expect(result.debriefSalience.primaryInsights, isNotEmpty);
      expect(timeline.salienceRegions, isNotEmpty);
      expect(
        timeline.markers.where(
          (marker) => marker.type == CognitiveTimelineEventType.salience,
        ),
        isNotEmpty,
      );
    });
  });

  group('Cognitive cascade propagation view data', () {
    test('builds a linked propagation graph from replay degradation cues', () {
      final result = _timelineResult();
      final data = const CognitiveCascadePropagationBuilder().build(result);

      expect(data.chains, isNotEmpty);
      expect(
          data.chains.first.nodes.map((node) => node.type),
          containsAll([
            CascadePropagationNodeType.fixation,
            CascadePropagationNodeType.scanNeglect,
            CascadePropagationNodeType.missedConflict,
            CascadePropagationNodeType.recoveryBreakdown,
          ]));
      expect(data.chains.first.edges, isNotEmpty);
    });

    test('cascade nodes are linked to replay timestamps', () {
      final data = const CognitiveCascadePropagationBuilder().build(
        _timelineResult(),
      );

      expect(
        data.chains.first.nodes.every(
          (node) => node.timestamp >= Duration.zero,
        ),
        isTrue,
      );
    });

    test('parallel chain summaries produce additional chains', () {
      final data = const CognitiveCascadePropagationBuilder().build(
        _parallelCascadeResult(),
      );

      expect(data.chains.length, greaterThan(1));
      expect(data.chains.last.title, contains('Parallel chain'));
    });

    test('edges include explainability text', () {
      final data = const CognitiveCascadePropagationBuilder().build(
        _timelineResult(),
      );

      expect(data.chains.first.edges.first.explanation, isNotEmpty);
      expect(data.chains.first.edges.first.confidence, greaterThan(0));
    });

    test('missed conflict can have competing inferred causes', () {
      final data = const CognitiveCascadePropagationBuilder().build(
        _timelineResult(),
      );
      final missedConflictEdges = data.chains.first.edges.where(
        (edge) => edge.toNodeId == 'missed-conflict',
      );

      expect(missedConflictEdges.length, greaterThan(1));
      expect(
        missedConflictEdges.map((edge) => edge.contributionStrength),
        everyElement(greaterThan(0)),
      );
    });

    test('recovery interruption weakens downstream confidence', () {
      final data = const CognitiveCascadePropagationBuilder().build(
        _recoveryInterruptedResult(),
      );
      final weakenedEdge = data.chains.first.edges.firstWhere(
        (edge) => edge.evidenceFactors.any(
          (factor) => factor.contains('recovery interruption'),
        ),
      );

      expect(weakenedEdge.confidence, lessThan(0.8));
      expect(
        weakenedEdge.explanation,
        contains('weakens this inference'),
      );
    });

    test('edge explanations preserve probabilistic wording', () {
      final data = const CognitiveCascadePropagationBuilder().build(
        _timelineResult(),
      );

      expect(
        data.chains.first.edges.map((edge) => edge.explanation).join(' '),
        anyOf(contains('likely contributed'), contains('Evidence suggests')),
      );
    });
  });

  group('Environmental pressure ecology', () {
    test('detects traffic rhythm and synchronized operational pressure', () {
      final ecology = const EnvironmentalPressureEcologyBuilder().build(
        snapshot: _ecologySnapshot(),
        score: const RadarV2ScoreSnapshot(
          score: 66,
          commandCount: 7,
          separationLossCount: 0,
          lateResolutionCount: 1,
          spacingStability: 52,
          throughputEfficiency: 68,
          weatherManagement: 70,
          commandEfficiency: 74,
          anticipationScore: 56,
          lastDelta: -5,
          lastReason: 'Late resolution',
          penalties: ['Late resolution'],
          totalOverloadDuration: Duration(seconds: 24),
        ),
      );

      expect(
        ecology.windows.map((window) => window.source),
        containsAll([
          EnvironmentalPressureSource.arrivalWave,
          EnvironmentalPressureSource.departureCompression,
          EnvironmentalPressureSource.weatherReroute,
          EnvironmentalPressureSource.synchronizedStressors,
        ]),
      );
      expect(ecology.synchronizedRisk, greaterThan(0.45));
    });

    test('explains why pressure emerged operationally', () {
      final result = RadarTrainingResultBuilder.build(
        scenarioTitle: 'Ecology Scenario',
        scenarioId: 'ecology',
        score: const RadarV2ScoreSnapshot(
          score: 61,
          commandCount: 8,
          separationLossCount: 0,
          lateResolutionCount: 1,
          spacingStability: 48,
          throughputEfficiency: 62,
          weatherManagement: 66,
          commandEfficiency: 70,
          anticipationScore: 52,
          lastDelta: -5,
          lastReason: 'Late resolution',
          penalties: ['Late resolution'],
          totalOverloadDuration: Duration(seconds: 18),
        ),
        snapshot: _ecologySnapshot(),
      );

      expect(result.environmentalEcology.reportLines.join(' '),
          contains('Arrival compression'));
      expect(result.debriefSalience.primaryInsights, isNotEmpty);
    });

    test('detects attention traps and latent conflict ecology', () {
      final ecology = const EnvironmentalPressureEcologyBuilder().build(
        snapshot: _ecologySnapshot(),
        score: const RadarV2ScoreSnapshot(
          score: 58,
          commandCount: 9,
          separationLossCount: 1,
          lateResolutionCount: 1,
          spacingStability: 44,
          throughputEfficiency: 58,
          weatherManagement: 64,
          commandEfficiency: 62,
          anticipationScore: 48,
          lastDelta: -25,
          lastReason: 'Separation loss',
          penalties: ['Separation loss'],
        ),
      );

      expect(
        ecology.windows.map((window) => window.source),
        containsAll([
          EnvironmentalPressureSource.attentionTrap,
          EnvironmentalPressureSource.latentConflict,
        ]),
      );
    });
  });
}

DebriefInsight _insight({
  required String id,
  String title = 'Training Insight',
  required String body,
  DebriefInsightCategory category = DebriefInsightCategory.attention,
  DebriefInsightSeverity severity = DebriefInsightSeverity.medium,
  double confidence = 0.82,
}) {
  return DebriefInsight(
    id: id,
    title: title,
    body: body,
    category: category,
    severity: severity,
    timestamp: null,
    confidence: confidence,
    sourceSystem: category.name,
  );
}

RadarTrainingResult _timelineResult() {
  return RadarTrainingResultBuilder.build(
    scenarioTitle: 'Timeline Scenario',
    scenarioId: 'timeline_scenario',
    score: const RadarV2ScoreSnapshot(
      score: 58,
      commandCount: 9,
      separationLossCount: 1,
      lateResolutionCount: 1,
      spacingStability: 48,
      throughputEfficiency: 62,
      weatherManagement: 70,
      commandEfficiency: 65,
      anticipationScore: 42,
      lastDelta: -25,
      lastReason: 'Separation loss',
      penalties: ['Separation loss', 'Late resolution'],
      totalOverloadDuration: Duration(seconds: 38),
      ignoredCriticalAlertCount: 1,
    ),
    snapshot: const SimulationSnapshot(
      tick: 1,
      elapsed: Duration(seconds: 180),
      aircraft: [],
      separation: [],
      events: [
        SimulationEvent(
          elapsed: Duration(seconds: 42),
          type: 'attentionFixationWindow',
          label: 'Fixation window detected.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 58),
          type: 'attentionScanBlind',
          label: 'Scan blind period opened.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 62),
          type: 'workingMemoryInterrupted',
          label: 'Sequencing task was interrupted.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 66),
          type: 'expectationMismatch',
          label: 'Expectation mismatch appeared before conflict.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 72),
          type: 'separationWarning',
          label: 'Separation warning developed.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 96),
          type: 'cognitiveCascadeChain',
          label: 'Cascade onset after spacing compression.',
        ),
      ],
      attentionFocus: AttentionFocusState(
        scanCoverageQuality: 0.42,
        fixationWindowCount: 1,
        scanBlindDuration: Duration(seconds: 18),
        reportLines: ['Critical alert ignored for 21s.'],
      ),
      attentionReportLines: ['Critical alert ignored for 21s.'],
    ),
  );
}

RadarTrainingResult _recoveryInterruptedResult() {
  return RadarTrainingResultBuilder.build(
    scenarioTitle: 'Recovery Interruption Scenario',
    scenarioId: 'recovery_interruption',
    score: const RadarV2ScoreSnapshot(
      score: 52,
      commandCount: 8,
      separationLossCount: 1,
      lateResolutionCount: 1,
      spacingStability: 44,
      throughputEfficiency: 58,
      weatherManagement: 70,
      commandEfficiency: 62,
      anticipationScore: 40,
      lastDelta: -25,
      lastReason: 'Separation loss',
      penalties: ['Separation loss'],
      totalOverloadDuration: Duration(seconds: 34),
    ),
    snapshot: const SimulationSnapshot(
      tick: 1,
      elapsed: Duration(seconds: 120),
      aircraft: [],
      separation: [],
      events: [
        SimulationEvent(
          elapsed: Duration(seconds: 24),
          type: 'attentionScanBlind',
          label: 'Scan blind period opened.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 48),
          type: 'metaSuccessfulRecovery',
          label: 'Recovery action briefly stabilized flow.',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 86),
          type: 'separationWarning',
          label: 'Separation warning returned after recovery.',
        ),
      ],
      attentionFocus: AttentionFocusState(
        scanCoverageQuality: 0.48,
        scanBlindDuration: Duration(seconds: 24),
      ),
    ),
  );
}

RadarTrainingResult _parallelCascadeResult() {
  return RadarTrainingResultBuilder.build(
    scenarioTitle: 'Parallel Cascade Scenario',
    scenarioId: 'parallel_cascade',
    score: const RadarV2ScoreSnapshot(
      score: 64,
      commandCount: 7,
      separationLossCount: 0,
      lateResolutionCount: 1,
      spacingStability: 62,
      throughputEfficiency: 68,
      weatherManagement: 72,
      commandEfficiency: 78,
      anticipationScore: 58,
      lastDelta: -5,
      lastReason: 'Late resolution',
      penalties: ['Late resolution'],
    ),
    snapshot: const SimulationSnapshot(
      tick: 1,
      elapsed: Duration(seconds: 210),
      aircraft: [],
      separation: [],
      cognitiveCascadeState: CognitiveCascadeState(
        chainHistory: [
          CascadeChainSummary(
            chainId: 'chain-a',
            rootMismatchId: 'm1',
            rootLabel: 'Unexpected weather deviation',
            startedAt: Duration(seconds: 80),
            secondaryFailures: [
              'scan neglect',
              'working memory pressure',
            ],
            amplification: 0.72,
          ),
        ],
      ),
    ),
  );
}

SimulationSnapshot _ecologySnapshot() {
  return const SimulationSnapshot(
    tick: 1,
    elapsed: Duration(seconds: 210),
    aircraft: [
      AircraftState(
        id: 'a1',
        callsign: 'QFA214',
        xNm: -18,
        yNm: 12,
        altitudeFt: 6000,
        headingDeg: 90,
        groundSpeedKt: 250,
      ),
      AircraftState(
        id: 'a2',
        callsign: 'VOZ431',
        xNm: -10,
        yNm: 8,
        altitudeFt: 6000,
        headingDeg: 110,
        groundSpeedKt: 220,
      ),
    ],
    separation: [],
    weatherZones: [
      WeatherZone(id: 'wx1', xNm: 4, yNm: 4, radiusNm: 8, severity: 3),
    ],
    arrivalFlows: [
      ArrivalFlow(
        id: 'arrivals',
        runwayId: 'RWY16',
        mergeWaypointId: 'MERGE',
        finalFixWaypointId: 'FINAL',
        thresholdWaypointId: 'THR',
        spacingTargetNm: 5,
        stabilizedAltitudeFt: 3000,
      ),
    ],
    departureFlows: [
      DepartureFlow(
        id: 'deps',
        runwayId: 'RWY16',
        sidProcedureId: 'SID16',
        releaseIntervalSeconds: 40,
      ),
    ],
    events: [
      SimulationEvent(
        elapsed: Duration(seconds: 20),
        type: 'sectorEntry',
        label: 'QFA214 sector entry',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 36),
        type: 'sectorEntry',
        label: 'VOZ431 sector entry',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 52),
        type: 'sectorEntry',
        label: 'JST908 sector entry',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 68),
        type: 'departureQueued',
        label: 'RXA33 queued for departure',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 86),
        type: 'departureReleased',
        label: 'RXA33 departure released',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 110),
        type: 'expectationMismatch',
        label: 'Ambiguous trajectory mismatch before spacing compression',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 124),
        type: 'separationWarning',
        label: 'Delayed conflict alert surfaced',
      ),
      SimulationEvent(
        elapsed: Duration(seconds: 145),
        type: 'metaRecoveryAction',
        label: 'Recovery command issued',
      ),
    ],
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: 6.8,
      currentLevel: CognitiveLoadLevel.overloaded,
      activeStressors: ['arrival compression', 'weather reroute'],
      recentSpikes: [],
    ),
    attentionFocus: AttentionFocusState(
      currentFocusTarget: 'aircraft:QFA214',
      scanCoverageQuality: 0.46,
      fixationWindowCount: 1,
      ignoredAlerts: [],
    ),
  );
}
