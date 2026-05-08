import 'package:atm_flutter/features/radar_v2/core/alerts/alert_priority.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/operational_alert.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_competition_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/ignored_alert_tracker.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_event.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
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
  List<OperationalAlert> alerts = const [],
  List<SimulationEvent> events = const [],
  CognitiveLoadLevel level = CognitiveLoadLevel.calm,
}) {
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: const [],
    separation: const [],
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
  });
}
