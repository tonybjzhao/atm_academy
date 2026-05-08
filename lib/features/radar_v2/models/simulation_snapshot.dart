import 'arrival_flow.dart';
import 'aircraft_state.dart';
import 'hold_pattern.dart';
import 'runway_state.dart';
import 'separation_result.dart';
import 'simulation_event.dart';
import 'trail_point.dart';
import 'weather_zone.dart';
import 'waypoint.dart';

class SimulationSnapshot {
  final int tick;
  final Duration elapsed;
  final List<AircraftState> aircraft;
  final List<SeparationResult> separation;
  final Map<String, List<TrailPoint>> trails;
  final Map<String, Waypoint> waypoints;
  final List<WeatherZone> weatherZones;
  final List<ArrivalFlow> arrivalFlows;
  final List<HoldPattern> holdPatterns;
  final List<RunwayState> runwayStates;
  final int maxControllerLoad;
  final List<SimulationEvent> events;

  const SimulationSnapshot({
    required this.tick,
    required this.elapsed,
    required this.aircraft,
    required this.separation,
    this.trails = const {},
    this.waypoints = const {},
    this.weatherZones = const [],
    this.arrivalFlows = const [],
    this.holdPatterns = const [],
    this.runwayStates = const [],
    this.maxControllerLoad = 6,
    this.events = const [],
  });

  AircraftState? aircraftById(String id) {
    for (final target in aircraft) {
      if (target.id == id) return target;
    }
    return null;
  }

  List<TrailPoint> trailFor(String aircraftId) {
    return trails[aircraftId] ?? const [];
  }

  RunwayState? runwayState(String runwayId) {
    for (final state in runwayStates) {
      if (state.runwayId == runwayId) return state;
    }
    return null;
  }
}
