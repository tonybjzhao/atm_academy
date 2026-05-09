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
  final List<_PendingExecution> _pendingExecutions = <_PendingExecution>[];
  final List<_PendingRadioEvent> _pendingRadioEvents = <_PendingRadioEvent>[];
  final List<SimulationEvent> _events = <SimulationEvent>[];
  final Set<String> _recordedBehaviorEvents = <String>{};
  final Map<String, int> _weatherInfluenceTicks = <String, int>{};
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
    this.commandAcknowledgementDelay = const Duration(milliseconds: 2600),
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
      _applyDueExecutions(_elapsed + fixedStep);
      _applyDueRadioEvents(_elapsed + fixedStep);
      for (var index = 0; index < _aircraft.length; index++) {
        if (!_aircraft[index].active) continue;
        final original = _aircraft[index];
        final guided = _applyRouteGuidance(original);
        final environment = _environmentEffectFor(guided);
        var advanced = trajectoryIntegrator.advance(
          guided,
          fixedStep,
          performance: AircraftPerformanceProfile.byType(
            guided.performanceType,
          ),
          pressureIndex: _sectorPressureIndex,
          trackWobbleDeg: environment.trackWobbleDeg,
          groundSpeedVariationKt: environment.groundSpeedVariationKt,
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
    final weatherInfluence = _weatherInfluenceFor(aircraft);
    final profileFactor = _pilotResponseProfileFactor(aircraft);
    var effectiveDelay = _getEffectiveAckDelay();
    effectiveDelay += _pilotResponseJitter(aircraft, command);
    effectiveDelay = Duration(
      milliseconds:
          (effectiveDelay.inMilliseconds * profileFactor).round().clamp(600, 11000),
    );

    if (_sectorPressureIndex >= 1.0) {
      effectiveDelay += Duration(
        milliseconds: ((_sectorPressureIndex - 0.9) * 520).round().clamp(0, 2300),
      );
    }
    if (weatherInfluence > 0.22) {
      effectiveDelay += Duration(
        milliseconds: (weatherInfluence * 950).round().clamp(0, 1300),
      );
    }

    // Under higher pressure, occasional delayed acknowledgements add
    // operational imperfection without introducing a new gameplay system.
    final delayedAckChance =
        (0.04 + _sectorPressureIndex * 0.09 + weatherInfluence * 0.16)
            .clamp(0.0, 0.42);
    if (_sectorPressureIndex >= 1.0 &&
        _noise01('${aircraft.id}:${command.runtimeType}:delay:${_tick}') <
            delayedAckChance) {
      effectiveDelay += Duration(
        milliseconds: 900 +
            (_noise01('${aircraft.id}:${command.runtimeType}:delay_mag:${_tick}') *
                    1300)
                .round(),
      );
    }
    effectiveDelay = Duration(
      milliseconds: effectiveDelay.inMilliseconds.clamp(700, 12000),
    );
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
    if (effectiveDelay - commandAcknowledgementDelay >=
        const Duration(milliseconds: 800)) {
      _recordBehaviorEvent(
        key: 'pilot_delay:${aircraft.id}',
        type: 'pilotResponseDelay',
        label: 'Delayed acknowledgement increased follow-through time.',
        aircraftId: aircraft.id,
      );
    }
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
      final command = pending.command;
      final aircraft = _aircraftById(command.aircraftId);
      _recordAcknowledgement(command, aircraft);
      final executionDelay = _executionDelayFor(aircraft, command);
      if (executionDelay > Duration.zero) {
        _pendingExecutions.add(
          _PendingExecution(
            command: command,
            applyAt: _elapsed + executionDelay,
          ),
        );
        _recordBehaviorEvent(
          key: 'pilot_exec_delay:${aircraft.id}:${command.runtimeType}:${_tick}',
          type: 'pilotExecutionDelay',
          label: 'Pilot began execution after acknowledgement due workload/weather.',
          aircraftId: aircraft.id,
        );
      } else {
        _applyCommandIntent(command);
      }
    }
  }

  void _applyDueExecutions(Duration effectiveElapsed) {
    final due = _pendingExecutions
        .where((pending) => pending.applyAt <= effectiveElapsed)
        .toList(growable: false);
    _pendingExecutions
        .removeWhere((pending) => pending.applyAt <= effectiveElapsed);
    for (final pending in due) {
      _applyCommandIntent(pending.command);
    }
  }

  void _applyDueRadioEvents(Duration effectiveElapsed) {
    final due = _pendingRadioEvents
        .where((pending) => pending.emitAt <= effectiveElapsed)
        .toList(growable: false);
    _pendingRadioEvents
        .removeWhere((pending) => pending.emitAt <= effectiveElapsed);
    for (final pending in due) {
      _events.add(SimulationEvent(
        elapsed: _elapsed,
        type: pending.type,
        label: pending.label,
        aircraftId: pending.aircraftId,
      ));
    }
  }

  void _applyCommandIntent(ControllerCommand command) {
    final aircraft = _aircraftById(command.aircraftId);
    final variability = _executionVariabilityScale(aircraft);
    if (command is AssignHeading) {
      final commandedHeading = _normalizeHeading(command.headingDeg);
      final headingOffset = _sectorPressureIndex >= 0.9
          ? _headingComplianceOffsetDeg(
              aircraft,
              command,
              variability: variability,
            )
          : 0.0;
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedHeadingDeg:
                _normalizeHeading(commandedHeading + headingOffset),
            clearDirectTo: true,
          ),
        ),
      );
      if (headingOffset.abs() >= 3.2) {
        _recordBehaviorEvent(
          key: 'pilot_late_capture:${aircraft.id}:${_tick}',
          type: 'pilotLateCapture',
          label: 'Heading capture was late and required additional settling.',
          aircraftId: aircraft.id,
        );
      }
      return;
    }
    if (command is AssignAltitude) {
      final altitudeOffset = _sectorPressureIndex >= 0.9
          ? _altitudeComplianceOffsetFt(
              aircraft,
              command,
              variability: variability,
            )
          : 0;
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedAltitudeFt:
                (command.altitudeFt + altitudeOffset).clamp(2000, 45000),
          ),
        ),
      );
      return;
    }
    if (command is AssignSpeed) {
      final speedOffset = _sectorPressureIndex >= 0.9
              ? _speedComplianceOffsetKt(
                  aircraft,
                  command,
                  variability: variability,
                )
          : 0.0;
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedSpeedKt:
                (command.speedKt + speedOffset).clamp(120, 480).toDouble(),
          ),
        ),
      );
          if (speedOffset.abs() >= 6.6) {
            _recordBehaviorEvent(
              key: 'pilot_speed_instability:${aircraft.id}:${_tick}',
              type: 'pilotSpeedInstability',
              label: 'Speed control was unstable before settling to target.',
              aircraftId: aircraft.id,
            );
          }
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
    final effectiveDuration = _effectiveRunwayOccupancyDuration(
      duration,
      aircraftId,
    );
    _runwayStates[runwayId] = RunwayState(
      runwayId: runwayId,
      occupiedUntil: _elapsed + effectiveDuration,
      occupiedByAircraftId: aircraftId,
    );
    recordEvent(SimulationEvent(
      elapsed: _elapsed,
      type: 'runwayOccupied',
      label: '$runwayId occupied',
      aircraftId: aircraftId,
    ));
    if (effectiveDuration.inMilliseconds >
        (duration.inMilliseconds * 1.08).round()) {
      _recordBehaviorEvent(
        key: 'runway_extended:$runwayId',
        type: 'runwayRecoveryExtended',
        label: 'Runway occupancy extended the recovery window.',
        aircraftId: aircraftId,
      );
    }
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
      if (_weatherInfluenceTicks[aircraft.id] != null &&
          _weatherInfluenceTicks[aircraft.id]! >= 6 &&
          _weatherInfluenceFor(aircraft) > 0.2) {
        speedTarget +=
            (_noise01('${aircraft.id}:merge:${_elapsed.inSeconds ~/ 3}') -
                    0.5) *
                5.5;
        _recordBehaviorEvent(
          key: 'weather_compression:${aircraft.id}',
          type: 'weatherCompression',
          label: 'Weather compressed spacing near the merge.',
          aircraftId: aircraft.id,
        );
      }
      if (aircraft.groundSpeedKt - speedTarget > 22 &&
          distanceToThreshold < 18) {
        _recordBehaviorEvent(
          key: 'late_speed:${aircraft.id}',
          type: 'lateSpeedControl',
          label: 'Late speed control allowed closure rate to build.',
          aircraftId: aircraft.id,
        );
      }
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

  void _recordAcknowledgement(
    ControllerCommand command,
    AircraftState aircraft,
  ) {
    final readback = _readbackFor(command, aircraft);
    _events.add(SimulationEvent(
      elapsed: _elapsed,
      type: 'commandAcknowledged',
      label: readback.primary,
      aircraftId: command.aircraftId,
    ));
    if (readback.style == _ReadbackStyle.concise) {
      _recordBehaviorEvent(
        key: 'pilot_readback_concise:${aircraft.id}:${_tick}',
        type: 'pilotReadbackConcise',
        label: 'Pilot used a concise acknowledgement readback.',
        aircraftId: aircraft.id,
      );
    }
    if (readback.style == _ReadbackStyle.partial) {
      _recordBehaviorEvent(
        key: 'pilot_readback_partial:${aircraft.id}:${_tick}',
        type: 'pilotReadbackPartial',
        label: 'Pilot provided a partial readback before full execution.',
        aircraftId: aircraft.id,
      );
    }
    if (readback.delayedConfirmation != null) {
      _pendingRadioEvents.add(
        _PendingRadioEvent(
          emitAt: _elapsed + readback.confirmationDelay,
          type: 'pilotReadbackConfirm',
          label: readback.delayedConfirmation!,
          aircraftId: aircraft.id,
        ),
      );
      _recordBehaviorEvent(
        key: 'pilot_readback_confirm_delay:${aircraft.id}:${_tick}',
        type: 'pilotReadbackConfirmDelay',
        label: 'Pilot confirmation arrived slightly after the initial readback.',
        aircraftId: aircraft.id,
      );
    }
  }

  String _commandIssuedLabel(ControllerCommand command) {
    if (command is AssignHeading) {
      return 'Command sent: heading ${command.headingDeg.round()}';
    }
    if (command is AssignAltitude) {
      return 'Command sent: altitude ${command.altitudeFt ~/ 100}';
    }
    if (command is AssignSpeed) {
      return 'Command sent: speed ${command.speedKt.round()}';
    }
    if (command is DirectToWaypoint) {
      return 'Command sent: direct ${command.waypointId}';
    }
    if (command is EnterHold) {
      return 'Command sent: hold ${command.holdPatternId}';
    }
    if (command is ExitHold) {
      return 'Command sent: exit hold';
    }
    return 'Command sent';
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
    final baseMilliseconds = switch (profile.type) {
      AircraftPerformanceType.jet => 650,
      AircraftPerformanceType.regional => 470,
      AircraftPerformanceType.turboprop => 340,
    };
    final noise = _noise01(
      '${aircraft.id}:${command.runtimeType}:${_elapsed.inSeconds}:${_tick}',
    );
    final pressureExtra = _sectorPressureIndex >= 0.8
        ? (_sectorPressureIndex * 230).round()
        : 0;
    final weatherExtra = _weatherInfluenceFor(aircraft) >= 0.2
        ? (_weatherInfluenceFor(aircraft) * 260).round()
        : 0;
    return Duration(
      milliseconds:
          (baseMilliseconds + noise * 700 + pressureExtra + weatherExtra)
              .round(),
    );
  }

  double _headingComplianceOffsetDeg(
    AircraftState aircraft,
    ControllerCommand command, {
    required double variability,
  }
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
    return (noise - 0.5) * 2 * maxOffset * variability;
  }

  int _altitudeComplianceOffsetFt(
    AircraftState aircraft,
    ControllerCommand command, {
    required double variability,
  }
  ) {
    final noise = _noise01(
      '${aircraft.id}:alt:${command.runtimeType}:${_elapsed.inSeconds}',
    );
    // Keep deviation small enough to remain operationally plausible.
    return ((noise - 0.5) * 2 * 120 * variability).round();
  }

  double _speedComplianceOffsetKt(
    AircraftState aircraft,
    ControllerCommand command, {
    required double variability,
  }
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
    return (noise - 0.5) * 2 * maxOffset * variability;
  }

  Duration _executionDelayFor(
    AircraftState aircraft,
    ControllerCommand command,
  ) {
    final weather = _weatherInfluenceFor(aircraft);
    final workload = (_sectorPressureIndex - 0.7).clamp(0.0, 2.5);
    var chance = 0.02 + workload * 0.06 + weather * 0.14;
    var minMs = 700;
    var maxMs = 2000;

    if (command is AssignAltitude && command.altitudeFt < aircraft.altitudeFt) {
      chance += 0.12;
      minMs = 1300;
      maxMs = 4200;
      if (_sectorPressureIndex >= 1.8 && weather > 0.45) {
        final magNoise = _noise01(
          '${aircraft.id}:${command.runtimeType}:forced_descent_delay:${_tick}:${_elapsed.inSeconds}',
        );
        final lagMs = 1800 + (magNoise * 2400).round();
        return Duration(milliseconds: lagMs.clamp(1600, 4600));
      }
    } else if (command is AssignHeading || command is DirectToWaypoint) {
      chance += 0.08;
      minMs = 900;
      maxMs = 2800;
    } else if (command is AssignSpeed) {
      chance += 0.06;
      minMs = 800;
      maxMs = 2400;
    }

    if (weather > 0.48 && (command is AssignHeading || command is DirectToWaypoint)) {
      chance = chance.clamp(0.0, 0.9).toDouble();
      minMs = math.max(minMs, 1800);
      maxMs = math.max(maxMs, 3400);
      _recordBehaviorEvent(
        key: 'weather_compliance_delay:${aircraft.id}:${_tick}',
        type: 'weatherComplianceDelay',
        label: 'Weather deviation delayed turn/direct compliance.',
        aircraftId: aircraft.id,
      );
    }

    chance = chance.clamp(0.0, 0.58);
    final triggerNoise = _noise01(
      '${aircraft.id}:${command.runtimeType}:exec_trigger:${_tick}:${_elapsed.inSeconds}',
    );
    if (triggerNoise >= chance) return Duration.zero;
    final magNoise = _noise01(
      '${aircraft.id}:${command.runtimeType}:exec_delay:${_tick}:${_elapsed.inSeconds}',
    );
    final lagMs = minMs + ((maxMs - minMs) * magNoise).round();
    return Duration(milliseconds: lagMs.clamp(600, 5200));
  }

  _ReadbackResult _readbackFor(
    ControllerCommand command,
    AircraftState aircraft,
  ) {
    final pressure = _sectorPressureIndex.clamp(0.0, 3.0);
    final weather = _weatherInfluenceFor(aircraft);
    final conciseChance = (0.18 + pressure * 0.05).clamp(0.12, 0.38);
    final partialChance = (0.06 + pressure * 0.06 + weather * 0.12)
        .clamp(0.04, 0.32);
    final styleNoise = _noise01(
      '${aircraft.id}:${command.runtimeType}:readback_style:${_tick}:${_elapsed.inSeconds}',
    );
    var style = _ReadbackStyle.standard;
    if (styleNoise < partialChance) {
      style = _ReadbackStyle.partial;
    } else if (styleNoise < partialChance + conciseChance) {
      style = _ReadbackStyle.concise;
    }

    final payload = _commandReadbackPayload(command);
    final callsign = aircraft.callsign;
    final base = switch (style) {
      _ReadbackStyle.standard => 'ACK ${payload.long}',
      _ReadbackStyle.concise => '$callsign ${payload.long}.',
      _ReadbackStyle.partial => '$callsign ${payload.short}.',
    };

    final confirmationChance =
        (0.08 + pressure * 0.05 + weather * 0.1).clamp(0.04, 0.36);
    final confirmationNoise = _noise01(
      '${aircraft.id}:${command.runtimeType}:readback_confirm:${_tick}:${_elapsed.inSeconds}',
    );
    if (style == _ReadbackStyle.partial && confirmationNoise < confirmationChance) {
      final delay = Duration(
        milliseconds: 900 +
            (_noise01('${aircraft.id}:${command.runtimeType}:confirm_delay:${_tick}') *
                    1300)
                .round(),
      );
      return _ReadbackResult(
        style: style,
        primary: base,
        delayedConfirmation: '$callsign confirming ${payload.long}.',
        confirmationDelay: delay,
      );
    }
    return _ReadbackResult(
      style: style,
      primary: base,
      delayedConfirmation: null,
      confirmationDelay: Duration.zero,
    );
  }

  _ReadbackPayload _commandReadbackPayload(ControllerCommand command) {
    if (command is AssignHeading) {
      final heading = command.headingDeg.round();
      return _ReadbackPayload(long: 'heading $heading', short: 'heading');
    }
    if (command is AssignAltitude) {
      return _ReadbackPayload(
        long: 'altitude ${command.altitudeFt ~/ 100}',
        short: 'altitude',
      );
    }
    if (command is AssignSpeed) {
      return _ReadbackPayload(
        long: 'speed ${command.speedKt.round()}',
        short: 'speed',
      );
    }
    if (command is DirectToWaypoint) {
      return _ReadbackPayload(long: 'direct ${command.waypointId}', short: 'direct');
    }
    if (command is EnterHold) {
      return _ReadbackPayload(long: 'hold ${command.holdPatternId}', short: 'hold');
    }
    if (command is ExitHold) {
      return const _ReadbackPayload(long: 'exit hold', short: 'hold');
    }
    return const _ReadbackPayload(long: 'received', short: 'received');
  }

  double _pilotResponseProfileFactor(AircraftState aircraft) {
    final profile = AircraftPerformanceProfile.byType(aircraft.performanceType);
    final typeBias = switch (profile.type) {
      AircraftPerformanceType.jet => 1.04,
      AircraftPerformanceType.regional => 0.98,
      AircraftPerformanceType.turboprop => 0.92,
    };
    final personal =
        0.84 + _noise01('${aircraft.id}:pilot_profile') * 0.34; // 0.84..1.18
    return (typeBias * personal).clamp(0.78, 1.24);
  }

  double _executionVariabilityScale(AircraftState aircraft) {
    final weather = _weatherInfluenceFor(aircraft);
    final workload = (_sectorPressureIndex / 3.0).clamp(0.0, 1.0);
    final pilot = 0.92 + _noise01('${aircraft.id}:pilot_variability') * 0.26;
    return (pilot + workload * 0.2 + weather * 0.24).clamp(0.85, 1.42);
  }

  double _noise01(String seed) {
    var hash = 2166136261;
    for (var i = 0; i < seed.length; i++) {
      hash ^= seed.codeUnitAt(i);
      hash = (hash * 16777619) & 0xffffffff;
    }
    return (hash % 10000) / 10000.0;
  }

  _EnvironmentEffect _environmentEffectFor(AircraftState aircraft) {
    final influence = _weatherInfluenceFor(aircraft);
    if (influence <= 0) {
      _weatherInfluenceTicks.remove(aircraft.id);
      return const _EnvironmentEffect.none();
    }
    _weatherInfluenceTicks[aircraft.id] =
        (_weatherInfluenceTicks[aircraft.id] ?? 0) + 1;
    final phase = _elapsed.inSeconds ~/ 2;
    final wobbleNoise = _noise01('${aircraft.id}:wx_track:$phase') - 0.5;
    final speedNoise = _noise01('${aircraft.id}:wx_speed:$phase') - 0.5;
    final pressure = (0.65 + _sectorPressureIndex * 0.16).clamp(0.65, 1.35);
    final wobble = wobbleNoise * 2 * influence * pressure * 1.2;
    final speed = speedNoise * 2 * influence * pressure * 4.5;
    if (influence > 0.28 && _weatherInfluenceTicks[aircraft.id]! >= 6) {
      _recordBehaviorEvent(
        key: 'weather_wobble:${aircraft.id}',
        type: 'weatherInteraction',
        label: 'Weather compressed spacing near the merge.',
        aircraftId: aircraft.id,
      );
    }
    return _EnvironmentEffect(
      trackWobbleDeg: wobble.clamp(-2.2, 2.2),
      groundSpeedVariationKt: speed.clamp(-7.0, 7.0),
    );
  }

  double _weatherInfluenceFor(AircraftState aircraft) {
    var influence = 0.0;
    for (final zone in weatherZones) {
      final distance =
          _distance(aircraft.xNm, aircraft.yNm, zone.xNm, zone.yNm);
      final edge = zone.radiusNm + 4;
      if (distance > edge) continue;
      final proximity = 1 - (distance / edge).clamp(0.0, 1.0);
      influence =
          math.max(influence, proximity * (0.45 + zone.severity * 0.18));
    }
    return influence.clamp(0.0, 1.0);
  }

  Duration _effectiveRunwayOccupancyDuration(
    Duration baseDuration,
    String aircraftId,
  ) {
    AircraftState? aircraft;
    for (final candidate in _aircraft) {
      if (candidate.id == aircraftId) {
        aircraft = candidate;
        break;
      }
    }
    final typeFactor = switch (aircraft?.performanceType) {
      AircraftPerformanceType.jet => 1.08,
      AircraftPerformanceType.regional => 1.0,
      AircraftPerformanceType.turboprop => 0.92,
      null => 1.0,
    };
    final weatherFactor =
        weatherZones.isEmpty ? 1.0 : 1.0 + (0.03 * _sectorPressureIndex);
    final noise =
        (_noise01('$aircraftId:runway:${_elapsed.inSeconds}') - 0.5) * 0.08;
    final factor = (typeFactor * weatherFactor + noise).clamp(0.84, 1.28);
    return Duration(
      milliseconds: (baseDuration.inMilliseconds * factor).round(),
    );
  }

  void _recordBehaviorEvent({
    required String key,
    required String type,
    required String label,
    String? aircraftId,
  }) {
    if (!_recordedBehaviorEvents.add(key)) return;
    _events.add(SimulationEvent(
      elapsed: _elapsed,
      type: type,
      label: label,
      aircraftId: aircraftId,
    ));
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

class _PendingExecution {
  final ControllerCommand command;
  final Duration applyAt;

  const _PendingExecution({
    required this.command,
    required this.applyAt,
  });
}

class _PendingRadioEvent {
  final Duration emitAt;
  final String type;
  final String label;
  final String aircraftId;

  const _PendingRadioEvent({
    required this.emitAt,
    required this.type,
    required this.label,
    required this.aircraftId,
  });
}

enum _ReadbackStyle {
  standard,
  concise,
  partial,
}

class _ReadbackPayload {
  final String long;
  final String short;

  const _ReadbackPayload({
    required this.long,
    required this.short,
  });
}

class _ReadbackResult {
  final _ReadbackStyle style;
  final String primary;
  final String? delayedConfirmation;
  final Duration confirmationDelay;

  const _ReadbackResult({
    required this.style,
    required this.primary,
    required this.delayedConfirmation,
    required this.confirmationDelay,
  });
}

class _EnvironmentEffect {
  final double trackWobbleDeg;
  final double groundSpeedVariationKt;

  const _EnvironmentEffect({
    required this.trackWobbleDeg,
    required this.groundSpeedVariationKt,
  });

  const _EnvironmentEffect.none()
      : trackWobbleDeg = 0,
        groundSpeedVariationKt = 0;
}
