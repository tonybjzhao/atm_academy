import 'package:atm_flutter/features/radar_v2/commands/controller_command.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_intent.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/separation_result.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_event.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/workflow/command_workflow_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandWorkflowTracker', () {
    test('command queue transitions sent -> awaiting -> acknowledged -> completed', () {
      final tracker = CommandWorkflowTracker();
      const aircraft = AircraftState(
        id: 'A1',
        callsign: 'AAL101',
        xNm: 0,
        yNm: 0,
        altitudeFt: 9000,
        headingDeg: 180,
        groundSpeedKt: 250,
      );

      tracker.onCommandSent(
        command: const AssignHeading(
          aircraftId: 'A1',
          issuedAt: Duration(seconds: 10),
          headingDeg: 220,
        ),
        aircraft: aircraft,
        label: 'AAL101 TURN RIGHT HEADING 220',
      );

      expect(tracker.entries.single.status, CommandWorkflowStatus.sent);

      final prev = _snapshot(
        tick: 10,
        elapsed: const Duration(seconds: 10),
        aircraft: const [aircraft],
        events: const [],
      );
      final current = _snapshot(
        tick: 11,
        elapsed: const Duration(seconds: 11),
        aircraft: const [aircraft],
        events: const [],
      );

      tracker.onSnapshotTransition(previous: prev, current: current);
      expect(
        tracker.entries.single.status,
        CommandWorkflowStatus.awaitingAcknowledgement,
      );

      const ackAircraft = AircraftState(
        id: 'A1',
        callsign: 'AAL101',
        xNm: 0,
        yNm: 0,
        altitudeFt: 9000,
        headingDeg: 180,
        groundSpeedKt: 250,
      );
      final withAck = _snapshot(
        tick: 12,
        elapsed: const Duration(seconds: 13),
        aircraft: const [ackAircraft],
        events: const [
          SimulationEvent(
            elapsed: Duration(seconds: 13),
            type: 'commandAcknowledged',
            label: 'ACK heading 220',
            aircraftId: 'A1',
          ),
        ],
      );
      tracker.onSnapshotTransition(previous: current, current: withAck);
      expect(tracker.entries.single.status, CommandWorkflowStatus.acknowledged);

      const completedAircraft = AircraftState(
        id: 'A1',
        callsign: 'AAL101',
        xNm: 0,
        yNm: 0,
        altitudeFt: 9000,
        headingDeg: 180,
        groundSpeedKt: 250,
        intent: AircraftIntent(assignedHeadingDeg: 220),
      );
      final complete = _snapshot(
        tick: 13,
        elapsed: const Duration(seconds: 15),
        aircraft: const [completedAircraft],
        events: const [
          SimulationEvent(
            elapsed: Duration(seconds: 13),
            type: 'commandAcknowledged',
            label: 'ACK heading 220',
            aircraftId: 'A1',
          ),
        ],
      );
      tracker.onSnapshotTransition(previous: withAck, current: complete);
      expect(tracker.entries.single.status, CommandWorkflowStatus.completed);
    });

    test('chained commands retain chain id and ordering', () {
      final tracker = CommandWorkflowTracker();
      const aircraft = AircraftState(
        id: 'A2',
        callsign: 'DAL220',
        xNm: 0,
        yNm: 0,
        altitudeFt: 12000,
        headingDeg: 90,
        groundSpeedKt: 300,
      );

      tracker.onCommandSent(
        command: const AssignHeading(
          aircraftId: 'A2',
          issuedAt: Duration(seconds: 20),
          headingDeg: 130,
        ),
        aircraft: aircraft,
        label: 'DAL220 TURN RIGHT HEADING 130',
        chainId: 'chain-1',
      );
      tracker.onCommandSent(
        command: const AssignSpeed(
          aircraftId: 'A2',
          issuedAt: Duration(seconds: 20),
          speedKt: 260,
        ),
        aircraft: aircraft,
        label: 'DAL220 REDUCE SPEED 260',
        chainId: 'chain-1',
      );

      final entries = tracker.entriesForAircraft('A2');
      expect(entries, hasLength(2));
      expect(entries[0].chainId, 'chain-1');
      expect(entries[1].chainId, 'chain-1');
    });

    test('replay insights expose delayed and interrupted command windows', () {
      final tracker = CommandWorkflowTracker();
      final insights = tracker.replayInsights(const [
        SimulationEvent(
          elapsed: Duration(seconds: 40),
          type: 'commandIssued',
          label: 'Command sent: heading 210',
          aircraftId: 'A3',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 43),
          type: 'weatherInteraction',
          label: 'Weather compressed spacing near the merge.',
          aircraftId: 'A3',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 44),
          type: 'pilotResponseDelay',
          label: 'Delayed acknowledgement increased follow-through time.',
          aircraftId: 'A3',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 45),
          type: 'trajectoryTurnOvershoot',
          label: 'Turn overshoot widened heading correction before settling.',
          aircraftId: 'A3',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 46),
          type: 'commandAcknowledged',
          label: 'ACK heading 210',
          aircraftId: 'A3',
        ),
      ]);

      expect(insights, hasLength(1));
      expect(insights.single.delayed, isTrue);
      expect(insights.single.interrupted, isTrue);
      expect(insights.single.acknowledgementDelay, const Duration(seconds: 6));
      expect(insights.single.causes, contains('weather-driven deviation'));
      expect(insights.single.causes, contains('pilot response delay'));
      expect(insights.single.causes, contains('turn overshoot'));
      expect(
        insights.single.spacingImpact,
        'Trajectory instability reduced merge/spacing predictability.',
      );
    });

    test('replay insights explain wake ecology pressure and instability', () {
      final tracker = CommandWorkflowTracker();
      final insights = tracker.replayInsights(const [
        SimulationEvent(
          elapsed: Duration(seconds: 18),
          type: 'commandIssued',
          label: 'Command sent: speed 180',
          aircraftId: 'A4',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 20),
          type: 'wakeTurbulenceWobble',
          label: 'Heavy wake turbulence introduced subtle trajectory wobble.',
          aircraftId: 'A4',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 21),
          type: 'wakeTurnStabilizationDelay',
          label: 'Wake turbulence delayed turn stabilization behind lead traffic.',
          aircraftId: 'A4',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 22),
          type: 'wakeSpeedInstability',
          label: 'Wake influence caused speed instability during follow-through.',
          aircraftId: 'A4',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 23),
          type: 'wakeSequencingPressure',
          label: 'Sequencing pressure built behind heavy final approach traffic.',
          aircraftId: 'A4',
        ),
        SimulationEvent(
          elapsed: Duration(seconds: 24),
          type: 'commandAcknowledged',
          label: 'ACK speed 180',
          aircraftId: 'A4',
        ),
      ]);

      expect(insights, hasLength(1));
      expect(insights.single.causes, contains('wake turbulence wobble'));
      expect(insights.single.causes, contains('wake-delayed turn stabilization'));
      expect(insights.single.causes, contains('wake-induced speed instability'));
      expect(insights.single.causes, contains('heavy sequencing pressure'));
      expect(
        insights.single.spacingImpact,
        'Wake effects increased sequencing pressure and reduced recovery margin.',
      );
    });
  });
}

SimulationSnapshot _snapshot({
  required int tick,
  required Duration elapsed,
  required List<AircraftState> aircraft,
  required List<SimulationEvent> events,
}) {
  return SimulationSnapshot(
    tick: tick,
    elapsed: elapsed,
    aircraft: aircraft,
    separation: const <SeparationResult>[],
    events: events,
  );
}
