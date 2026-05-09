import 'arrival_flow.dart';
import 'aircraft_state.dart';
import 'controller_alert.dart';
import 'departure_flow.dart';
import 'hold_pattern.dart';
import 'runway_state.dart';
import 'separation_result.dart';
import 'simulation_event.dart';
import 'trail_point.dart';
import 'weather_zone.dart';
import 'waypoint.dart';
import '../core/attention/attention_focus_state.dart';
import '../core/cognitive_load/cognitive_load_state.dart';
import '../core/alerts/operational_alert.dart';
import '../core/mental_model/cognitive_cascade_state.dart';
import '../core/mental_model/controller_expectation_state.dart';
import '../core/mental_model/predictive_mental_model_state.dart';
import '../core/mental_model/working_memory_state.dart';
import '../core/psychology/scenario_pressure_phase.dart';

class SimulationSnapshot {
  final int tick;
  final Duration elapsed;
  final List<AircraftState> aircraft;
  final List<SeparationResult> separation;
  final Map<String, List<TrailPoint>> trails;
  final Map<String, Waypoint> waypoints;
  final List<WeatherZone> weatherZones;
  final List<ArrivalFlow> arrivalFlows;
  final List<DepartureFlow> departureFlows;
  final List<HoldPattern> holdPatterns;
  final List<RunwayState> runwayStates;
  final int maxControllerLoad;
  final double sectorPressureIndex;
  final List<SimulationEvent> events;
  final List<ControllerAlert> activeAlerts;
  final Set<String> activeDistractions;
  final double distractionEfficiencyPenalty;
  // Decision Pressure Engine V1 fields
  final CognitiveLoadState cognitiveLoad;
  final List<OperationalAlert> operationalAlerts;
  final AttentionFocusState attentionFocus;
  final List<String> attentionReportLines;
  final ScenarioPsychologyState psychologyState;
  final ControllerExpectationState expectationState;
  final PredictiveMentalModelState predictiveMentalModelState;
  final List<String> predictiveMentalModelReportLines;
  final CognitiveCascadeState cognitiveCascadeState;
  final List<String> cognitiveCascadeReportLines;
  final WorkingMemoryState workingMemoryState;
  final List<String> workingMemoryReportLines;

  const SimulationSnapshot({
    required this.tick,
    required this.elapsed,
    required this.aircraft,
    required this.separation,
    this.trails = const {},
    this.waypoints = const {},
    this.weatherZones = const [],
    this.arrivalFlows = const [],
    this.departureFlows = const [],
    this.holdPatterns = const [],
    this.runwayStates = const [],
    this.maxControllerLoad = 6,
    this.sectorPressureIndex = 0,
    this.events = const [],
    this.activeAlerts = const [],
    this.activeDistractions = const {},
    this.distractionEfficiencyPenalty = 1.0,
    this.cognitiveLoad = CognitiveLoadState.idle,
    this.operationalAlerts = const [],
    this.attentionFocus = AttentionFocusState.idle,
    this.attentionReportLines = const [],
    this.psychologyState = ScenarioPsychologyState.idle,
    this.expectationState = ControllerExpectationState.idle,
    this.predictiveMentalModelState = PredictiveMentalModelState.idle,
    this.predictiveMentalModelReportLines = const [],
    this.cognitiveCascadeState = CognitiveCascadeState.idle,
    this.cognitiveCascadeReportLines = const [],
    this.workingMemoryState = WorkingMemoryState.idle,
    this.workingMemoryReportLines = const [],
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
