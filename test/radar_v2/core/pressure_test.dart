import 'package:atm_flutter/features/radar_v2/core/alerts/alert_priority.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/operational_alert.dart';

import 'package:atm_flutter/features/radar_v2/core/audio/workload_audio_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/pressure/attention_competition_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/pressure/tunnel_vision_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/pressure/workload_degradation.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: prefer_const_constructors

OperationalAlert _alert(
  String id, {
  AlertPriority priority = AlertPriority.medium,
  Duration createdAt = Duration.zero,
}) =>
    OperationalAlert(
      id: id,
      type: 'TEST',
      priority: priority,
      createdAt: createdAt,
      workloadImpact: 3,
    );

void main() {
  group('WorkloadDegradation', () {
    test('score 0 gives none/identity values', () {
      final d = WorkloadDegradation.fromLoadScore(0.0);
      expect(d.pilotAckDelayFactor, closeTo(1.0, 0.01));
      expect(d.alertEscalationBias, closeTo(0.0, 0.01));
      expect(d.spacingCompressionRisk, closeTo(0.0, 0.01));
    });

    test('score 10 gives saturated values', () {
      final d = WorkloadDegradation.fromLoadScore(10.0);
      expect(d.pilotAckDelayFactor, greaterThan(2.0));
      expect(d.spacingCompressionRisk, greaterThan(0.3));
    });

    test('intermediate score interpolates linearly', () {
      final d5 = WorkloadDegradation.fromLoadScore(5.0);
      final d0 = WorkloadDegradation.fromLoadScore(0.0);
      final d10 = WorkloadDegradation.fromLoadScore(10.0);
      // 5.0 should be between 0 and 10 extremes
      expect(
        d5.pilotAckDelayFactor,
        greaterThan(d0.pilotAckDelayFactor - 0.01),
      );
      expect(
        d5.pilotAckDelayFactor,
        lessThan(d10.pilotAckDelayFactor + 0.01),
      );
    });

    test('forLevel maps levels to expected presets', () {
      expect(
        WorkloadDegradation.forLevel(CognitiveLoadLevel.calm).pilotAckDelayFactor,
        closeTo(1.0, 0.01),
      );
      expect(
        WorkloadDegradation.forLevel(CognitiveLoadLevel.saturated).alertEscalationBias,
        greaterThan(0.2),
      );
    });
  });

  group('AttentionCompetitionEngine', () {
    late AttentionCompetitionEngine engine;
    setUp(() => engine = AttentionCompetitionEngine());

    test('idle with no alerts returns full budget', () {
      final result = engine.evaluate(activeAlerts: [], recentCommandCount: 0);
      expect(result.remainingAttentionBudget, closeTo(1.0, 0.01));
      expect(result.escalatingAlertIds, isEmpty);
      expect(result.lowPrioritySuppressionActive, isFalse);
    });

    test('one critical alert reduces budget', () {
      final result = engine.evaluate(
        activeAlerts: [_alert('a1', priority: AlertPriority.critical)],
        recentCommandCount: 0,
      );
      expect(result.remainingAttentionBudget, lessThan(1.0));
    });

    test('five critical alerts triggers low-priority suppression', () {
      final alerts = List.generate(
        5,
        (i) => _alert('a$i', priority: AlertPriority.critical),
      );
      final result =
          engine.evaluate(activeAlerts: alerts, recentCommandCount: 8);
      expect(result.lowPrioritySuppressionActive, isTrue);
      expect(result.escalatingAlertIds, isNotEmpty);
    });

    test('three medium alerts does not suppress low priority', () {
      final alerts = List.generate(
        3,
        (i) => _alert('a$i', priority: AlertPriority.medium),
      );
      final result = engine.evaluate(
        activeAlerts: alerts,
        recentCommandCount: 2,
      );
      expect(result.lowPrioritySuppressionActive, isFalse);
    });
  });

  group('TunnelVisionEngine', () {
    late TunnelVisionEngine engine;
    setUp(() => engine = TunnelVisionEngine());

    test('no interactions — no fixation', () {
      final state = engine.tick(const Duration(seconds: 5));
      expect(state.isActive, isFalse);
      expect(state.detectionLatencySeconds, closeTo(0.0, 0.01));
    });

    test('repeated interactions on same target triggers fixation', () {
      // Record 5 interactions on the same aircraft within the window
      for (var i = 0; i < 5; i++) {
        engine.recordInteraction(
          aircraftId: 'AC1',
          elapsed: Duration(seconds: i * 5),
        );
      }
      final state = engine.tick(const Duration(seconds: 30));
      expect(state.isActive, isTrue);
      expect(state.fixatedObjectId, equals('AC1'));
      expect(state.detectionLatencySeconds, greaterThan(0));
    });

    test('fixation latency is greater than zero once established', () {
      for (var i = 0; i < 5; i++) {
        engine.recordInteraction(
          aircraftId: 'AC1',
          elapsed: Duration(seconds: i * 5),
        );
      }
      final state = engine.tick(const Duration(seconds: 25));
      expect(state.isActive, isTrue);
      expect(state.detectionLatencySeconds, greaterThan(0));
    });

    test('reset clears fixation', () {
      for (var i = 0; i < 5; i++) {
        engine.recordInteraction(
          aircraftId: 'AC1',
          elapsed: Duration(seconds: i * 5),
        );
      }
      engine.reset();
      final state = engine.tick(const Duration(seconds: 30));
      expect(state.isActive, isFalse);
    });

    test('different aircraft do not compound fixation', () {
      for (var i = 0; i < 6; i++) {
        engine.recordInteraction(
          aircraftId: 'AC$i',
          elapsed: Duration(seconds: i * 5),
        );
      }
      final state = engine.tick(const Duration(seconds: 35));
      expect(state.isActive, isFalse);
    });
  });

  group('WorkloadAudioStateMachine', () {
    late WorkloadAudioStateMachine machine;
    setUp(() => machine = WorkloadAudioStateMachine());

    test('starts in calm state', () {
      expect(machine.currentState, equals(AudioWorkloadState.calm));
    });

    test('single overloaded tick does not immediately escalate', () {
      // hysteresis: need _hysteresisTicksUp+1 ticks before confirmed escalation
      machine.tick(CognitiveLoadLevel.overloaded);
      expect(machine.currentState, isNot(AudioWorkloadState.overload));
    });

    test('enough overloaded ticks escalate to overload', () {
      // _hysteresisTicksUp = 3 pending ticks needed → must call tick 4 times
      for (var i = 0; i < 4; i++) {
        machine.tick(CognitiveLoadLevel.overloaded);
      }
      expect(machine.currentState, equals(AudioWorkloadState.overload));
    });

    test('does not downgrade immediately after one calm tick', () {
      // Escalate to overload first
      for (var i = 0; i < 4; i++) {
        machine.tick(CognitiveLoadLevel.overloaded);
      }
      machine.tick(CognitiveLoadLevel.calm);
      // Should still be overload — needs _hysteresisTicksDown ticks to drop
      expect(machine.currentState, equals(AudioWorkloadState.overload));
    });

    test('downgrade after enough calm ticks', () {
      // Escalate
      for (var i = 0; i < 4; i++) {
        machine.tick(CognitiveLoadLevel.overloaded);
      }
      // Downgrade (_hysteresisTicksDown = 8 pending ticks → 9 calls)
      for (var i = 0; i < 9; i++) {
        machine.tick(CognitiveLoadLevel.calm);
      }
      expect(
        machine.currentState,
        isNot(equals(AudioWorkloadState.overload)),
      );
    });

    test('saturated escalates through all states', () {
      // Need 4 ticks per stage: busy, then overload, then saturation
      for (var i = 0; i < 12; i++) {
        machine.tick(CognitiveLoadLevel.saturated);
      }
      expect(machine.currentState, equals(AudioWorkloadState.saturation));
    });
  });
}
