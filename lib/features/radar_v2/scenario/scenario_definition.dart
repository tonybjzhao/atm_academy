import '../models/aircraft_intent.dart';
import '../models/aircraft_performance_profile.dart';
import '../models/aircraft_state.dart';
import '../models/aircraft_urgency.dart';
import '../models/altitude_restriction.dart';
import '../models/arrival_flow.dart';
import '../models/attention_management_event.dart';
import '../models/departure_flow.dart';
import '../models/hold_pattern.dart';
import '../models/route_procedure.dart';
import '../models/weather_zone.dart';
import '../models/waypoint.dart';

class ScenarioDefinition {
  final String id;
  final String title;
  final String sectorId;
  final String sectorPersonality;
  final Duration duration;
  final int difficulty;
  final double radarRangeNm;
  final String trafficDescription;
  final List<String> objectives;
  final List<String> expectedTechniques;
  final Map<String, Waypoint> waypoints;
  final Map<String, RouteProcedure> routeProcedures;
  final List<WeatherZone> weatherZones;
  final List<ArrivalFlow> arrivalFlows;
  final List<DepartureFlow> departureFlows;
  final List<HoldPattern> holdPatterns;
  final List<AltitudeRestriction> altitudeRestrictions;
  final int maxControllerLoad;
  final Duration runwayOccupancyDuration;
  final String weatherMode;
  final double lowVisibilitySpacingMultiplier;
  final double lowVisibilityRunwayOccupancyMultiplier;
  final double workloadPressureMultiplier;
  final double densityScale;
  final List<int> speedOptions;
  final List<AircraftSpawnDefinition> aircraft;
  final List<ScenarioCondition> winConditions;
  final List<ScenarioCondition> failConditions;
  final List<AttentionManagementEvent> attentionManagementEvents;

  const ScenarioDefinition({
    required this.id,
    required this.title,
    required this.sectorId,
    this.sectorPersonality = 'arrival_rush',
    required this.duration,
    required this.difficulty,
    this.radarRangeNm = 42,
    this.trafficDescription = '',
    this.objectives = const [],
    this.expectedTechniques = const [],
    this.waypoints = const {},
    this.routeProcedures = const {},
    this.weatherZones = const [],
    this.arrivalFlows = const [],
    this.departureFlows = const [],
    this.holdPatterns = const [],
    this.altitudeRestrictions = const [],
    this.maxControllerLoad = 6,
    this.runwayOccupancyDuration = const Duration(seconds: 45),
    this.weatherMode = 'normal',
    this.lowVisibilitySpacingMultiplier = 1.0,
    this.lowVisibilityRunwayOccupancyMultiplier = 1.0,
    this.workloadPressureMultiplier = 1.0,
    this.densityScale = 1,
    required this.speedOptions,
    required this.aircraft,
    required this.winConditions,
    required this.failConditions,
    this.attentionManagementEvents = const [],
  });
}

class AircraftSpawnDefinition {
  final String id;
  final String callsign;
  final Duration spawnAt;
  final bool isDeparture;
  final String? departureFlowId;
  final String? procedureId;
  final AircraftState initialState;

  const AircraftSpawnDefinition({
    required this.id,
    required this.callsign,
    required this.spawnAt,
    this.isDeparture = false,
    this.departureFlowId,
    this.procedureId,
    required this.initialState,
  });
}

class ScenarioCondition {
  final String type;
  final int? value;

  const ScenarioCondition({
    required this.type,
    this.value,
  });
}

class ScenarioResultState {
  final bool complete;
  final bool failed;
  final List<String> reasons;

  const ScenarioResultState({
    required this.complete,
    required this.failed,
    required this.reasons,
  });

  const ScenarioResultState.running()
      : complete = false,
        failed = false,
        reasons = const [];
}

AircraftState aircraftStateFromSpawn({
  required String id,
  required String callsign,
  required double xNm,
  required double yNm,
  required int altitudeFt,
  required double headingDeg,
  required double groundSpeedKt,
  int verticalSpeedFpm = 0,
  List<String> route = const [],
  int routeWaypointIndex = 0,
  AircraftPerformanceType performanceType = AircraftPerformanceType.jet,
  String? assignedRunwayId,
  String? assignedProcedureId,
  bool isDeparture = false,
  int priorityWeight = 5,
  EmergencyState emergencyState = EmergencyState.normal,
  int? fuelMinutesRemaining,
  int? medicalUrgency,
  int? unstableApproachSeverity,
}) {
  return AircraftState(
    id: id,
    callsign: callsign,
    xNm: xNm,
    yNm: yNm,
    altitudeFt: altitudeFt,
    headingDeg: headingDeg,
    groundSpeedKt: groundSpeedKt,
    verticalSpeedFpm: verticalSpeedFpm,
    intent: AircraftIntent(
      route: route,
      assignedRunwayId: assignedRunwayId,
      assignedProcedureId: assignedProcedureId,
      isDeparture: isDeparture,
    ),
    routeWaypointIndex: routeWaypointIndex,
    performanceType: performanceType,
    urgency: AircraftUrgency(
      priorityWeight: priorityWeight,
      emergencyState: emergencyState,
      fuelMinutesRemaining: fuelMinutesRemaining,
      medicalUrgency: medicalUrgency,
      unstableApproachSeverity: unstableApproachSeverity,
    ),
  );
}
