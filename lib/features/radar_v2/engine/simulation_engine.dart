import '../commands/controller_command.dart';
import '../models/aircraft_state.dart';
import '../models/separation_result.dart';
import '../models/simulation_snapshot.dart';
import 'conflict_predictor.dart';
import 'separation_calculator.dart';
import 'trajectory_integrator.dart';

class SimulationEngine {
  final Duration fixedStep;
  final TrajectoryIntegrator trajectoryIntegrator;
  final SeparationCalculator separationCalculator;
  final ConflictPredictor conflictPredictor;
  final List<AircraftState> _aircraft;
  int _tick;
  Duration _elapsed;

  SimulationEngine({
    required Iterable<AircraftState> aircraft,
    this.fixedStep = const Duration(seconds: 1),
    this.trajectoryIntegrator = const TrajectoryIntegrator(),
    this.separationCalculator = const SeparationCalculator(),
    this.conflictPredictor = const ConflictPredictor(),
    int initialTick = 0,
    Duration initialElapsed = Duration.zero,
  })  : _aircraft = List<AircraftState>.from(aircraft, growable: true),
        _tick = initialTick,
        _elapsed = initialElapsed;

  SimulationSnapshot get snapshot => _buildSnapshot();

  SimulationSnapshot tick({int steps = 1}) {
    if (steps < 1) return snapshot;
    for (var i = 0; i < steps; i++) {
      for (var index = 0; index < _aircraft.length; index++) {
        if (!_aircraft[index].active) continue;
        _aircraft[index] =
            trajectoryIntegrator.advance(_aircraft[index], fixedStep);
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
  }

  void updateAircraft(AircraftState aircraft) {
    final index =
        _aircraft.indexWhere((existing) => existing.id == aircraft.id);
    if (index == -1) {
      throw ArgumentError('Unknown aircraft id: ${aircraft.id}');
    }
    _aircraft[index] = aircraft;
  }

  void deactivateAircraft(String aircraftId) {
    final aircraft = _aircraftById(aircraftId);
    updateAircraft(aircraft.copyWith(active: false));
  }

  void applyCommand(ControllerCommand command) {
    final aircraft = _aircraftById(command.aircraftId);
    if (command is AssignHeading) {
      updateAircraft(
        aircraft.copyWith(
          intent: aircraft.intent.copyWith(
            assignedHeadingDeg: _normalizeHeading(command.headingDeg),
          ),
        ),
      );
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
    );
  }
}
