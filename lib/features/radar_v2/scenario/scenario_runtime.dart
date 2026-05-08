import '../engine/simulation_engine.dart';
import '../models/simulation_snapshot.dart';
import 'scenario_definition.dart';

class ScenarioRuntime {
  final ScenarioDefinition definition;
  final SimulationEngine engine;
  final Set<String> _spawnedIds = <String>{};

  ScenarioRuntime({
    required this.definition,
    SimulationEngine? engine,
  }) : engine = engine ?? SimulationEngine(aircraft: const []);

  SimulationSnapshot get snapshot => engine.snapshot;

  SimulationSnapshot tick({int speedMultiplier = 1}) {
    final multiplier = speedMultiplier < 1 ? 1 : speedMultiplier;
    for (var i = 0; i < multiplier; i++) {
      _spawnDueAircraft(engine.snapshot.elapsed);
      engine.tick();
    }
    _spawnDueAircraft(engine.snapshot.elapsed);
    return engine.snapshot;
  }

  ScenarioResultState evaluate() {
    final snapshot = engine.snapshot;
    final reasons = <String>[];
    final losses =
        snapshot.separation.where((result) => result.isLossOfSeparation).length;

    for (final condition in definition.failConditions) {
      if (condition.type == 'separationLoss' && losses > 0) {
        reasons.add('Separation loss detected');
      }
      if (condition.type == 'timeout' &&
          snapshot.elapsed >= definition.duration &&
          !_allAircraftSpawned) {
        reasons.add('Scenario timed out before all traffic spawned');
      }
    }

    if (reasons.isNotEmpty) {
      return ScenarioResultState(
          complete: true, failed: true, reasons: reasons);
    }

    if (snapshot.elapsed >= definition.duration || _allAircraftSpawned) {
      final winReasons = <String>[];
      for (final condition in definition.winConditions) {
        if (condition.type == 'maxSeparationLosses') {
          final maxLosses = condition.value ?? 0;
          if (losses > maxLosses) return const ScenarioResultState.running();
          winReasons.add('No excessive separation losses');
        }
        if (condition.type == 'allAircraftSpawned' && _allAircraftSpawned) {
          winReasons.add('All aircraft spawned');
        }
      }
      if (winReasons.isNotEmpty) {
        return ScenarioResultState(
          complete: true,
          failed: false,
          reasons: winReasons,
        );
      }
    }

    return const ScenarioResultState.running();
  }

  bool get _allAircraftSpawned =>
      _spawnedIds.length == definition.aircraft.length;

  void _spawnDueAircraft(Duration elapsed) {
    for (final spawn in definition.aircraft) {
      if (_spawnedIds.contains(spawn.id)) continue;
      if (spawn.spawnAt <= elapsed) {
        engine.addAircraft(spawn.initialState);
        _spawnedIds.add(spawn.id);
      }
    }
  }
}
