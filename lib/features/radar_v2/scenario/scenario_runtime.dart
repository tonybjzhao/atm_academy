import 'dart:math' as math;

import '../engine/simulation_engine.dart';
import '../models/aircraft_state.dart';
import '../models/arrival_flow.dart';
import '../models/controller_alert.dart';
import '../models/departure_flow.dart';
import '../models/simulation_event.dart';
import '../models/simulation_snapshot.dart';
import 'scenario_definition.dart';

class ScenarioRuntime {
  final ScenarioDefinition definition;
  final SimulationEngine engine;
  final Set<String> _spawnedIds = <String>{};
  final Set<String> _exitedIds = <String>{};
  final Map<String, AircraftSpawnDefinition> _queuedDepartures =
      <String, AircraftSpawnDefinition>{};
  final Map<String, Duration> _lastDepartureReleaseByRunway =
      <String, Duration>{};
  final Set<String> _goAroundIssued = <String>{};
  final Map<String, ControllerAlert> _activeAlerts = <String, ControllerAlert>{};
  final Set<String> _alertsEscalatedThisTick = <String>{};
  int _separationLossCount = 0;
  double _pressureCarryOver = 0;

  ScenarioRuntime({
    required this.definition,
    SimulationEngine? engine,
  }) : engine = engine ??
            SimulationEngine(
              aircraft: const [],
              waypoints: definition.waypoints,
              weatherZones: definition.weatherZones,
              arrivalFlows: _effectiveArrivalFlows(definition),
              departureFlows: definition.departureFlows,
              holdPatterns: definition.holdPatterns,
              altitudeRestrictions: definition.altitudeRestrictions,
              maxControllerLoad: definition.maxControllerLoad,
            );

  static List<ArrivalFlow> _effectiveArrivalFlows(ScenarioDefinition def) {
    if (def.weatherMode != 'low_visibility' ||
        def.lowVisibilitySpacingMultiplier <= 1) {
      return def.arrivalFlows;
    }
    return def.arrivalFlows
        .map((flow) => ArrivalFlow(
              id: flow.id,
              runwayId: flow.runwayId,
              procedureId: flow.procedureId,
              mergeWaypointId: flow.mergeWaypointId,
              finalFixWaypointId: flow.finalFixWaypointId,
              thresholdWaypointId: flow.thresholdWaypointId,
              goAroundMergeWaypointId: flow.goAroundMergeWaypointId,
              goAroundRouteWaypointIds: flow.goAroundRouteWaypointIds,
              spacingTargetNm:
                  flow.spacingTargetNm * def.lowVisibilitySpacingMultiplier,
              stabilizedAltitudeFt: flow.stabilizedAltitudeFt,
            ))
        .toList(growable: false);
  }

  SimulationSnapshot get snapshot => engine.snapshot;

  SimulationSnapshot tick({int speedMultiplier = 1}) {
    final multiplier = speedMultiplier < 1 ? 1 : speedMultiplier;
    for (var i = 0; i < multiplier; i++) {
      _spawnDueAircraft(engine.snapshot.elapsed);
      _releaseQueuedDepartures(engine.snapshot.elapsed);
      _updateAdaptivePressure(engine.snapshot);
      final snapshot = engine.tick();
      _generateAndEscalateAlerts(snapshot);
      _evaluateGoAroundTriggers(snapshot);
      _recordSeparationLosses(snapshot);
      _markLandedAircraft(snapshot);
      _markExitedAircraft(snapshot);
    }
    _spawnDueAircraft(engine.snapshot.elapsed);
    _releaseQueuedDepartures(engine.snapshot.elapsed);
    _updateAdaptivePressure(engine.snapshot);
    _generateAndEscalateAlerts(engine.snapshot);
    return _buildSnapshotWithAlerts(engine.snapshot);
  }

  /// Builds a new snapshot including active alerts.
  SimulationSnapshot _buildSnapshotWithAlerts(SimulationSnapshot baseSnapshot) {
    return SimulationSnapshot(
      tick: baseSnapshot.tick,
      elapsed: baseSnapshot.elapsed,
      aircraft: baseSnapshot.aircraft,
      separation: baseSnapshot.separation,
      trails: baseSnapshot.trails,
      waypoints: baseSnapshot.waypoints,
      weatherZones: baseSnapshot.weatherZones,
      arrivalFlows: baseSnapshot.arrivalFlows,
      departureFlows: baseSnapshot.departureFlows,
      holdPatterns: baseSnapshot.holdPatterns,
      runwayStates: baseSnapshot.runwayStates,
      maxControllerLoad: baseSnapshot.maxControllerLoad,
      sectorPressureIndex: baseSnapshot.sectorPressureIndex,
      events: baseSnapshot.events,
      activeAlerts: List<ControllerAlert>.from(_activeAlerts.values),
    );
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
        if (spawn.isDeparture) {
          _queuedDepartures[spawn.id] = spawn;
          _spawnedIds.add(spawn.id);
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'departureQueued',
            label: '${spawn.callsign} queued for departure',
            aircraftId: spawn.id,
          ));
          continue;
        }
        _spawnAndActivate(spawn, elapsed, releasedAsDeparture: false);
      }
    }
  }

  void _spawnAndActivate(
    AircraftSpawnDefinition spawn,
    Duration elapsed, {
    required bool releasedAsDeparture,
  }) {
    final departureFlow = _departureFlowFor(spawn.departureFlowId);
    final procedure = spawn.procedureId == null
        ? null
        : definition.routeProcedures[spawn.procedureId!];
    final route = spawn.initialState.intent.route.isNotEmpty
        ? spawn.initialState.intent.route
        : (procedure?.waypointIds ?? const <String>[]);
    var state = spawn.initialState.copyWith(
      intent: spawn.initialState.intent.copyWith(
        route: route,
        assignedProcedureId: spawn.procedureId,
        isDeparture: spawn.isDeparture,
        assignedAltitudeFt:
            spawn.isDeparture ? departureFlow?.initialClimbFt : null,
      ),
      routeWaypointIndex: 0,
    );
    state = _scaledAircraft(state);
    engine.addAircraft(state);
    _spawnedIds.add(spawn.id);
    engine.recordEvent(SimulationEvent(
      elapsed: elapsed,
      type: releasedAsDeparture ? 'departureReleased' : 'sectorEntry',
      label: releasedAsDeparture
          ? '${spawn.callsign} departure released'
          : '${spawn.callsign} entered sector',
      aircraftId: spawn.id,
    ));
  }

  void _releaseQueuedDepartures(Duration elapsed) {
    if (_queuedDepartures.isEmpty) return;
    final queue = _queuedDepartures.values.toList(growable: false);
    for (final spawn in queue) {
      final flow = _departureFlowFor(spawn.departureFlowId);
      if (flow == null) {
        _spawnAndActivate(spawn, elapsed, releasedAsDeparture: true);
        _queuedDepartures.remove(spawn.id);
        continue;
      }
      if (!_canReleaseDeparture(flow, elapsed)) continue;
      _spawnAndActivate(spawn, elapsed, releasedAsDeparture: true);
      _queuedDepartures.remove(spawn.id);
      _lastDepartureReleaseByRunway[flow.runwayId] = elapsed;
      engine.occupyRunway(
        runwayId: flow.runwayId,
        duration: _scaledDuration(_effectiveRunwayOccupancy(), 0.6),
        aircraftId: spawn.id,
      );
    }
  }

  bool _canReleaseDeparture(DepartureFlow flow, Duration elapsed) {
    final state = engine.snapshot.runwayState(flow.runwayId);
    if (state != null && state.isOccupiedAt(elapsed)) {
      return false;
    }
    for (final crossing in flow.crossingRunwayIds) {
      final crossingState = engine.snapshot.runwayState(crossing);
      if (crossingState != null && crossingState.isOccupiedAt(elapsed)) {
        return false;
      }
    }
    final lastRelease = _lastDepartureReleaseByRunway[flow.runwayId];
    if (lastRelease != null &&
        elapsed - lastRelease < Duration(seconds: flow.releaseIntervalSeconds)) {
      return false;
    }
    return !_arrivalOnShortFinal(flow.runwayId);
  }

  bool _arrivalOnShortFinal(String runwayId) {
    final flow = _arrivalFlowForRunway(runwayId);
    if (flow == null) return false;
    final threshold = definition.waypoints[flow.thresholdWaypointId];
    if (threshold == null) return false;
    return engine.snapshot.aircraft.any((aircraft) {
      if (!aircraft.active || aircraft.intent.isDeparture) return false;
      if (aircraft.intent.assignedRunwayId != runwayId) return false;
      final distance = _distance(
        aircraft.xNm,
        aircraft.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      return distance <= 6;
    });
  }

  AircraftState _scaledAircraft(AircraftState aircraft) {
    final speedBoost = 1 + (definition.difficulty.clamp(1, 5) - 1) * 0.035;
    return aircraft.copyWith(
        groundSpeedKt: aircraft.groundSpeedKt * speedBoost);
  }

  void _evaluateGoAroundTriggers(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || aircraft.intent.isDeparture) continue;
      if (_goAroundIssued.contains(aircraft.id)) continue;
      final runwayId = aircraft.intent.assignedRunwayId;
      if (runwayId == null) continue;
      final flow = _arrivalFlowForRunway(runwayId);
      if (flow == null) continue;
      final threshold = definition.waypoints[flow.thresholdWaypointId];
      if (threshold == null) continue;

      final runwayState = snapshot.runwayState(runwayId);
      final distanceToThreshold = _distance(
        aircraft.xNm,
        aircraft.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      if (runwayState != null &&
          runwayState.isOccupiedAt(snapshot.elapsed) &&
          distanceToThreshold < 6 &&
          runwayState.occupiedUntil - snapshot.elapsed >=
              const Duration(seconds: 16)) {
        _executeGoAround(
          aircraft,
          flow,
          reason: 'runway occupied',
          elapsed: snapshot.elapsed,
        );
        continue;
      }
      if (_hasUnstableFinalSpacing(snapshot, aircraft, flow)) {
        _executeGoAround(
          aircraft,
          flow,
          reason: 'unstable spacing',
          elapsed: snapshot.elapsed,
        );
        continue;
      }
      if (_hasCloseFinalPair(snapshot, aircraft, flow)) {
        _executeGoAround(
          aircraft,
          flow,
          reason: 'aircraft too close on final',
          elapsed: snapshot.elapsed,
        );
      }
    }
  }

  bool _hasUnstableFinalSpacing(
    SimulationSnapshot snapshot,
    AircraftState aircraft,
    ArrivalFlow flow,
  ) {
    final threshold = definition.waypoints[flow.thresholdWaypointId];
    if (threshold == null) return false;
    final sameRunway = snapshot.aircraft.where((candidate) {
      return candidate.active &&
          !candidate.intent.isDeparture &&
          candidate.intent.assignedRunwayId == flow.runwayId;
    }).toList(growable: false);
    sameRunway.sort((a, b) {
      final ad =
          _distance(a.xNm, a.yNm, threshold.xNm, threshold.yNm);
      final bd =
          _distance(b.xNm, b.yNm, threshold.xNm, threshold.yNm);
      return ad.compareTo(bd);
    });
    final index = sameRunway.indexWhere((candidate) => candidate.id == aircraft.id);
    if (index <= 0) return false;
    final leader = sameRunway[index - 1];
    final spacing =
        _distance(aircraft.xNm, aircraft.yNm, leader.xNm, leader.yNm);
    return spacing < flow.spacingTargetNm * 0.72;
  }

  bool _hasCloseFinalPair(
    SimulationSnapshot snapshot,
    AircraftState aircraft,
    ArrivalFlow flow,
  ) {
    final threshold = definition.waypoints[flow.thresholdWaypointId];
    if (threshold == null) return false;
    final ownDistance =
        _distance(aircraft.xNm, aircraft.yNm, threshold.xNm, threshold.yNm);
    if (ownDistance > 8) return false;
    for (final candidate in snapshot.aircraft) {
      if (candidate.id == aircraft.id || !candidate.active) continue;
      if (candidate.intent.isDeparture) continue;
      if (candidate.intent.assignedRunwayId != flow.runwayId) continue;
      final candidateDistance = _distance(
        candidate.xNm,
        candidate.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      if (candidateDistance > 8) continue;
      final pairDistance = _distance(
        aircraft.xNm,
        aircraft.yNm,
        candidate.xNm,
        candidate.yNm,
      );
      if (pairDistance < math.max(2.8, flow.spacingTargetNm * 0.45)) {
        return true;
      }
    }
    return false;
  }

  void _executeGoAround(
    AircraftState aircraft,
    ArrivalFlow flow,
    {
    required String reason,
    required Duration elapsed,
  }
  ) {
    final goAroundRoute = flow.goAroundRouteWaypointIds.isNotEmpty
        ? flow.goAroundRouteWaypointIds
        : <String>[flow.mergeWaypointId, flow.finalFixWaypointId, flow.thresholdWaypointId];
    final targetAltitude = flow.stabilizedAltitudeFt + 3000;
    final updated = aircraft.copyWith(
      routeWaypointIndex: 0,
      intent: aircraft.intent.copyWith(
        route: goAroundRoute,
        assignedAltitudeFt: targetAltitude,
        assignedSpeedKt: math.max(aircraft.groundSpeedKt, 190).toDouble(),
        clearAssignedHeading: true,
        clearDirectTo: true,
        hold: false,
        clearHoldPattern: true,
      ),
    );
    _goAroundIssued.add(aircraft.id);
    _pressureCarryOver += 0.5;
    engine
      ..updateAircraft(updated)
      ..recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'goAround',
        label: '${aircraft.callsign} go-around: $reason',
        aircraftId: aircraft.id,
      ));
  }

  void _updateAdaptivePressure(SimulationSnapshot snapshot) {
    final active = snapshot.aircraft.where((item) => item.active).length;
    final occupiedRunways = snapshot.runwayStates
        .where((state) => state.isOccupiedAt(snapshot.elapsed))
        .length;
    final weatherComplexity = snapshot.weatherZones
        .fold<int>(0, (total, zone) => total + zone.severity);
    final spawnOverlap = _imminentSpawnCount(snapshot.elapsed);
    final queuePressure = _queuedDepartures.length;

    var pressure = (active / math.max(1, definition.maxControllerLoad)) - 1;
    pressure += weatherComplexity * 0.14;
    pressure += occupiedRunways * 0.24;
    pressure += spawnOverlap * 0.11;
    pressure += queuePressure * 0.18;
    pressure += _pressureCarryOver;
    pressure *= definition.workloadPressureMultiplier;
    pressure = pressure.clamp(0, 5.0);
    _pressureCarryOver = (_pressureCarryOver * 0.92).clamp(0, 2.0);

    final dynamicLoad =
        (definition.maxControllerLoad - pressure.round()).clamp(3, 9);
    engine.updateWorkloadState(
      dynamicControllerLoad: dynamicLoad,
      sectorPressureIndex: pressure,
    );
  }

  int _imminentSpawnCount(Duration elapsed) {
    var count = 0;
    for (final spawn in definition.aircraft) {
      if (_spawnedIds.contains(spawn.id)) continue;
      final scaledSpawnAt = Duration(
        milliseconds:
            (spawn.spawnAt.inMilliseconds / definition.densityScale).round(),
      );
      final delta = scaledSpawnAt - elapsed;
      if (delta >= Duration.zero && delta <= const Duration(seconds: 45)) {
        count += 1;
      }
    }
    return count;
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

  void _markLandedAircraft(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || _exitedIds.contains(aircraft.id)) continue;
      if (aircraft.intent.isDeparture) continue;
      final runwayId = aircraft.intent.assignedRunwayId;
      if (runwayId == null) continue;
      final flow = _arrivalFlowForRunway(runwayId);
      if (flow == null) continue;
      final threshold = definition.waypoints[flow.thresholdWaypointId];
      if (threshold == null) continue;
      final dx = aircraft.xNm - threshold.xNm;
      final dy = aircraft.yNm - threshold.yNm;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > 0.8 * 0.8) continue;

      _exitedIds.add(aircraft.id);
      engine
        ..occupyRunway(
          runwayId: runwayId,
          duration: _effectiveRunwayOccupancy(),
          aircraftId: aircraft.id,
        )
        ..recordEvent(SimulationEvent(
          elapsed: snapshot.elapsed,
          type: 'handoff',
          label: '${aircraft.callsign} landed and handed off',
          aircraftId: aircraft.id,
        ))
        ..deactivateAircraft(aircraft.id);
    }
  }

  Duration _effectiveRunwayOccupancy() {
    final multiplier = definition.weatherMode == 'low_visibility'
        ? definition.lowVisibilityRunwayOccupancyMultiplier
        : 1.0;
    return Duration(
      milliseconds:
          (definition.runwayOccupancyDuration.inMilliseconds * multiplier)
              .round(),
    );
  }

  Duration _scaledDuration(Duration duration, double factor) {
    return Duration(
      milliseconds: (duration.inMilliseconds * factor).round(),
    );
  }

  bool _isOutsideRadarRange(AircraftState aircraft) {
    final distanceSquared =
        aircraft.xNm * aircraft.xNm + aircraft.yNm * aircraft.yNm;
    return distanceSquared > definition.radarRangeNm * definition.radarRangeNm;
  }

  ArrivalFlow? _arrivalFlowForRunway(String runwayId) {
    for (final flow in definition.arrivalFlows) {
      if (flow.runwayId == runwayId) return flow;
    }
    return null;
  }

  DepartureFlow? _departureFlowFor(String? departureFlowId) {
    if (departureFlowId == null) return null;
    for (final flow in definition.departureFlows) {
      if (flow.id == departureFlowId) return flow;
    }
    return null;
  }

  double _distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Generates and escalates active alerts based on current snapshot conditions.
  /// Alerts compete for controller attention based on urgency hierarchy.
  void _generateAndEscalateAlerts(SimulationSnapshot snapshot) {
    _alertsEscalatedThisTick.clear();

    // Generate separation loss alerts
    for (final result in snapshot.separation) {
      if (!result.isLossOfSeparation && !result.isPredictedConflict) continue;
      final key = _alertKeyForPair(result.aircraftAId, result.aircraftBId);
      if (_activeAlerts.containsKey(key)) {
        // Update existing alert with escalation
        final existing = _activeAlerts[key]!;
        if (existing.timeToLoss != null &&
            result.timeToConflict != null &&
            result.timeToConflict!.inSeconds < existing.timeToLoss!.inSeconds) {
          final newSeverity = (existing.severity + 1).clamp(1, 10);
          _activeAlerts[key] = existing.copyWith(
            severity: newSeverity,
            timeToLoss: result.timeToConflict,
            escalationCount: existing.escalationCount + 1,
          );
          _alertsEscalatedThisTick.add(key);
        }
      } else {
        // Create new alert
        final alertType = result.isLossOfSeparation
            ? AlertType.separationLoss
            : AlertType.separationLoss; // Can refine for predicted vs actual
        _activeAlerts[key] = ControllerAlert(
          id: key,
          type: alertType,
          severity: result.isLossOfSeparation ? 10 : 5,
          createdAt: snapshot.elapsed,
          timeToLoss: result.timeToConflict,
          aircraftIds: [result.aircraftAId, result.aircraftBId],
        );
      }
    }

    // Generate runway occupancy alerts
    for (final runway in snapshot.runwayStates) {
      if (!runway.isOccupiedAt(snapshot.elapsed)) continue;
      for (final flow in definition.arrivalFlows) {
        if (flow.runwayId != runway.runwayId) continue;
        final threshold = definition.waypoints[flow.thresholdWaypointId];
        if (threshold == null) continue;
        for (final aircraft in snapshot.aircraft) {
          if (!aircraft.active ||
              aircraft.intent.isDeparture ||
              aircraft.intent.assignedRunwayId != runway.runwayId) {
            continue;
          }
          final distance = _distance(
            aircraft.xNm,
            aircraft.yNm,
            threshold.xNm,
            threshold.yNm,
          );
          if (distance >= 10) continue; // Not approaching actively

          final key = 'runway_occupancy:${runway.runwayId}:${aircraft.id}';
          if (!_activeAlerts.containsKey(key)) {
            final ttl = runway.occupiedUntil - snapshot.elapsed;
            _activeAlerts[key] = ControllerAlert(
              id: key,
              type: AlertType.runwayOccupancy,
              severity: 7,
              createdAt: snapshot.elapsed,
              timeToLoss: ttl.inSeconds > 0 ? ttl : Duration.zero,
              aircraftIds: [aircraft.id],
              runwayId: runway.runwayId,
            );
          }
        }
      }
    }

    // Generate departure queue backlog alerts
    if (_queuedDepartures.isNotEmpty) {
      final oldestQueued = _queuedDepartures.values.reduce((a, b) =>
          a.spawnAt.compareTo(b.spawnAt) < 0 ? a : b);
      final queueAge = snapshot.elapsed - oldestQueued.spawnAt;
      if (queueAge.inSeconds > 30) {
        final key = 'departure_queue:backlog';
        if (!_activeAlerts.containsKey(key)) {
          _activeAlerts[key] = ControllerAlert(
            id: key,
            type: AlertType.departureQueueBacklog,
            severity: (queueAge.inSeconds ~/ 30).clamp(1, 10),
            createdAt: snapshot.elapsed,
            aircraftIds: _queuedDepartures.keys.toList(),
          );
        } else {
          final existing = _activeAlerts[key]!;
          final newSeverity = (queueAge.inSeconds ~/ 30).clamp(1, 10);
          if (newSeverity > existing.severity) {
            _activeAlerts[key] = existing.copyWith(
              severity: newSeverity,
              escalationCount: existing.escalationCount + 1,
            );
            _alertsEscalatedThisTick.add(key);
          }
        }
      }
    }

    // Remove old/resolved alerts
    _activeAlerts.removeWhere((key, alert) {
      // Remove if no longer predicted/actual conflict
      if (alert.type == AlertType.separationLoss) {
        final pair = key.split(':');
        if (pair.length != 2) return true;
        return !snapshot.separation.any((result) =>
            (result.aircraftAId == pair[0] && result.aircraftBId == pair[1]) ||
            (result.aircraftAId == pair[1] && result.aircraftBId == pair[0]));
      }
      // Keep other alerts for now
      return false;
    });
  }

  String _alertKeyForPair(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}:${ids[1]}';
  }
}
