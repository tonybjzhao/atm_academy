import '../models/aircraft_intent.dart';
import '../models/aircraft_performance_profile.dart';
import '../models/aircraft_state.dart';
import '../models/arrival_flow.dart';
import '../models/hold_pattern.dart';
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
  final List<WeatherZone> weatherZones;
  final List<ArrivalFlow> arrivalFlows;
  final List<HoldPattern> holdPatterns;
  final double densityScale;
  final List<int> speedOptions;
  final List<AircraftSpawnDefinition> aircraft;
  final List<ScenarioCondition> winConditions;
  final List<ScenarioCondition> failConditions;

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
    this.weatherZones = const [],
    this.arrivalFlows = const [],
    this.holdPatterns = const [],
    this.densityScale = 1,
    required this.speedOptions,
    required this.aircraft,
    required this.winConditions,
    required this.failConditions,
  });
}

class AircraftSpawnDefinition {
  final String id;
  final String callsign;
  final Duration spawnAt;
  final AircraftState initialState;

  const AircraftSpawnDefinition({
    required this.id,
    required this.callsign,
    required this.spawnAt,
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
    intent: AircraftIntent(route: route, assignedRunwayId: assignedRunwayId),
    routeWaypointIndex: routeWaypointIndex,
    performanceType: performanceType,
  );
}
