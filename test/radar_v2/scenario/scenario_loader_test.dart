import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_loader.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_runtime.dart';

void main() {
  const source = '''
{
  "id": "test_scenario",
  "title": "Test Scenario",
  "sectorId": "test_sector",
  "sectorPersonality": "crossing_overflight",
  "durationSeconds": 120,
  "difficulty": 3,
  "radarRangeNm": 42,
  "maxControllerLoad": 4,
  "weatherMode": "low_visibility",
  "lowVisibilitySpacingMultiplier": 1.2,
  "lowVisibilityRunwayOccupancyMultiplier": 1.3,
  "workloadPressureMultiplier": 1.1,
  "runwayOccupancySeconds": 40,
  "waypoints": [
    { "id": "FIXA", "xNm": 0, "yNm": 10 },
    { "id": "RWY01", "xNm": 0, "yNm": 0 }
  ],
  "routeProcedures": [
    {
      "id": "STAR_A",
      "name": "STAR A",
      "type": "star",
      "waypoints": ["FIXA", "RWY01"],
      "mergeWaypointId": "FIXA"
    },
    {
      "id": "SID_A",
      "name": "SID A",
      "type": "sid",
      "waypoints": ["RWY01", "FIXA"]
    }
  ],
  "weatherZones": [
    { "id": "WX", "xNm": 2, "yNm": 3, "radiusNm": 4, "severity": 2 }
  ],
  "arrivalFlows": [
    {
      "id": "test_flow",
      "runwayId": "RWY01",
      "procedureId": "STAR_A",
      "mergeWaypointId": "FIXA",
      "finalFixWaypointId": "FIXA",
      "thresholdWaypointId": "RWY01",
      "spacingTargetNm": 7,
      "stabilizedAltitudeFt": 3000
    }
  ],
  "departureFlows": [
    {
      "id": "dep_flow",
      "runwayId": "RWY01",
      "sidProcedureId": "SID_A",
      "releaseIntervalSeconds": 30,
      "crossingRunwayIds": [],
      "initialClimbFt": 6000
    }
  ],
  "holdPatterns": [
    {
      "id": "FIXA_HOLD",
      "fixWaypointId": "FIXA",
      "inboundHeadingDeg": 180,
      "legSeconds": 45,
      "stackAltitudeFt": 8000
    }
  ],
  "altitudeRestrictions": [
    { "waypointId": "FIXA", "altitudeFt": 4000, "type": "atOrBelow" }
  ],
  "densityScale": 1.2,
  "speedOptions": [1, 2, 4],
  "aircraft": [
    {
      "id": "a",
      "callsign": "QFA214",
      "spawnAtSeconds": 0,
      "position": { "xNm": -10, "yNm": 0 },
      "altitudeFt": 9000,
      "headingDeg": 90,
      "groundSpeedKt": 300,
      "performanceType": "regional",
      "procedureId": "STAR_A",
      "runwayId": "RWY01"
    },
    {
      "id": "b",
      "callsign": "VJA612",
      "spawnAtSeconds": 5,
      "isDeparture": true,
      "departureFlowId": "dep_flow",
      "procedureId": "SID_A",
      "position": { "xNm": 10, "yNm": 0 },
      "altitudeFt": 10000,
      "headingDeg": 270,
      "groundSpeedKt": 300
    }
  ],
  "winConditions": [
    { "type": "allAircraftSpawned" },
    { "type": "maxSeparationLosses", "value": 0 }
  ],
  "failConditions": [
    { "type": "separationLoss" },
    { "type": "timeout" }
  ]
}
''';

  test('parses scenario JSON', () {
    final scenario = const ScenarioLoader().parse(source);

    expect(scenario.id, 'test_scenario');
    expect(scenario.difficulty, 3);
    expect(scenario.sectorPersonality, 'crossing_overflight');
    expect(scenario.speedOptions, [1, 2, 4]);
    expect(scenario.waypoints['FIXA']?.yNm, 10);
    expect(scenario.weatherZones.single.id, 'WX');
    expect(scenario.arrivalFlows.single.spacingTargetNm, 7);
    expect(scenario.holdPatterns.single.stackAltitudeFt, 8000);
    expect(scenario.altitudeRestrictions.single.altitudeFt, 4000);
    expect(scenario.maxControllerLoad, 4);
    expect(scenario.runwayOccupancyDuration, const Duration(seconds: 40));
    expect(scenario.weatherMode, 'low_visibility');
    expect(scenario.lowVisibilitySpacingMultiplier, 1.2);
    expect(scenario.routeProcedures['STAR_A']?.name, 'STAR A');
    expect(scenario.departureFlows.single.sidProcedureId, 'SID_A');
    expect(scenario.densityScale, 1.2);
    expect(scenario.aircraft, hasLength(2));
    expect(
        scenario.aircraft.first.initialState.intent.assignedRunwayId, 'RWY01');
    expect(scenario.aircraft.last.isDeparture, isTrue);
    expect(scenario.aircraft.last.procedureId, 'SID_A');
    expect(scenario.aircraft.last.spawnAt, const Duration(seconds: 5));
  });

  test('runtime spawns aircraft dynamically from elapsed time', () {
    final scenario = const ScenarioLoader().parse(source);
    final runtime = ScenarioRuntime(definition: scenario);

    expect(runtime.tick().aircraft.map((aircraft) => aircraft.id), ['a']);
    runtime.tick(speedMultiplier: 4);

    expect(
      runtime.snapshot.aircraft.map((aircraft) => aircraft.id),
      contains('a'),
    );
  });

  test('runtime queues and releases departures on runway availability', () {
    final scenario = const ScenarioLoader().parse(source);
    final runtime = ScenarioRuntime(definition: scenario);

    runtime.tick(speedMultiplier: 40);

    expect(runtime.snapshot.events.map((event) => event.type),
        contains('departureReleased'));
  });

  test('scenario does not complete immediately after all aircraft spawn', () {
    final scenario = const ScenarioLoader().parse(source);
    final runtime = ScenarioRuntime(definition: scenario);

    runtime.tick(speedMultiplier: 5);

    expect(runtime.snapshot.aircraft, hasLength(2));
    expect(runtime.evaluate().complete, isFalse);
  });

  test(
      'scenario completes after duration when all aircraft spawned with no loss',
      () {
    final scenario = const ScenarioLoader().parse(source);
    final runtime = ScenarioRuntime(definition: scenario);

    runtime.tick(speedMultiplier: 120);

    final result = runtime.evaluate();
    expect(result.complete, isTrue);
    expect(result.failed, isFalse);
  });

  test('scenario can complete early when all aircraft exit safely', () {
    const exitSource = '''
{
  "id": "exit_scenario",
  "title": "Exit Scenario",
  "sectorId": "test_sector",
  "durationSeconds": 120,
  "difficulty": 1,
  "radarRangeNm": 0.05,
  "speedOptions": [1],
  "aircraft": [
    {
      "id": "a",
      "callsign": "QFA214",
      "spawnAtSeconds": 0,
      "position": { "xNm": 0, "yNm": 0 },
      "altitudeFt": 9000,
      "headingDeg": 90,
      "groundSpeedKt": 360
    }
  ],
  "winConditions": [
    { "type": "allAircraftSpawned" },
    { "type": "allAircraftExitedSafely" },
    { "type": "maxSeparationLosses", "value": 0 }
  ],
  "failConditions": [
    { "type": "separationLoss" },
    { "type": "timeout" }
  ]
}
''';
    final scenario = const ScenarioLoader().parse(exitSource);
    final runtime = ScenarioRuntime(definition: scenario);

    runtime.tick();

    final result = runtime.evaluate();
    expect(result.complete, isTrue);
    expect(result.failed, isFalse);
  });

  test('landing aircraft occupy runway and hand off cleanly', () {
    const landingSource = '''
{
  "id": "landing_scenario",
  "title": "Landing Scenario",
  "sectorId": "test_sector",
  "durationSeconds": 120,
  "difficulty": 1,
  "radarRangeNm": 42,
  "runwayOccupancySeconds": 35,
  "waypoints": [
    { "id": "FINAL", "xNm": 0, "yNm": 2 },
    { "id": "RWY", "xNm": 0, "yNm": 0 }
  ],
  "arrivalFlows": [
    {
      "id": "flow",
      "runwayId": "RWY",
      "mergeWaypointId": "FINAL",
      "finalFixWaypointId": "FINAL",
      "thresholdWaypointId": "RWY",
      "spacingTargetNm": 6,
      "stabilizedAltitudeFt": 3000
    }
  ],
  "speedOptions": [1],
  "aircraft": [
    {
      "id": "a",
      "callsign": "QFA214",
      "spawnAtSeconds": 0,
      "position": { "xNm": 0, "yNm": 0.2 },
      "altitudeFt": 3000,
      "headingDeg": 180,
      "groundSpeedKt": 120,
      "runwayId": "RWY",
      "route": ["RWY"]
    }
  ],
  "winConditions": [
    { "type": "allAircraftSpawned" },
    { "type": "allAircraftExitedSafely" },
    { "type": "maxSeparationLosses", "value": 0 }
  ],
  "failConditions": [
    { "type": "separationLoss" },
    { "type": "timeout" }
  ]
}
''';
    final scenario = const ScenarioLoader().parse(landingSource);
    final runtime = ScenarioRuntime(definition: scenario);

    runtime.tick();

    expect(runtime.snapshot.aircraftById('a')!.active, isFalse);
    expect(runtime.snapshot.runwayState('RWY')?.occupiedByAircraftId, 'a');
    expect(
      runtime.snapshot.events.map((event) => event.type),
      contains('handoff'),
    );
  });

  test('unstable final spacing can trigger go-around event', () {
    const goAroundSource = '''
{
  "id": "go_around_scenario",
  "title": "Go Around Scenario",
  "sectorId": "test_sector",
  "durationSeconds": 120,
  "difficulty": 2,
  "radarRangeNm": 42,
  "speedOptions": [1],
  "waypoints": [
    { "id": "FINAL", "xNm": 0, "yNm": 5 },
    { "id": "RWY", "xNm": 0, "yNm": 0 }
  ],
  "arrivalFlows": [
    {
      "id": "flow",
      "runwayId": "RWY",
      "mergeWaypointId": "FINAL",
      "finalFixWaypointId": "FINAL",
      "thresholdWaypointId": "RWY",
      "goAroundRoute": ["FINAL", "RWY"],
      "spacingTargetNm": 6,
      "stabilizedAltitudeFt": 3000
    }
  ],
  "aircraft": [
    {
      "id": "lead",
      "callsign": "QFA111",
      "spawnAtSeconds": 0,
      "position": { "xNm": 0, "yNm": 2.4 },
      "altitudeFt": 3000,
      "headingDeg": 180,
      "groundSpeedKt": 160,
      "runwayId": "RWY",
      "route": ["FINAL", "RWY"]
    },
    {
      "id": "trail",
      "callsign": "VJA222",
      "spawnAtSeconds": 0,
      "position": { "xNm": 0, "yNm": 4.8 },
      "altitudeFt": 3200,
      "headingDeg": 180,
      "groundSpeedKt": 170,
      "runwayId": "RWY",
      "route": ["FINAL", "RWY"]
    }
  ],
  "winConditions": [{ "type": "allAircraftSpawned" }],
  "failConditions": [{ "type": "timeout" }]
}
''';
    final scenario = const ScenarioLoader().parse(goAroundSource);
    final runtime = ScenarioRuntime(definition: scenario);

    runtime.tick(speedMultiplier: 2);

    expect(runtime.snapshot.events.map((event) => event.type),
        contains('goAround'));
  });
}
