import 'dart:math' as math;

import '../commands/controller_command.dart';
import '../models/aircraft_state.dart';
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
  final List<AircraftState> _aircraft;
  final Map<String, List<TrailPoint>> _trailHistory =
      <String, List<TrailPoint>>{};
  final List<_PendingCommand> _pendingCommands = <_PendingCommand>[];
  final List<SimulationEvent> _events = <SimulationEvent>[];
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
    int initialTick = 0,
    Duration initialElapsed = Duration.zero,
  })  : _aircraft = List<AircraftState>.from(aircraft, growable: true),
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
        var advanced = trajectoryIntegrator.advance(guided, fixedStep);
        if (original.intent.assignedHeadingDeg == null &&
            guided.intent.assignedHeadingDeg != null &&
            (original.intent.route.isNotEmpty ||
                original.intent.directToWaypointId != null)) {
          advanced = advanced.copyWith(
            intent: advanced.intent.copyWith(clearAssignedHeading: true),
          );
        }
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
    _aircraftById(command.aircraftId);
    _pendingCommands.add(
      _PendingCommand(
        command: command,
        applyAt: _elapsed + commandAcknowledgementDelay,
      ),
    );
    _events.add(SimulationEvent(
      elapsed: _elapsed,
      type: 'commandIssued',
      label: _commandIssuedLabel(command),
      aircraftId: command.aircraftId,
    ));
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
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedHeadingDeg: _normalizeHeading(command.headingDeg),
            clearDirectTo: true,
          ),
        ),
      );
      _recordAcknowledgement(
          command, 'ACK heading ${command.headingDeg.round()}');
      return;
    }
    if (command is AssignAltitude) {
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedAltitudeFt: command.altitudeFt,
          ),
        ),
      );
      _recordAcknowledgement(
          command, 'ACK altitude ${command.altitudeFt ~/ 100}');
      return;
    }
    if (command is AssignSpeed) {
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedSpeedKt: command.speedKt,
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
    final actual = separationCalculator.calculatePairs(aircraft);
    final predicted = conflictPredictor.predictPairs(aircraft);
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
      events: List<SimulationEvent>.unmodifiable(_events),
    );
  }

  AircraftState _applyRouteGuidance(AircraftState aircraft) {
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
    return aircraft.copyWith(
      routeWaypointIndex: nextIndex,
      intent: aircraft.intent.copyWith(assignedHeadingDeg: heading),
    );
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
    return 'Issued command';
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
