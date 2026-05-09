import 'dart:math' as math;

import '../commands/controller_command.dart';
import '../models/aircraft_performance_profile.dart';
import '../models/aircraft_state.dart';
import '../models/altitude_restriction.dart';
import '../models/arrival_flow.dart';
import '../models/departure_flow.dart';
import '../models/hold_pattern.dart';
import '../models/runway_state.dart';
import '../models/separation_result.dart';
import '../models/simulation_event.dart';
import '../models/simulation_snapshot.dart';
import '../models/trail_point.dart';
import '../models/weather_zone.dart';
import '../models/waypoint.dart';
import 'conflict_predictor.dart';
import 'separation_calculator.dart';
import 'trajectory_integrator.dart';

class SimulationEngine {
  final Duration fixedStep;
  final TrajectoryIntegrator trajectoryIntegrator;
  final SeparationCalculator separationCalculator;
  final ConflictPredictor conflictPredictor;
  final int maxTrailPoints;
  final Duration commandAcknowledgementDelay;
  final Map<String, Waypoint> waypoints;
  final List<WeatherZone> weatherZones;
  final List<ArrivalFlow> arrivalFlows;
  final List<DepartureFlow> departureFlows;
  final List<HoldPattern> holdPatterns;
  final List<AltitudeRestriction> altitudeRestrictions;
  final int maxControllerLoad;
  final List<AircraftState> _aircraft;
  final Map<String, RunwayState> _runwayStates = <String, RunwayState>{};
  final Map<String, List<TrailPoint>> _trailHistory =
      <String, List<TrailPoint>>{};
  final List<_PendingCommand> _pendingCommands = <_PendingCommand>[];
  final List<SimulationEvent> _events = <SimulationEvent>[];
  int _dynamicControllerLoad;
  double _sectorPressureIndex = 0;
  int _tick;
  Duration _elapsed;

  SimulationEngine({
    required Iterable<AircraftState> aircraft,
    this.fixedStep = const Duration(seconds: 1),
    this.trajectoryIntegrator = const TrajectoryIntegrator(),
    this.separationCalculator = const SeparationCalculator(),
    this.conflictPredictor = const ConflictPredictor(),
    this.maxTrailPoints = 28,
    this.commandAcknowledgementDelay = const Duration(seconds: 3),
    this.waypoints = const {},
    this.weatherZones = const [],
    this.arrivalFlows = const [],
    this.departureFlows = const [],
    this.holdPatterns = const [],
    this.altitudeRestrictions = const [],
    this.maxControllerLoad = 6,
    int initialTick = 0,
    Duration initialElapsed = Duration.zero,
  })  : _aircraft = List<AircraftState>.from(aircraft, growable: true),
        _dynamicControllerLoad = maxControllerLoad,
        _tick = initialTick,
        _elapsed = initialElapsed {
    for (final aircraft in _aircraft) {
      _recordTrailPoint(aircraft);
    }
  }

  SimulationSnapshot get snapshot => _buildSnapshot();

  SimulationSnapshot tick({int steps = 1}) {
    if (steps < 1) return snapshot;
    for (var i = 0; i < steps; i++) {
      _applyDueCommands(_elapsed + fixedStep);
      for (var index = 0; index < _aircraft.length; index++) {
        if (!_aircraft[index].active) continue;
        final original = _aircraft[index];
        final guided = _applyRouteGuidance(original);
        var advanced = trajectoryIntegrator.advance(
          guided,
          fixedStep,
          performance: AircraftPerformanceProfile.byType(
            guided.performanceType,
          ),
          pressureIndex: _sectorPressureIndex,
        );
        if (original.intent.assignedHeadingDeg == null &&
            guided.intent.assignedHeadingDeg != null &&
            (original.intent.route.isNotEmpty ||
                original.intent.directToWaypointId != null ||
                original.intent.hold)) {
          advanced = advanced.copyWith(
            intent: advanced.intent.copyWith(clearAssignedHeading: true),
          );
        }
        advanced = advanced.copyWith(
          airborneSeconds: advanced.airborneSeconds + fixedStep.inSeconds,
          cumulativeHoldSeconds: advanced.cumulativeHoldSeconds +
              (advanced.intent.hold ? fixedStep.inSeconds : 0),
          cumulativeVectorSeconds: advanced.cumulativeVectorSeconds +
              (_isVectoring(advanced) ? fixedStep.inSeconds : 0),
        );
        _aircraft[index] = advanced;
        _recordTrailPoint(_aircraft[index]);
      }
      _tick += 1;
      _elapsed += fixedStep;
    }
    return _buildSnapshot();
  }

  void addAircraft(AircraftState aircraft) {
    if (_aircraft.any((existing) => existing.id == aircraft.id)) {
      throw ArgumentError('Duplicate aircraft id: ${aircraft.id}');
    }
    _aircraft.add(aircraft);
    _recordTrailPoint(aircraft);
  }

  void updateAircraft(AircraftState aircraft) {
    final index =
        _aircraft.indexWhere((existing) => existing.id == aircraft.id);
    if (index == -1) {
      throw ArgumentError('Unknown aircraft id: ${aircraft.id}');
    }
    _aircraft[index] = aircraft;
    _recordTrailPoint(aircraft);
  }

  void deactivateAircraft(String aircraftId) {
    final aircraft = _aircraftById(aircraftId);
    updateAircraft(aircraft.copyWith(active: false));
  }

  void applyCommand(ControllerCommand command) {
    final aircraft = _aircraftById(command.aircraftId);
    var effectiveDelay = _getEffectiveAckDelay();
    if (_sectorPressureIndex >= 0.8) {
      effectiveDelay += _pilotResponseJitter(aircraft, command);
    }

    // Under higher pressure, occasional delayed acknowledgements add
    // operational imperfection without introducing a new gameplay system.
    final delayedAckChance = (_sectorPressureIndex * 0.08).clamp(0.0, 0.24);
    if (_sectorPressureIndex >= 1.0 &&
        _noise01('${aircraft.id}:${command.runtimeType}:delay:${_tick}') <
            delayedAckChance) {
      effectiveDelay += const Duration(milliseconds: 900);
    }
    if (effectiveDelay < const Duration(milliseconds: 700)) {
      effectiveDelay = const Duration(milliseconds: 700);
    }
    _pendingCommands.add(
      _PendingCommand(
        command: command,
        applyAt: _elapsed + effectiveDelay,
      ),
    );
    _events.add(SimulationEvent(
      elapsed: _elapsed,
      type: 'commandIssued',
      label: _commandIssuedLabel(command),
      aircraftId: command.aircraftId,
    ));
  }

  /// Calculates effective acknowledgement delay based on current sector pressure.
  /// Under low pressure (0–1.0): base 3s
  /// Under moderate pressure (1.0–2.0): 3s → 4.5s
  /// Under high pressure (2.0–3.0): 4.5s → 6s
  /// Under extreme pressure (3.0+): 6s+
  Duration _getEffectiveAckDelay() {
    final pressureRatio = (_sectorPressureIndex / 3.0).clamp(0, 2);
    final extraDelaySeconds = pressureRatio * 3.0; // 0 to 6 extra seconds
    return commandAcknowledgementDelay +
        Duration(milliseconds: (extraDelaySeconds * 1000).round());
  }

  void recordEvent(SimulationEvent event) {
    _events.add(event);
  }

  void updateWorkloadState({
    required int dynamicControllerLoad,
    required double sectorPressureIndex,
  }) {
    _dynamicControllerLoad = dynamicControllerLoad;
    _sectorPressureIndex = sectorPressureIndex;
  }

  void _applyDueCommands(Duration effectiveElapsed) {
    final due = _pendingCommands
        .where((pending) => pending.applyAt <= effectiveElapsed)
        .toList(growable: false);
    _pendingCommands
        .removeWhere((pending) => pending.applyAt <= effectiveElapsed);
    for (final pending in due) {
      _applyAcknowledgedCommand(pending.command);
    }
  }

  void _applyAcknowledgedCommand(ControllerCommand command) {
    final aircraft = _aircraftById(command.aircraftId);
    if (command is AssignHeading) {
      final commandedHeading = _normalizeHeading(command.headingDeg);
      final headingOffset =
          _sectorPressureIndex >= 0.9 ? _headingComplianceOffsetDeg(aircraft, command) : 0.0;
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedHeadingDeg:
                _normalizeHeading(commandedHeading + headingOffset),
            clearDirectTo: true,
          ),
        ),
      );
      _recordAcknowledgement(
          command, 'ACK heading ${command.headingDeg.round()}');
      return;
    }
    if (command is AssignAltitude) {
      final altitudeOffset = _sectorPressureIndex >= 0.9
          ? _altitudeComplianceOffsetFt(aircraft, command)
          : 0;
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedAltitudeFt:
                (command.altitudeFt + altitudeOffset).clamp(2000, 45000),
          ),
        ),
      );
      _recordAcknowledgement(
          command, 'ACK altitude ${command.altitudeFt ~/ 100}');
      return;
    }
    if (command is AssignSpeed) {
      final speedOffset =
          _sectorPressureIndex >= 0.9 ? _speedComplianceOffsetKt(aircraft, command) : 0.0;
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedSpeedKt:
                (command.speedKt + speedOffset).clamp(120, 480).toDouble(),
          ),
        ),
      );
      _recordAcknowledgement(command, 'ACK speed ${command.speedKt.round()}');
      return;
    }
    if (command is DirectToWaypoint) {
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            directToWaypointId: command.waypointId,
            clearAssignedHeading: true,
          ),
        ),
      );
      _recordAcknowledgement(command, 'ACK direct ${command.waypointId}');
      return;
    }
    if (command is EnterHold) {
      updateAircraft(
        aircraft.copyWith(
          holdElapsedSeconds: 0,
          intent: aircraft.intent.copyWith(
            hold: true,
            holdPatternId: command.holdPatternId,
            clearAssignedHeading: true,
            clearDirectTo: true,
          ),
        ),
      );
      _recordAcknowledgement(command, 'ACK hold ${command.holdPatternId}');
      return;
    }
    if (command is ExitHold) {
      updateAircraft(
        aircraft.copyWith(
          holdElapsedSeconds: 0,
          intent: aircraft.intent.copyWith(
            hold: false,
            clearAssignedHeading: true,
            clearHoldPattern: true,
          ),
        ),
      );
      _recordAcknowledgement(command, 'ACK exit hold');
      return;
    }
  }

  AircraftState _aircraftById(String aircraftId) {
    for (final aircraft in _aircraft) {
      if (aircraft.id == aircraftId) return aircraft;
    }
    throw ArgumentError('Unknown aircraft id: $aircraftId');
  }

  double _normalizeHeading(double headingDeg) {
    final normalized = headingDeg % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  SimulationSnapshot _buildSnapshot() {
    final aircraft = List<AircraftState>.unmodifiable(_aircraft);
    final actual = separationCalculator.calculatePairs(
      aircraft,
      pressureIndex: _sectorPressureIndex,
    );
    final predicted = conflictPredictor.predictPairs(
      aircraft,
      pressureIndex: _sectorPressureIndex,
    );
    return SimulationSnapshot(
      tick: _tick,
      elapsed: _elapsed,
      aircraft: aircraft,
      separation:
          List<SeparationResult>.unmodifiable([...actual, ...predicted]),
      trails: Map<String, List<TrailPoint>>.unmodifiable(
        _trailHistory.map(
          (id, points) => MapEntry(id, List<TrailPoint>.unmodifiable(points)),
        ),
      ),
      waypoints: Map<String, Waypoint>.unmodifiable(waypoints),
      weatherZones: List<WeatherZone>.unmodifiable(weatherZones),
      arrivalFlows: List<ArrivalFlow>.unmodifiable(arrivalFlows),
      departureFlows: List<DepartureFlow>.unmodifiable(departureFlows),
      holdPatterns: List<HoldPattern>.unmodifiable(holdPatterns),
      runwayStates: List<RunwayState>.unmodifiable(_runwayStates.values),
      maxControllerLoad: _dynamicControllerLoad,
      sectorPressureIndex: _sectorPressureIndex,
      events: List<SimulationEvent>.unmodifiable(_events),
    );
  }

  void occupyRunway({
    required String runwayId,
    required Duration duration,
    required String aircraftId,
  }) {
    _runwayStates[runwayId] = RunwayState(
      runwayId: runwayId,
      occupiedUntil: _elapsed + duration,
      occupiedByAircraftId: aircraftId,
    );
    recordEvent(SimulationEvent(
      elapsed: _elapsed,
      type: 'runwayOccupied',
      label: '$runwayId occupied',
      aircraftId: aircraftId,
    ));
  }

  AircraftState _applyRouteGuidance(AircraftState aircraft) {
    if (aircraft.intent.hold && aircraft.intent.holdPatternId != null) {
      return _applyHoldGuidance(aircraft);
    }
    final directId = aircraft.intent.directToWaypointId;
    final route = aircraft.intent.route;
    final waypointId = directId ??
        (aircraft.routeWaypointIndex < route.length
            ? route[aircraft.routeWaypointIndex]
            : null);
    if (waypointId == null || aircraft.intent.assignedHeadingDeg != null) {
      return aircraft;
    }
    final waypoint = waypoints[waypointId];
    if (waypoint == null) return aircraft;
    final dx = waypoint.xNm - aircraft.xNm;
    final dy = waypoint.yNm - aircraft.yNm;
    final distance = math.sqrt(dx * dx + dy * dy);
    var nextIndex = aircraft.routeWaypointIndex;
    if (distance < 1.2 && directId == null && nextIndex < route.length - 1) {
      nextIndex += 1;
    }
    final heading =
        _bearingTo(aircraft.xNm, aircraft.yNm, waypoint.xNm, waypoint.yNm);
    final approach = _approachIntentFor(aircraft);
    final restriction = _restrictionFor(waypointId);
    final altitudeTarget =
        _altitudeTargetForRestriction(aircraft, restriction) ?? approach?.$2;
    final speedTarget = approach?.$1;
    return aircraft.copyWith(
      routeWaypointIndex: nextIndex,
      intent: aircraft.intent.copyWith(
        assignedHeadingDeg: heading,
        assignedSpeedKt: speedTarget,
        assignedAltitudeFt: altitudeTarget,
      ),
    );
  }

  (double, int)? _approachIntentFor(AircraftState aircraft) {
    final runwayId = aircraft.intent.assignedRunwayId;
    if (runwayId == null) return null;
    final flow = _arrivalFlowForRunway(runwayId);
    if (flow == null) return null;
    final finalFix = waypoints[flow.finalFixWaypointId];
    final threshold = waypoints[flow.thresholdWaypointId];
    if (finalFix == null || threshold == null) return null;
    final distanceToThreshold =
        _distance(aircraft.xNm, aircraft.yNm, threshold.xNm, threshold.yNm);
    final distanceToFinal =
        _distance(aircraft.xNm, aircraft.yNm, finalFix.xNm, finalFix.yNm);
    if (distanceToThreshold > 18 && distanceToFinal > 8) return null;
    final profile = AircraftPerformanceProfile.byType(aircraft.performanceType);
    var speedTarget = distanceToThreshold < 8
        ? profile.approachSpeedKt
        : math.max(profile.approachSpeedKt + 35, 180).toDouble();

    if (_sectorPressureIndex >= 0.8) {
      speedTarget += _mergeSpacingAdjustmentKt(aircraft, flow, threshold);

      // Small deterministic variation avoids mathematically perfect spacing.
      speedTarget +=
        (_noise01('${aircraft.id}:approach:${_elapsed.inSeconds}') - 0.5) *
          2.8;
    }
    speedTarget = speedTarget.clamp(profile.approachSpeedKt - 5, 330);
    return (speedTarget, flow.stabilizedAltitudeFt);
  }

  double _mergeSpacingAdjustmentKt(
    AircraftState aircraft,
    ArrivalFlow flow,
    Waypoint threshold,
  ) {
    final sameFlow = _aircraft.where((candidate) {
      return candidate.active &&
          !candidate.intent.isDeparture &&
          candidate.id != aircraft.id &&
          candidate.intent.assignedRunwayId == flow.runwayId;
    }).toList(growable: false);
    if (sameFlow.isEmpty) return 0;

    final ownDistance =
        _distance(aircraft.xNm, aircraft.yNm, threshold.xNm, threshold.yNm);
    double? nearestAhead;
    for (final candidate in sameFlow) {
      final candidateDistance =
          _distance(candidate.xNm, candidate.yNm, threshold.xNm, threshold.yNm);
      if (candidateDistance >= ownDistance) continue;
      final gap = ownDistance - candidateDistance;
      if (nearestAhead == null || gap < nearestAhead) {
        nearestAhead = gap;
      }
    }

    if (nearestAhead == null) return 0;

    if (nearestAhead < flow.spacingTargetNm * 0.95) {
      return -10;
    }
    if (nearestAhead > flow.spacingTargetNm * 1.9) {
      return 6;
    }
    return 0;
  }

  ArrivalFlow? _arrivalFlowForRunway(String runwayId) {
    for (final flow in arrivalFlows) {
      if (flow.runwayId == runwayId) return flow;
    }
    return null;
  }

  AltitudeRestriction? _restrictionFor(String waypointId) {
    for (final restriction in altitudeRestrictions) {
      if (restriction.waypointId == waypointId) return restriction;
    }
    return null;
  }

  int? _altitudeTargetForRestriction(
    AircraftState aircraft,
    AltitudeRestriction? restriction,
  ) {
    if (restriction == null) return null;
    switch (restriction.type) {
      case AltitudeRestrictionType.at:
        return restriction.altitudeFt;
      case AltitudeRestrictionType.atOrAbove:
        if (aircraft.altitudeFt < restriction.altitudeFt) {
          return restriction.altitudeFt;
        }
        return aircraft.intent.assignedAltitudeFt;
      case AltitudeRestrictionType.atOrBelow:
        if (aircraft.altitudeFt > restriction.altitudeFt) {
          return restriction.altitudeFt;
        }
        return aircraft.intent.assignedAltitudeFt;
    }
  }

  AircraftState _applyHoldGuidance(AircraftState aircraft) {
    final pattern = _holdPatternById(aircraft.intent.holdPatternId);
    if (pattern == null) return aircraft;
    final fix = waypoints[pattern.fixWaypointId];
    if (fix == null) return aircraft;

    final distanceToFix =
        _distance(aircraft.xNm, aircraft.yNm, fix.xNm, fix.yNm);
    if (distanceToFix > 1.5 && aircraft.holdElapsedSeconds == 0) {
      return aircraft.copyWith(
        intent: aircraft.intent.copyWith(
          assignedHeadingDeg:
              _bearingTo(aircraft.xNm, aircraft.yNm, fix.xNm, fix.yNm),
        ),
      );
    }

    const turnSeconds = 30;
    final cycleSeconds = pattern.legSeconds * 2 + turnSeconds * 2;
    final nextElapsed =
        (aircraft.holdElapsedSeconds + fixedStep.inSeconds) % cycleSeconds;
    final firstLegEnd = pattern.legSeconds / cycleSeconds;
    final firstTurnEnd = (pattern.legSeconds + turnSeconds) / cycleSeconds;
    final secondLegEnd = (pattern.legSeconds * 2 + turnSeconds) / cycleSeconds;
    final phase = nextElapsed / cycleSeconds;
    final heading = phase < firstLegEnd
        ? pattern.inboundHeadingDeg
        : phase < firstTurnEnd
            ? pattern.inboundHeadingDeg + 90
            : phase < secondLegEnd
                ? pattern.inboundHeadingDeg + 180
                : pattern.inboundHeadingDeg + 270;

    return aircraft.copyWith(
      holdElapsedSeconds: nextElapsed.toDouble(),
      intent: aircraft.intent.copyWith(
        assignedHeadingDeg: _normalizeHeading(heading),
        assignedAltitudeFt: _holdStackAltitude(aircraft, pattern),
      ),
    );
  }

  int _holdStackAltitude(AircraftState aircraft, HoldPattern pattern) {
    final lowerAircraft = _aircraft.where((candidate) {
      return candidate.id != aircraft.id &&
          candidate.active &&
          candidate.intent.holdPatternId == pattern.id;
    }).length;
    return pattern.stackAltitudeFt + lowerAircraft * 1000;
  }

  void _recordTrailPoint(AircraftState aircraft) {
    if (!aircraft.active) return;
    final points = _trailHistory.putIfAbsent(aircraft.id, () => <TrailPoint>[]);
    if (points.isNotEmpty) {
      final last = points.last;
      if (last.xNm == aircraft.xNm && last.yNm == aircraft.yNm) return;
    }
    points.add(TrailPoint(
      xNm: aircraft.xNm,
      yNm: aircraft.yNm,
      elapsed: _elapsed,
    ));
    if (points.length > maxTrailPoints) {
      points.removeRange(0, points.length - maxTrailPoints);
    }
  }

  double _bearingTo(double fromX, double fromY, double toX, double toY) {
    final headingRad = math.atan2(toX - fromX, toY - fromY);
    return _normalizeHeading(headingRad * 180 / math.pi);
  }

  double _distance(double fromX, double fromY, double toX, double toY) {
    final dx = fromX - toX;
    final dy = fromY - toY;
    return math.sqrt(dx * dx + dy * dy);
  }

  HoldPattern? _holdPatternById(String? id) {
    if (id == null) return null;
    for (final pattern in holdPatterns) {
      if (pattern.id == id) return pattern;
    }
    return null;
  }

  void _recordAcknowledgement(ControllerCommand command, String label) {
    _events.add(SimulationEvent(
      elapsed: _elapsed,
      type: 'commandAcknowledged',
      label: label,
      aircraftId: command.aircraftId,
    ));
  }

  String _commandIssuedLabel(ControllerCommand command) {
    if (command is AssignHeading) {
      return 'Issued heading ${command.headingDeg.round()}';
    }
    if (command is AssignAltitude) {
      return 'Issued altitude ${command.altitudeFt ~/ 100}';
    }
    if (command is AssignSpeed) {
      return 'Issued speed ${command.speedKt.round()}';
    }
    if (command is DirectToWaypoint) {
      return 'Issued direct ${command.waypointId}';
    }
    if (command is EnterHold) {
      return 'Issued hold ${command.holdPatternId}';
    }
    if (command is ExitHold) {
      return 'Issued exit hold';
    }
    return 'Issued command';
  }

  bool _isVectoring(AircraftState aircraft) {
    if (aircraft.intent.hold) return false;
    return aircraft.intent.assignedHeadingDeg != null &&
        (aircraft.intent.route.isNotEmpty ||
            aircraft.intent.assignedProcedureId != null);
  }

  Duration _pilotResponseJitter(
    AircraftState aircraft,
    ControllerCommand command,
  ) {
    final profile = AircraftPerformanceProfile.byType(aircraft.performanceType);
    final baseSeconds = switch (profile.type) {
      AircraftPerformanceType.jet => 0.45,
      AircraftPerformanceType.regional => 0.35,
      AircraftPerformanceType.turboprop => 0.30,
    };
    final noise = _noise01(
      '${aircraft.id}:${command.runtimeType}:${_elapsed.inSeconds}:${_tick}',
    );
    final jitterSeconds = (noise - 0.5) * 2 * baseSeconds;
    return Duration(milliseconds: (jitterSeconds * 1000).round());
  }

  double _headingComplianceOffsetDeg(
    AircraftState aircraft,
    ControllerCommand command,
  ) {
    final profile = AircraftPerformanceProfile.byType(aircraft.performanceType);
    final maxOffset = switch (profile.type) {
      AircraftPerformanceType.jet => 2.2,
      AircraftPerformanceType.regional => 1.8,
      AircraftPerformanceType.turboprop => 1.4,
    };
    final noise = _noise01(
      '${aircraft.id}:hdg:${command.runtimeType}:${_elapsed.inSeconds}',
    );
    return (noise - 0.5) * 2 * maxOffset;
  }

  int _altitudeComplianceOffsetFt(
    AircraftState aircraft,
    ControllerCommand command,
  ) {
    final noise = _noise01(
      '${aircraft.id}:alt:${command.runtimeType}:${_elapsed.inSeconds}',
    );
    // Keep deviation small enough to remain operationally plausible.
    return ((noise - 0.5) * 2 * 120).round();
  }

  double _speedComplianceOffsetKt(
    AircraftState aircraft,
    ControllerCommand command,
  ) {
    final profile = AircraftPerformanceProfile.byType(aircraft.performanceType);
    final maxOffset = switch (profile.type) {
      AircraftPerformanceType.jet => 6.0,
      AircraftPerformanceType.regional => 4.5,
      AircraftPerformanceType.turboprop => 3.5,
    };
    final noise = _noise01(
      '${aircraft.id}:spd:${command.runtimeType}:${_elapsed.inSeconds}',
    );
    return (noise - 0.5) * 2 * maxOffset;
  }

  double _noise01(String seed) {
    final hash = seed.hashCode & 0x7fffffff;
    return (hash % 10000) / 10000.0;
  }
}

class _PendingCommand {
  final ControllerCommand command;
  final Duration applyAt;

  const _PendingCommand({
    required this.command,
    required this.applyAt,
  });
}
