import '../engine/simulation_engine.dart';
import '../models/aircraft_state.dart';
import '../models/simulation_event.dart';
import '../models/simulation_snapshot.dart';
import 'scenario_definition.dart';

class ScenarioRuntime {
  final ScenarioDefinition definition;
  final SimulationEngine engine;
  final Set<String> _spawnedIds = <String>{};
  final Set<String> _exitedIds = <String>{};
  int _separationLossCount = 0;

  ScenarioRuntime({
    required this.definition,
    SimulationEngine? engine,
  }) : engine = engine ??
            SimulationEngine(
              aircraft: const [],
              waypoints: definition.waypoints,
              weatherZones: definition.weatherZones,
              arrivalFlows: definition.arrivalFlows,
              holdPatterns: definition.holdPatterns,
            );

  SimulationSnapshot get snapshot => engine.snapshot;

  SimulationSnapshot tick({int speedMultiplier = 1}) {
    final multiplier = speedMultiplier < 1 ? 1 : speedMultiplier;
    for (var i = 0; i < multiplier; i++) {
      _spawnDueAircraft(engine.snapshot.elapsed);
      final snapshot = engine.tick();
      _recordSeparationLosses(snapshot);
      _markExitedAircraft(snapshot);
    }
    _spawnDueAircraft(engine.snapshot.elapsed);
    return engine.snapshot;
  }

  ScenarioResultState evaluate() {
    final snapshot = engine.snapshot;
    final reasons = <String>[];

    for (final condition in definition.failConditions) {
      if (condition.type == 'separationLoss' && _separationLossCount > 0) {
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

    final reachedDuration = snapshot.elapsed >= definition.duration;
    final exitedSafely = _allAircraftSpawned && _allSpawnedAircraftExited;

    if (_allAircraftSpawned && (reachedDuration || exitedSafely)) {
      final winReasons = <String>[];
      for (final condition in definition.winConditions) {
        if (condition.type == 'maxSeparationLosses') {
          final maxLosses = condition.value ?? 0;
          if (_separationLossCount > maxLosses) {
            return const ScenarioResultState.running();
          }
          winReasons.add('No excessive separation losses');
        }
        if (condition.type == 'allAircraftSpawned' && _allAircraftSpawned) {
          winReasons.add('All aircraft spawned');
        }
        if (condition.type == 'durationReached' && reachedDuration) {
          winReasons.add('Scenario duration reached');
        }
        if (condition.type == 'allAircraftExitedSafely' && exitedSafely) {
          winReasons.add('All aircraft exited safely');
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

  bool get _allSpawnedAircraftExited =>
      _spawnedIds.isNotEmpty && _spawnedIds.every(_exitedIds.contains);

  void _spawnDueAircraft(Duration elapsed) {
    for (final spawn in definition.aircraft) {
      if (_spawnedIds.contains(spawn.id)) continue;
      final scaledSpawnAt = Duration(
        milliseconds:
            (spawn.spawnAt.inMilliseconds / definition.densityScale).round(),
      );
      if (scaledSpawnAt <= elapsed) {
        engine.addAircraft(_scaledAircraft(spawn.initialState));
        _spawnedIds.add(spawn.id);
      }
    }
  }

  AircraftState _scaledAircraft(AircraftState aircraft) {
    final speedBoost = 1 + (definition.difficulty.clamp(1, 5) - 1) * 0.035;
    return aircraft.copyWith(
        groundSpeedKt: aircraft.groundSpeedKt * speedBoost);
  }

  void _recordSeparationLosses(SimulationSnapshot snapshot) {
    for (final result
        in snapshot.separation.where((result) => result.isLossOfSeparation)) {
      _separationLossCount += 1;
      engine.recordEvent(SimulationEvent(
        elapsed: snapshot.elapsed,
        type: 'separationLoss',
        label: 'Loss ${result.aircraftAId}/${result.aircraftBId}',
        aircraftId: result.aircraftAId,
      ));
    }
  }

  void _markExitedAircraft(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || _exitedIds.contains(aircraft.id)) continue;
      if (_isOutsideRadarRange(aircraft)) {
        _exitedIds.add(aircraft.id);
        engine.recordEvent(SimulationEvent(
          elapsed: snapshot.elapsed,
          type: 'aircraftExited',
          label: '${aircraft.callsign} exited radar',
          aircraftId: aircraft.id,
        ));
        engine.deactivateAircraft(aircraft.id);
      }
    }
  }

  bool _isOutsideRadarRange(AircraftState aircraft) {
    final distanceSquared =
        aircraft.xNm * aircraft.xNm + aircraft.yNm * aircraft.yNm;
    return distanceSquared > definition.radarRangeNm * definition.radarRangeNm;
  }
}
