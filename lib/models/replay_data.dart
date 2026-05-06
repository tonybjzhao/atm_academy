import 'dart:convert';

/// Snapshot of one aircraft at a specific moment in the scenario.
class AircraftReplayState {
  final String callsign;
  final double x;
  final double y;
  final double heading; // degrees
  final double speed;
  final int altitude;   // FL style: 320 = FL320
  final bool wasSelected;   // user selected this aircraft
  final bool wasConflicting; // was part of the conflict pair

  const AircraftReplayState({
    required this.callsign,
    required this.x,
    required this.y,
    required this.heading,
    required this.speed,
    required this.altitude,
    required this.wasSelected,
    required this.wasConflicting,
  });

  Map<String, dynamic> toMap() => {
        'callsign': callsign,
        'x': x,
        'y': y,
        'heading': heading,
        'speed': speed,
        'altitude': altitude,
        'wasSelected': wasSelected,
        'wasConflicting': wasConflicting,
      };
}

/// All data needed for the Unity 3D replay.
/// Flutter builds this at scenario end and passes it to UnityReplayScreen.
class ScenarioReplayData {
  final String scenarioId;
  final String scenarioTitle; // already localised for display

  /// Aircraft at scenario start (from config — used as Unity spawn positions).
  final List<AircraftReplayState> initialAircraft;

  /// Aircraft at scenario end (final positions after user commands).
  final List<AircraftReplayState> finalAircraft;

  /// Closest horizontal distance reached during the scenario (px).
  final double minHorizDist;

  /// Whether loss of separation occurred.
  final bool hadLOS;

  /// 0–120 points.
  final int score;

  /// 'ratingExcellent' | 'ratingSafe' | 'ratingNeedsImprovement' | 'ratingUnsafe'
  final String ratingKey;

  const ScenarioReplayData({
    required this.scenarioId,
    required this.scenarioTitle,
    required this.initialAircraft,
    required this.finalAircraft,
    required this.minHorizDist,
    required this.hadLOS,
    required this.score,
    required this.ratingKey,
  });

  /// JSON string sent to Unity via platform channel / flutter_unity_widget.
  String toJson() => jsonEncode({
        'scenarioId': scenarioId,
        'scenarioTitle': scenarioTitle,
        'initialAircraft': initialAircraft.map((a) => a.toMap()).toList(),
        'finalAircraft': finalAircraft.map((a) => a.toMap()).toList(),
        'minHorizDist': minHorizDist,
        'hadLOS': hadLOS,
        'score': score,
        'ratingKey': ratingKey,
      });
}
