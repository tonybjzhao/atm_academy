import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/commands/controller_command.dart';
import 'package:atm_flutter/features/radar_v2/engine/simulation_engine.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_intent.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';

void main() {
  test('fixed timestep moves aircraft deterministically', () {
    final engineA = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 360,
        ),
      ],
    );
    final engineB = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 360,
        ),
      ],
    );

    final first = engineA.tick(steps: 10).aircraftById('a')!;
    final second = engineB.tick(steps: 10).aircraftById('a')!;

    expect(first.xNm, closeTo(1, 0.0001));
    expect(first.yNm, closeTo(0, 0.0001));
    expect(first.xNm, second.xNm);
    expect(first.yNm, second.yNm);
  });

  test('heading speed and altitude assignments update gradually', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 240,
          intent: AircraftIntent(
            assignedHeadingDeg: 90,
            assignedSpeedKt: 300,
            assignedAltitudeFt: 12000,
          ),
        ),
      ],
    );

    final aircraft = engine.tick(steps: 10).aircraftById('a')!;

    expect(aircraft.headingDeg, closeTo(30, 0.001));
    expect(aircraft.groundSpeedKt, closeTo(270, 0.001));
    expect(aircraft.altitudeFt, 9300);
    expect(aircraft.verticalSpeedFpm, 1800);
  });

  test('separation loss is detected', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 250,
        ),
        const AircraftState(
          id: 'b',
          callsign: 'VJA612',
          xNm: 3,
          yNm: 0,
          altitudeFt: 9500,
          headingDeg: 270,
          groundSpeedKt: 250,
        ),
      ],
    );

    final losses =
        engine.snapshot.separation.where((result) => result.isLossOfSeparation);

    expect(losses, hasLength(1));
  });

  test('future crossing traffic produces predicted conflict point', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: -10,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 300,
        ),
        const AircraftState(
          id: 'b',
          callsign: 'VJA612',
          xNm: 0,
          yNm: -10,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 300,
        ),
      ],
    );

    final predicted = engine.snapshot.separation
        .where((result) => result.isPredictedConflict)
        .single;

    expect(predicted.timeToConflict, const Duration(minutes: 2));
    expect(predicted.conflictXNm, closeTo(0, 0.001));
    expect(predicted.conflictYNm, closeTo(0, 0.001));
  });

  test('commands update aircraft intent and affect future motion', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 240,
        ),
      ],
    );

    engine
      ..applyCommand(
        const AssignHeading(
          aircraftId: 'a',
          issuedAt: Duration.zero,
          headingDeg: 90,
        ),
      )
      ..applyCommand(
        const AssignAltitude(
          aircraftId: 'a',
          issuedAt: Duration.zero,
          altitudeFt: 12000,
        ),
      )
      ..applyCommand(
        const AssignSpeed(
          aircraftId: 'a',
          issuedAt: Duration.zero,
          speedKt: 300,
        ),
      );

    final intent = engine.snapshot.aircraftById('a')!.intent;
    expect(intent.assignedHeadingDeg, 90);
    expect(intent.assignedAltitudeFt, 12000);
    expect(intent.assignedSpeedKt, 300);

    final aircraft = engine.tick(steps: 10).aircraftById('a')!;
    expect(aircraft.headingDeg, closeTo(30, 0.001));
    expect(aircraft.groundSpeedKt, closeTo(270, 0.001));
    expect(aircraft.altitudeFt, 9300);
  });
}
