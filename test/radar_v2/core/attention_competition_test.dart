import 'package:atm_flutter/features/radar_v2/core/alerts/alert_priority.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/operational_alert.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_competition_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/ignored_alert_tracker.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_event.dart';
import 'package:atm_flutter/features/radar_v2/models/separation_result.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/models/weather_zone.dart';
import 'package:flutter_test/flutter_test.dart';

OperationalAlert _alert(
  String id, {
  AlertPriority priority = AlertPriority.high,
  Duration createdAt = Duration.zero,
  List<String> aircraft = const ['b'],
  String? runway,
}) {
  return OperationalAlert(
    id: id,
    type: 'runway_occupancy',
    priority: priority,
    createdAt: createdAt,
    workloadImpact: priority == AlertPriority.critical ? 9 : 6,
    relatedAircraftIds: aircraft,
    relatedRunwayId: runway,
  );
}

SimulationSnapshot _snapshot({
  Duration elapsed = Duration.zero,
  List<AircraftState> aircraft = const [],
  List<SeparationResult> separation = const [],
  List<WeatherZone> weatherZones = const [],
  List<OperationalAlert> alerts = const [],
  List<SimulationEvent> events = const [],
  CognitiveLoadLevel level = CognitiveLoadLevel.calm,
}) {
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: aircraft,
    separation: separation,
    weatherZones: weatherZones,
    events: events,
    operationalAlerts: alerts,
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: switch (level) {
        CognitiveLoadLevel.calm => 1,
        CognitiveLoadLevel.busy => 4,
        CognitiveLoadLevel.overloaded => 7,
        CognitiveLoadLevel.saturated => 9,
      },
      currentLevel: level,
      activeStressors: const [],
      recentSpikes: const [],
    ),
  );
}

AircraftState _aircraft(String id, {double x = 0, double y = 0}) {
  return AircraftState(
    id: id,
    callsign: id.toUpperCase(),
    xNm: x,
    yNm: y,
    altitudeFt: 9000,
    headingDeg: 90,
    groundSpeedKt: 240,
  );
}

void main() {
  group('IgnoredAlertTracker', () {
    test('tracks ignored alert duration and escalating severity', () {
      final tracker = IgnoredAlertTracker();
      final alerts = [_alert('a1', priority: AlertPriority.critical)];

      tracker.update(
        elapsed: Duration.zero,
        alerts: alerts,
        focusTarget: 'aircraft:other',
        overloaded: false,
      );
      final ignored = tracker.update(
        elapsed: const Duration(seconds: 21),
        alerts: alerts,
        focusTarget: 'aircraft:other',
        overloaded: true,
      );

      expect(ignored.single.ignoredFor, const Duration(seconds: 21));
      expect(ignored.single.severity, greaterThanOrEqualTo(4));
    });
  });

  group('AttentionCompetitionEngine', () {
    test('tracks selected and recently interacted aircraft', () {
      final engine = AttentionCompetitionEngine();
      final events = [
        SimulationEvent(
          elapsed: const Duration(seconds: 5),
          type: 'commandIssued',
          label: 'Issued heading',
          aircraftId: 'b',
        ),
        SimulationEvent(
          elapsed: const Duration(seconds: 15),
          type: 'commandIssued',
          label: 'Issued speed',
          aircraftId: 'c',
        ),
      ];

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 30),
          aircraft: [_aircraft('a'), _aircraft('b'), _aircraft('c')],
          events: events,
        ),
        selectedAircraftId: 'a',
      );

      expect(state.selectedAircraftId, 'a');
      expect(state.recentlyInteractedAircraftIds, containsAll(['b', 'c']));
    });

    test('focus target changes when selected aircraft changes', () {
      final engine = AttentionCompetitionEngine();

      final first = engine.evaluate(
        snapshot: _snapshot(elapsed: const Duration(seconds: 1)),
        selectedAircraftId: 'a',
      );
      final second = engine.evaluate(
        snapshot: _snapshot(elapsed: const Duration(seconds: 2)),
        selectedAircraftId: 'b',
      );

      expect(first.currentFocusTarget, 'aircraft:a');
      expect(second.currentFocusTarget, 'aircraft:b');
      expect(second.focusDuration, Duration.zero);
    });

    test('detects tunnel vision after ignored critical alert exceeds threshold',
        () {
      final engine = AttentionCompetitionEngine();
      final alerts = [_alert('crit', priority: AlertPriority.critical)];

      engine.evaluate(
        snapshot: _snapshot(elapsed: Duration.zero, alerts: alerts),
        selectedAircraftId: 'a',
      );
      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 31),
          alerts: alerts,
          level: CognitiveLoadLevel.overloaded,
        ),
        selectedAircraftId: 'a',
      );

      expect(state.riskLevel, AttentionRiskLevel.criticalFixation);
      expect(state.ignoredCriticalCount, 1);
    });

    test('overloaded state increases attention risk with competing alerts', () {
      final engine = AttentionCompetitionEngine();
      final alerts = [
        _alert('h1', priority: AlertPriority.high, aircraft: const ['b']),
        _alert('h2', priority: AlertPriority.high, aircraft: const ['c']),
      ];

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 10),
          alerts: alerts,
          level: CognitiveLoadLevel.overloaded,
        ),
        selectedAircraftId: 'a',
      );

      expect(state.riskLevel, AttentionRiskLevel.fixationRisk);
      expect(state.competingHighPriorityAlertCount, 2);
    });

    test('repeated commands to same aircraft drive tunnel vision', () {
      final engine = AttentionCompetitionEngine();
      final events = List.generate(
        4,
        (index) => SimulationEvent(
          elapsed: Duration(seconds: index * 5),
          type: 'commandIssued',
          label: 'Issued heading',
          aircraftId: 'a',
        ),
      );

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 25),
          alerts: [
            _alert('h1', aircraft: const ['b'])
          ],
          events: events,
        ),
        selectedAircraftId: 'a',
      );

      expect(state.recentFocusedCommandCount, 4);
      expect(state.riskLevel, AttentionRiskLevel.tunnelVision);
    });

    test('neglected aircraft degrade prediction clarity and confidence', () {
      final engine = AttentionCompetitionEngine();
      final traffic = [_aircraft('a'), _aircraft('b', x: 5), _aircraft('c', y: 6)];

      engine.evaluate(
        snapshot: _snapshot(
          elapsed: Duration.zero,
          aircraft: traffic,
        ),
        selectedAircraftId: 'a',
      );
      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 42),
          aircraft: traffic,
          level: CognitiveLoadLevel.overloaded,
        ),
        selectedAircraftId: 'a',
      );

      expect(state.neglectedAircraftIds, containsAll(['b', 'c']));
      expect(state.predictionClarity, lessThan(0.75));
      expect(state.intentConfidence, lessThan(0.78));
      expect(state.surpriseRisk, greaterThan(0.22));
    });

    test('high salience competition can trigger tunnel-vision risk', () {
      final engine = AttentionCompetitionEngine();
      final alerts = [
        _alert('crit', priority: AlertPriority.critical, aircraft: const ['b']),
        _alert('high2', priority: AlertPriority.high, aircraft: const ['c']),
      ];
      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 40),
          aircraft: [_aircraft('a'), _aircraft('b'), _aircraft('c')],
          alerts: alerts,
          weatherZones: const [
            WeatherZone(id: 'w1', xNm: 0, yNm: 0, radiusNm: 10, severity: 3),
          ],
          level: CognitiveLoadLevel.overloaded,
        ),
        selectedAircraftId: 'a',
      );

      expect(state.visuallySalientAircraftIds.length, greaterThanOrEqualTo(3));
      expect(
        state.riskLevel.index,
        greaterThanOrEqualTo(AttentionRiskLevel.fixationRisk.index),
      );
    });

    test('beginner support keeps higher awareness than advanced support', () {
      final beginnerEngine = AttentionCompetitionEngine();
      final advancedEngine = AttentionCompetitionEngine();
      final traffic = [
        _aircraft('a'),
        _aircraft('b', x: 6),
        _aircraft('c', y: 6),
        _aircraft('d', x: -5, y: 4),
      ];

      beginnerEngine.evaluate(
        snapshot: _snapshot(elapsed: Duration.zero, aircraft: traffic),
        selectedAircraftId: 'a',
        awarenessSupport: 1.0,
      );
      advancedEngine.evaluate(
        snapshot: _snapshot(elapsed: Duration.zero, aircraft: traffic),
        selectedAircraftId: 'a',
        awarenessSupport: 0.55,
      );

      final beginner = beginnerEngine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 36),
          aircraft: traffic,
          level: CognitiveLoadLevel.overloaded,
        ),
        selectedAircraftId: 'a',
        awarenessSupport: 1.0,
      );
      final advanced = advancedEngine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 36),
          aircraft: traffic,
          level: CognitiveLoadLevel.overloaded,
        ),
        selectedAircraftId: 'a',
        awarenessSupport: 0.55,
      );

      expect(beginner.predictionClarity, greaterThan(advanced.predictionClarity));
      expect(beginner.intentConfidence, greaterThan(advanced.intentConfidence));
      expect(beginner.surpriseRisk, lessThan(advanced.surpriseRisk));
    });
  });

  group('AttentionReplayAnalytics', () {
    test('generates replay summary text for tunnel vision and ignored alerts',
        () {
      const ignored = IgnoredAlertSnapshot(
        alertId: 'crit',
        alertType: 'runway_occupancy',
        priority: AlertPriority.critical,
        ignoredFor: Duration(seconds: 21),
        severity: 5,
      );
      const state = AttentionFocusState(
        currentFocusTarget: 'aircraft:QFA214',
        focusDuration: Duration(seconds: 32),
        ignoredAlerts: [ignored],
        competingHighPriorityAlertCount: 4,
        recentFocusedCommandCount: 4,
        overloadDuration: Duration(seconds: 10),
        riskLevel: AttentionRiskLevel.criticalFixation,
      );

      final report = const AttentionReplayAnalytics(states: [state]).generate();

      expect(report.longestIgnoredAlert?.alertId, 'crit');
      expect(report.tunnelVisionEpisodes, isNotEmpty);
      expect(report.reportLines.join(' '), contains('Tunnel vision detected'));
    });

    test('reports scan imbalance and late rediscovery cues', () {
      const degraded = AttentionFocusState(
        scanCoverageQuality: 0.42,
        longestNeglect: Duration(seconds: 37),
        delayedAwarenessMoments: 2,
      );

      final report = const AttentionReplayAnalytics(states: [degraded]).generate();

      expect(
        report.reportLines.join(' '),
        contains('Scan imbalance observed'),
      );
      expect(report.reportLines.join(' '), contains('Delayed awareness moments'));
    });
  });
}
