import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/commands/controller_command.dart';
import 'package:atm_flutter/features/radar_v2/engine/simulation_engine.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_intent.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_performance_profile.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/altitude_restriction.dart';
import 'package:atm_flutter/features/radar_v2/models/arrival_flow.dart';
import 'package:atm_flutter/features/radar_v2/models/hold_pattern.dart';
import 'package:atm_flutter/features/radar_v2/models/weather_zone.dart';
import 'package:atm_flutter/features/radar_v2/models/waypoint.dart';

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

  test('snapshots include bounded aircraft trail history', () {
    final engine = SimulationEngine(
      maxTrailPoints: 5,
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

    final snapshot = engine.tick(steps: 10);
    final trail = snapshot.trailFor('a');

    expect(trail, hasLength(5));
    expect(trail.last.xNm, closeTo(1, 0.0001));
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

    expect(aircraft.headingDeg, greaterThan(20));
    expect(aircraft.headingDeg, lessThan(90));
    expect(aircraft.turnRateDegPerSecond, greaterThan(0));
    expect(aircraft.groundSpeedKt, greaterThan(250));
    expect(aircraft.groundSpeedKt, lessThan(300));
    expect(aircraft.speedTrendKtPerSecond, greaterThan(0));
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
    expect(intent.assignedHeadingDeg, isNull);
    expect(intent.assignedAltitudeFt, isNull);
    expect(intent.assignedSpeedKt, isNull);

    final acknowledged = engine.tick(steps: 5).aircraftById('a')!;
    expect(acknowledged.intent.assignedHeadingDeg, 90);
    expect(acknowledged.intent.assignedAltitudeFt, 12000);
    expect(acknowledged.intent.assignedSpeedKt, 300);

    final aircraft = engine.tick(steps: 10).aircraftById('a')!;
    expect(aircraft.headingDeg, greaterThan(20));
    expect(aircraft.headingDeg, lessThan(90));
    expect(aircraft.groundSpeedKt, greaterThan(250));
    expect(aircraft.groundSpeedKt, lessThan(300));
    expect(aircraft.altitudeFt, greaterThan(9200));
    expect(aircraft.altitudeFt, lessThan(12000));
  });

  test('aircraft follows waypoint route when not being vectored', () {
    final engine = SimulationEngine(
      waypoints: const {
        'FIX1': Waypoint(id: 'FIX1', xNm: 0, yNm: 10),
        'FIX2': Waypoint(id: 'FIX2', xNm: 10, yNm: 10),
      },
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 270,
          groundSpeedKt: 360,
          intent: AircraftIntent(route: ['FIX1', 'FIX2']),
        ),
      ],
    );

    final aircraft = engine.tick().aircraftById('a')!;

    expect(aircraft.yNm, greaterThan(0));
    expect(aircraft.headingDeg, greaterThan(270));
    expect(aircraft.headingDeg, lessThan(273));
  });

  test('performance profiles change maneuver response rates', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'jet',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 240,
          performanceType: AircraftPerformanceType.jet,
          intent: AircraftIntent(assignedHeadingDeg: 90),
        ),
        const AircraftState(
          id: 'tp',
          callsign: 'REX438',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 240,
          performanceType: AircraftPerformanceType.turboprop,
          intent: AircraftIntent(assignedHeadingDeg: 90),
        ),
      ],
    );

    final snapshot = engine.tick(steps: 10);

    expect(snapshot.aircraftById('tp')!.headingDeg,
        greaterThan(snapshot.aircraftById('jet')!.headingDeg));
  });

  test('hold command flies aircraft onto a racetrack hold', () {
    final engine = SimulationEngine(
      waypoints: const {
        'FIX1': Waypoint(id: 'FIX1', xNm: 0, yNm: 0),
      },
      holdPatterns: const [
        HoldPattern(
          id: 'FIX1_HOLD',
          fixWaypointId: 'FIX1',
          inboundHeadingDeg: 180,
          legSeconds: 30,
          stackAltitudeFt: 8000,
        ),
      ],
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

    engine.applyCommand(
      const EnterHold(
        aircraftId: 'a',
        issuedAt: Duration.zero,
        holdPatternId: 'FIX1_HOLD',
      ),
    );

    final aircraft = engine.tick(steps: 5).aircraftById('a')!;

    expect(aircraft.intent.hold, isTrue);
    expect(aircraft.intent.holdPatternId, 'FIX1_HOLD');
    expect(aircraft.intent.assignedAltitudeFt, 8000);
  });

  test('route guidance applies altitude restrictions', () {
    final engine = SimulationEngine(
      waypoints: const {
        'FIX1': Waypoint(id: 'FIX1', xNm: 0, yNm: 10),
      },
      altitudeRestrictions: const [
        AltitudeRestriction(
          waypointId: 'FIX1',
          altitudeFt: 7000,
          type: AltitudeRestrictionType.atOrBelow,
        ),
      ],
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 240,
          intent: AircraftIntent(route: ['FIX1']),
        ),
      ],
    );

    final aircraft = engine.tick().aircraftById('a')!;

    expect(aircraft.intent.assignedAltitudeFt, 7000);
  });

  test('speed commands respond gradually and differ by aircraft type', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'jet',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 300,
          performanceType: AircraftPerformanceType.jet,
          intent: AircraftIntent(assignedSpeedKt: 220),
        ),
        const AircraftState(
          id: 'tp',
          callsign: 'REX438',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 0,
          groundSpeedKt: 300,
          performanceType: AircraftPerformanceType.turboprop,
          intent: AircraftIntent(assignedSpeedKt: 220),
        ),
      ],
    );

    final snapshot = engine.tick(steps: 12);
    final jet = snapshot.aircraftById('jet')!;
    final turboprop = snapshot.aircraftById('tp')!;

    expect(jet.groundSpeedKt, greaterThan(220));
    expect(turboprop.groundSpeedKt, greaterThan(220));
    expect(jet.groundSpeedKt, lessThan(turboprop.groundSpeedKt));
  });

  test('weather zone creates bounded deterministic track instability', () {
    final aircraft = const AircraftState(
      id: 'wx',
      callsign: 'VOZ841',
      xNm: 0,
      yNm: 0,
      altitudeFt: 9000,
      headingDeg: 90,
      groundSpeedKt: 260,
    );
    final engineA = SimulationEngine(
      aircraft: [aircraft],
      weatherZones: const [
        WeatherZone(id: 'storm', xNm: 0, yNm: 0, radiusNm: 10, severity: 3),
      ],
    );
    final engineB = SimulationEngine(
      aircraft: [aircraft],
      weatherZones: const [
        WeatherZone(id: 'storm', xNm: 0, yNm: 0, radiusNm: 10, severity: 3),
      ],
    );

    final first = engineA.tick(steps: 8).aircraftById('wx')!;
    final second = engineB.tick(steps: 8).aircraftById('wx')!;

    expect(first.xNm, closeTo(second.xNm, 0.0001));
    expect(first.yNm, closeTo(second.yNm, 0.0001));
    expect(first.yNm.abs(), lessThan(0.06));
    expect(first.groundSpeedKt, inInclusiveRange(253, 267));
  });

  test('repeated weather ticks do not create unbounded speed drift', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'wx',
          callsign: 'VOZ841',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 260,
        ),
      ],
      weatherZones: const [
        WeatherZone(id: 'storm', xNm: 0, yNm: 0, radiusNm: 14, severity: 3),
      ],
    );

    final aircraft = engine.tick(steps: 90).aircraftById('wx')!;

    expect(aircraft.groundSpeedKt, closeTo(260, 0.0001));
  });

  test('pilot acknowledgement delay remains within expected bounds', () {
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
          performanceType: AircraftPerformanceType.jet,
        ),
      ],
    );

    engine.applyCommand(
      const AssignHeading(
        aircraftId: 'a',
        issuedAt: Duration.zero,
        headingDeg: 90,
      ),
    );
    final snapshot = engine.tick(steps: 8);
    final ack = snapshot.events.singleWhere(
      (event) => event.type == 'commandAcknowledged',
    );

    expect(ack.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 2500)));
    expect(ack.elapsed, lessThanOrEqualTo(const Duration(seconds: 5)));
  });

  test('weather behavior event is sustained and does not spam', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'wx',
          callsign: 'VOZ841',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 260,
        ),
      ],
      weatherZones: const [
        WeatherZone(id: 'storm', xNm: 0, yNm: 0, radiusNm: 14, severity: 3),
      ],
    );

    final early = engine.tick(steps: 4);
    expect(
      early.events.where((event) => event.type == 'weatherInteraction'),
      isEmpty,
    );

    final later = engine.tick(steps: 20);
    expect(
      later.events.where((event) => event.type == 'weatherInteraction'),
      hasLength(1),
    );
  });

  test('approach capture stabilizes speed and altitude near final', () {
    final engine = SimulationEngine(
      waypoints: const {
        'FINAL': Waypoint(id: 'FINAL', xNm: 0, yNm: 4),
        'RWY': Waypoint(id: 'RWY', xNm: 0, yNm: 0),
      },
      arrivalFlows: const [
        ArrivalFlow(
          id: 'flow',
          runwayId: 'RWY',
          mergeWaypointId: 'FINAL',
          finalFixWaypointId: 'FINAL',
          thresholdWaypointId: 'RWY',
          spacingTargetNm: 6,
          stabilizedAltitudeFt: 3000,
        ),
      ],
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 7,
          altitudeFt: 5000,
          headingDeg: 180,
          groundSpeedKt: 220,
          intent:
              AircraftIntent(route: ['FINAL', 'RWY'], assignedRunwayId: 'RWY'),
        ),
      ],
    );

    final aircraft = engine.tick().aircraftById('a')!;

    expect(aircraft.intent.assignedSpeedKt, 145);
    expect(aircraft.intent.assignedAltitudeFt, 3000);
  });
}
