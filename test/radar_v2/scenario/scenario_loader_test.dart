import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_loader.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_runtime.dart';

void main() {
  const source = '''
{
  "id": "test_scenario",
  "title": "Test Scenario",
  "sectorId": "test_sector",
  "durationSeconds": 120,
  "difficulty": 3,
  "speedOptions": [1, 2, 4],
  "aircraft": [
    {
      "id": "a",
      "callsign": "QFA214",
      "spawnAtSeconds": 0,
      "position": { "xNm": -10, "yNm": 0 },
      "altitudeFt": 9000,
      "headingDeg": 90,
      "groundSpeedKt": 300
    },
    {
      "id": "b",
      "callsign": "VJA612",
      "spawnAtSeconds": 5,
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
    expect(scenario.speedOptions, [1, 2, 4]);
    expect(scenario.aircraft, hasLength(2));
    expect(scenario.aircraft.last.spawnAt, const Duration(seconds: 5));
  });

  test('runtime spawns aircraft dynamically from elapsed time', () {
    final scenario = const ScenarioLoader().parse(source);
    final runtime = ScenarioRuntime(definition: scenario);

    expect(runtime.tick().aircraft.map((aircraft) => aircraft.id), ['a']);
    runtime.tick(speedMultiplier: 4);

    expect(
      runtime.snapshot.aircraft.map((aircraft) => aircraft.id).toList(),
      ['a', 'b'],
    );
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
}
