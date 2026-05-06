import 'localized_text.dart';

class ScenarioAircraftConfig {
  final String callsign;
  final double x;
  final double y;
  final double heading;
  final double speed;
  final int altitude; // FL style: 320 = FL320

  const ScenarioAircraftConfig({
    required this.callsign,
    required this.x,
    required this.y,
    required this.heading,
    required this.speed,
    required this.altitude,
  });
}

class ConflictRules {
  // V1 spec: LOS = 60 px horizontal + 10 FL (1000 ft) vertical
  //          Warning = 90 px horizontal + 15 FL (1500 ft) vertical
  final double minHorizontalDistancePx;    // LOS threshold px
  final int    minVerticalSeparationFL;    // LOS threshold FL (1 FL = 100 ft)
  final double warningHorizontalDistancePx; // Warning threshold px
  final int    warningVerticalSeparationFL; // Warning threshold FL

  const ConflictRules({
    this.minHorizontalDistancePx     = 60,
    this.minVerticalSeparationFL     = 10,
    this.warningHorizontalDistancePx = 90,
    this.warningVerticalSeparationFL = 15,
  });

  // Backward-compat aliases used by ScenarioEngine/PressureBar
  double get warningDistancePx  => warningHorizontalDistancePx;
  double get advisoryDistancePx => warningHorizontalDistancePx * 1.40;
}

class ScenarioFeedbackMessages {
  final LocalizedText success;
  final LocalizedText late;
  final LocalizedText wrong;
  final LocalizedText los;

  const ScenarioFeedbackMessages({
    required this.success,
    required this.late,
    required this.wrong,
    required this.los,
  });
}

class Scenario {
  final String id;
  final LocalizedText title;
  final int level;
  final String skill; // 'separation' | 'altitude' | 'speed' | 'mixed'
  final int timeLimitSeconds;
  final LocalizedText objective;
  final List<ScenarioAircraftConfig> aircraft;
  final ConflictRules conflictRules;
  final int maintainSafeSeparationForSeconds;
  final ScenarioFeedbackMessages feedback;

  const Scenario({
    required this.id,
    required this.title,
    required this.level,
    required this.skill,
    required this.timeLimitSeconds,
    required this.objective,
    required this.aircraft,
    required this.conflictRules,
    required this.maintainSafeSeparationForSeconds,
    required this.feedback,
  });
}
