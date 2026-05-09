import 'package:atm_flutter/features/radar_v2/core/alerts/alert_priority.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/operational_alert.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/working_memory_engine.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_event.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot({
  required Duration elapsed,
  List<SimulationEvent> events = const [],
  CognitiveLoadLevel level = CognitiveLoadLevel.calm,
  AttentionFocusState attention = AttentionFocusState.idle,
  Set<String> activeDistractions = const {},
}) {
  final loadScore = switch (level) {
    CognitiveLoadLevel.calm => 1.5,
    CognitiveLoadLevel.busy => 4.0,
    CognitiveLoadLevel.overloaded => 7.2,
    CognitiveLoadLevel.saturated => 9.0,
  };
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: const [],
    separation: const [],
    events: events,
    activeDistractions: activeDistractions,
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: loadScore,
      currentLevel: level,
      activeStressors: const [],
      recentSpikes: const [],
    ),
    attentionFocus: attention,
  );
}

void main() {
  group('WorkingMemoryEngine', () {
    test('creates pending intentions from issued commands', () {
      final engine = WorkingMemoryEngine();
      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 5),
          events: const [
            SimulationEvent(
              elapsed: Duration(seconds: 5),
              type: 'commandIssued',
              label: 'ISS heading 240',
              aircraftId: 'a1',
            ),
          ],
        ),
        attentionFocus: const AttentionFocusState(),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 1,
          currentLevel: CognitiveLoadLevel.calm,
          activeStressors: [],
          recentSpikes: [],
        ),
        operationalAlerts: const [],
      );

      expect(state.pendingIntentions, isNotEmpty);
      expect(state.pendingIntentions.first.typeLabel, contains('turn'));
    });

    test('high workload and interruptions can produce forgotten intentions', () {
      final engine = WorkingMemoryEngine();
      const events = [
        SimulationEvent(
          elapsed: Duration(seconds: 0),
          type: 'commandIssued',
          label: 'ISS altitude 080',
          aircraftId: 'a2',
        ),
      ];

      engine.evaluate(
        snapshot: _snapshot(
          elapsed: Duration.zero,
          events: events,
          level: CognitiveLoadLevel.overloaded,
          attention: const AttentionFocusState(
            currentFocusTarget: 'aircraft:b1',
            competingHighPriorityAlertCount: 2,
            activeInterrupts: ['radio chatter'],
          ),
          activeDistractions: const {'int:1'},
        ),
        attentionFocus: const AttentionFocusState(
          currentFocusTarget: 'aircraft:b1',
          competingHighPriorityAlertCount: 2,
          activeInterrupts: ['radio chatter'],
        ),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 8,
          currentLevel: CognitiveLoadLevel.overloaded,
          activeStressors: [],
          recentSpikes: [],
        ),
        operationalAlerts: const [
          OperationalAlert(
            id: 'x',
            type: 'separation_loss',
            priority: AlertPriority.critical,
            createdAt: Duration.zero,
            workloadImpact: 10,
          ),
        ],
      );

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 55),
          events: events,
          level: CognitiveLoadLevel.overloaded,
          attention: const AttentionFocusState(
            currentFocusTarget: 'aircraft:b1',
            competingHighPriorityAlertCount: 3,
            activeInterrupts: ['emergency distraction'],
          ),
          activeDistractions: const {'int:1', 'int:2'},
        ),
        attentionFocus: const AttentionFocusState(
          currentFocusTarget: 'aircraft:b1',
          competingHighPriorityAlertCount: 3,
          activeInterrupts: ['emergency distraction'],
        ),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 8,
          currentLevel: CognitiveLoadLevel.overloaded,
          activeStressors: [],
          recentSpikes: [],
        ),
        operationalAlerts: const [],
      );

      expect(state.forgottenIntentionCount, greaterThanOrEqualTo(1));
      expect(state.delayedFollowThroughCount, greaterThanOrEqualTo(1));
    });

    test('late acknowledgement recovers forgotten intention', () {
      final engine = WorkingMemoryEngine();
      const issued = SimulationEvent(
        elapsed: Duration(seconds: 0),
        type: 'commandIssued',
        label: 'ISS heading 180',
        aircraftId: 'a3',
      );
      const acknowledged = SimulationEvent(
        elapsed: Duration(seconds: 46),
        type: 'commandAcknowledged',
        label: 'ACK heading 180',
        aircraftId: 'a3',
      );

      engine.evaluate(
        snapshot: _snapshot(
          elapsed: Duration.zero,
          events: const [issued],
          level: CognitiveLoadLevel.overloaded,
          activeDistractions: const {'int:x'},
        ),
        attentionFocus: const AttentionFocusState(
          currentFocusTarget: 'aircraft:b1',
          competingHighPriorityAlertCount: 2,
          activeInterrupts: ['radio chatter'],
        ),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 8,
          currentLevel: CognitiveLoadLevel.overloaded,
          activeStressors: [],
          recentSpikes: [],
        ),
        operationalAlerts: const [],
      );

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 48),
          events: const [issued, acknowledged],
          level: CognitiveLoadLevel.overloaded,
          activeDistractions: const {'int:x'},
        ),
        attentionFocus: const AttentionFocusState(
          currentFocusTarget: 'aircraft:b1',
          competingHighPriorityAlertCount: 2,
          activeInterrupts: ['runway change'],
        ),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 8,
          currentLevel: CognitiveLoadLevel.overloaded,
          activeStressors: [],
          recentSpikes: [],
        ),
        operationalAlerts: const [],
      );

      expect(state.recoveredTaskCount, greaterThanOrEqualTo(1));
    });
  });
}
