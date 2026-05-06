import 'dart:convert';

class AircraftReplayState {
  final String callsign;
  final double x;
  final double y;
  final double heading;
  final double speed;
  final int    altitude;
  final bool   wasSelected;
  final bool   wasConflicting;

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
    'callsign':       callsign,
    'x':              x,
    'y':              y,
    'heading':        heading,
    'speed':          speed,
    'altitude':       altitude,
    'wasSelected':    wasSelected,
    'wasConflicting': wasConflicting,
  };
}

/// All data passed to Unity's ScenarioReplayManager.LoadReplayData().
/// Flutter builds this at scenario end; Unity only visualises — it does
/// not recalculate any score or conflict logic.
class ScenarioReplayData {
  final String scenarioId;
  final String scenarioTitle;

  // Aircraft states
  final List<AircraftReplayState> initialAircraft;
  final List<AircraftReplayState> finalAircraft;

  // Conflict details (for Unity to colour and annotate)
  final List<String> conflictPairCallsigns;  // e.g. ['QFA123', 'UAE406']
  final double closestPointPxX;              // Flutter coords of conflict midpoint
  final double closestPointPxY;
  final double closestPointTimeSec;
  final double thresholdHorizontalPx;        // LOS threshold
  final int    thresholdVerticalFt;          // LOS vertical threshold in ft

  // User action (for Unity timeline marker)
  final double actionTimeSec;                // when first command was issued (0 = none)
  final String userCommandSummary;           // e.g. "Turned QFA123 left 15°"

  // Score / rating (Unity overlay — not recalculated)
  final double minHorizDist;
  final bool   hadLOS;
  final int    score;
  final String ratingKey;

  // Breakdown (Unity overlay)
  final List<String> penaltyBreakdown;
  final List<String> bonusBreakdown;

  const ScenarioReplayData({
    required this.scenarioId,
    required this.scenarioTitle,
    required this.initialAircraft,
    required this.finalAircraft,
    required this.conflictPairCallsigns,
    required this.closestPointPxX,
    required this.closestPointPxY,
    required this.closestPointTimeSec,
    required this.thresholdHorizontalPx,
    required this.thresholdVerticalFt,
    required this.actionTimeSec,
    required this.userCommandSummary,
    required this.minHorizDist,
    required this.hadLOS,
    required this.score,
    required this.ratingKey,
    required this.penaltyBreakdown,
    required this.bonusBreakdown,
  });

  /// JSON string sent to Unity via postMessage.
  String toJson() => jsonEncode({
    'scenarioId':              scenarioId,
    'scenarioTitle':           scenarioTitle,
    'initialAircraft':         initialAircraft.map((a) => a.toMap()).toList(),
    'finalAircraft':           finalAircraft.map((a) => a.toMap()).toList(),
    'conflictPairCallsigns':   conflictPairCallsigns,
    'closestPointPxX':         closestPointPxX,
    'closestPointPxY':         closestPointPxY,
    'closestPointTimeSec':     closestPointTimeSec,
    'thresholdHorizontalPx':   thresholdHorizontalPx,
    'thresholdVerticalFt':     thresholdVerticalFt,
    'actionTimeSec':           actionTimeSec,
    'userCommandSummary':      userCommandSummary,
    'minHorizDist':            minHorizDist,
    'hadLOS':                  hadLOS,
    'score':                   score,
    'ratingKey':               ratingKey,
    'penaltyBreakdown':        penaltyBreakdown,
    'bonusBreakdown':          bonusBreakdown,
  });
}
