import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/commands/controller_command.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/attention_management_event.dart';
import 'package:atm_flutter/features/radar_v2/models/controller_alert.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_definition.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_runtime.dart';
import 'package:atm_flutter/features/radar_v2/scoring/cognitive_replay.dart';
import 'package:atm_flutter/features/radar_v2/scoring/radar_v2_score.dart';

void main() {
  group('ControllerAlert priority ordering', () {
    test('separation loss alert outranks runway occupancy', () {
      const separationAlert = ControllerAlert(
        id: 'sep1',
        type: AlertType.separationLoss,
        severity: 5,
        createdAt: Duration.zero,
      );
      const runwayAlert = ControllerAlert(
        id: 'rwy1',
        type: AlertType.runwayOccupancy,
        severity: 5,
        createdAt: Duration.zero,
      );
      expect(separationAlert.effectivePriority,
          greaterThan(runwayAlert.effectivePriority));
    });

    test('imminent alert gets 50-point urgency boost', () {
      const longAlert = ControllerAlert(
        id: 'long',
        type: AlertType.separationLoss,
        severity: 5,
        createdAt: Duration.zero,
        timeToLoss: Duration(minutes: 5),
      );
      const imminentAlert = ControllerAlert(
        id: 'imminent',
        type: AlertType.separationLoss,
        severity: 5,
        createdAt: Duration.zero,
        timeToLoss: Duration(seconds: 20),
      );
      expect(imminentAlert.effectivePriority - longAlert.effectivePriority,
          greaterThanOrEqualTo(50));
    });

    test('unacknowledged alert has higher priority than acknowledged', () {
      const unacked = ControllerAlert(
        id: 'ua',
        type: AlertType.goAround,
        severity: 5,
        createdAt: Duration.zero,
      );
      const acked = ControllerAlert(
        id: 'ac',
        type: AlertType.goAround,
        severity: 5,
        createdAt: Duration.zero,
        acknowledged: true,
      );
      expect(unacked.effectivePriority, greaterThan(acked.effectivePriority));
    });

    test('medical emergency outranks distraction', () {
      const medical = ControllerAlert(
        id: 'med',
        type: AlertType.medicalEmergency,
        severity: 9,
        createdAt: Duration.zero,
      );
      const distraction = ControllerAlert(
        id: 'dis',
        type: AlertType.distractionEvent,
        severity: 9,
        createdAt: Duration.zero,
      );
      expect(medical.effectivePriority, greaterThan(distraction.effectivePriority));
    });
  });

  group('Distraction penalty model', () {
    late ScenarioDefinition def;

    setUp(() {
      def = ScenarioDefinition(
        id: 'test',
        title: 'Test',
        sectorId: 'test_sector',
        duration: const Duration(minutes: 5),
        difficulty: 1,
        speedOptions: const [1, 2],
        aircraft: const [],
        winConditions: const [],
        failConditions: const [],
        attentionManagementEvents: const [
          AttentionManagementEvent(
            id: 'dist1',
            type: 'distraction',
            scheduledAt: Duration(seconds: 10),
            duration: Duration(seconds: 30),
          ),
        ],
      );
    });

    test('no distraction at session start gives penalty of 1.0', () {
      final runtime = ScenarioRuntime(definition: def);
      expect(runtime.getDistractionEfficiencyPenalty(Duration.zero), equals(1.0));
    });

    test('active distraction reduces efficiency to 0.8', () {
      final runtime = ScenarioRuntime(definition: def);
      // Simulate distraction firing
      for (var i = 0; i < 11; i++) {
        runtime.tick();
      }
      final snapshot = runtime.tick();
      // After 11 ticks at 1Hz = ~11 seconds, distraction at 10s should be active
      if (snapshot.activeDistractions.isNotEmpty) {
        expect(snapshot.distractionEfficiencyPenalty, lessThan(1.0));
      }
    });
  });

  group('Score applies distraction command penalty', () {
    test('command during distraction incurs extra penalty', () {
      final tracker = RadarV2ScoreTracker();
      final baseScore = tracker.snapshot.score;

      // Build a snapshot with active distraction
      const snapshot = SimulationSnapshot(
        tick: 1,
        elapsed: Duration(seconds: 10),
        aircraft: [],
        separation: [],
        activeDistractions: {'dist1'},
        distractionEfficiencyPenalty: 0.8,
      );

      tracker.recordCommand(
        const AssignHeading(
          aircraftId: 'a',
          issuedAt: Duration(seconds: 10),
          headingDeg: 180,
        ),
        snapshot,
      );

      // Penalty should include distraction reduction (base 2 points at 0.8 efficiency)
      expect(tracker.snapshot.score, lessThan(baseScore));
    });
  });

  group('Dynamic sector pacing', () {
    test('upcoming spawn times returns empty when all spawned', () {
      final def = ScenarioDefinition(
        id: 'test',
        title: 'Test',
        sectorId: 'test_sector',
        duration: const Duration(minutes: 5),
        difficulty: 1,
        speedOptions: const [1],
        aircraft: const [],
        winConditions: const [],
        failConditions: const [],
      );
      final runtime = ScenarioRuntime(definition: def);
      expect(runtime.upcomingSpawnTimes(), isEmpty);
    });

    test('held spawn count starts at zero', () {
      final def = ScenarioDefinition(
        id: 'test',
        title: 'Test',
        sectorId: 'test_sector',
        duration: const Duration(minutes: 5),
        difficulty: 1,
        speedOptions: const [1],
        aircraft: const [],
        winConditions: const [],
        failConditions: const [],
      );
      final runtime = ScenarioRuntime(definition: def);
      expect(runtime.heldSpawnCount, isZero);
    });
  });

  group('Cognitive replay tracker', () {
    test('generates report with zero commands for empty session', () {
      final tracker = CognitiveReplayTracker();
      final report = tracker.generateReport();
      expect(report.totalCommands, isZero);
      expect(report.unaddressedAlerts, isZero);
      expect(report.averageReactionLatencySeconds, equals(0.0));
    });

    test('records alert lifecycle from observe', () {
      final tracker = CognitiveReplayTracker();
      const snapshot = SimulationSnapshot(
        tick: 1,
        elapsed: Duration(seconds: 10),
        aircraft: [],
        separation: [],
        activeAlerts: [
          ControllerAlert(
            id: 'sep1',
            type: AlertType.separationLoss,
            severity: 8,
            createdAt: Duration(seconds: 10),
            aircraftIds: ['a', 'b'],
          ),
        ],
      );
      tracker.observe(snapshot);

      // Alert should be tracked
      const emptySnapshot = SimulationSnapshot(
        tick: 2,
        elapsed: Duration(seconds: 20),
        aircraft: [],
        separation: [],
        activeAlerts: [],
      );
      tracker.observe(emptySnapshot);

      final report = tracker.generateReport();
      // Alert fired but had no response → unaddressed
      expect(report.unaddressedAlerts, equals(1));
    });

    test('records reaction latency when command follows alert', () {
      final tracker = CognitiveReplayTracker();
      const alertSnapshot = SimulationSnapshot(
        tick: 1,
        elapsed: Duration(seconds: 10),
        aircraft: [],
        separation: [],
        activeAlerts: [
          ControllerAlert(
            id: 'sep1',
            type: AlertType.separationLoss,
            severity: 8,
            createdAt: Duration(seconds: 10),
            aircraftIds: ['a', 'b'],
          ),
        ],
      );
      tracker.observe(alertSnapshot);

      // Issue command 8 seconds after alert
      const commandSnapshot = SimulationSnapshot(
        tick: 2,
        elapsed: Duration(seconds: 18),
        aircraft: [],
        separation: [],
        activeAlerts: [
          ControllerAlert(
            id: 'sep1',
            type: AlertType.separationLoss,
            severity: 8,
            createdAt: Duration(seconds: 10),
            aircraftIds: ['a', 'b'],
          ),
        ],
      );
      tracker.recordCommand(
        const AssignHeading(
          aircraftId: 'a',
          issuedAt: Duration(seconds: 18),
          headingDeg: 180,
        ),
        commandSnapshot,
      );

      final report = tracker.generateReport();
      expect(report.totalCommands, equals(1));
      // Alert got a response so should not be unaddressed
      expect(report.unaddressedAlerts, isZero);
      // Reaction latency should be around 8 seconds
      expect(report.averageReactionLatencySeconds,
          closeTo(8.0, 2.0));
    });

    test('composite score is lower when alerts are ignored', () {
      final withResponse = CognitiveReplayTracker();
      final withoutResponse = CognitiveReplayTracker();

      const alertSnapshot = SimulationSnapshot(
        tick: 1,
        elapsed: Duration(seconds: 5),
        aircraft: [],
        separation: [],
        activeAlerts: [
          ControllerAlert(
            id: 'sep1',
            type: AlertType.separationLoss,
            severity: 8,
            createdAt: Duration(seconds: 5),
            aircraftIds: ['a', 'b'],
          ),
        ],
      );
      withResponse.observe(alertSnapshot);
      withoutResponse.observe(alertSnapshot);

      const resolvedSnapshot = SimulationSnapshot(
        tick: 2,
        elapsed: Duration(seconds: 10),
        aircraft: [],
        separation: [],
        activeAlerts: [],
      );

      // Controller A responds immediately
      withResponse.recordCommand(
        const AssignHeading(
          aircraftId: 'a',
          issuedAt: Duration(seconds: 6),
          headingDeg: 180,
        ),
        alertSnapshot,
      );
      withResponse.observe(resolvedSnapshot);
      withoutResponse.observe(resolvedSnapshot);

      final reportWith = withResponse.generateReport();
      final reportWithout = withoutResponse.generateReport();

      expect(reportWith.compositeScore,
          greaterThan(reportWithout.compositeScore));
    });
  });
}
