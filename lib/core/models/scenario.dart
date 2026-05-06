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
  final double minHorizontalDistancePx; // LOS threshold
  final int minVerticalSeparationFL;    // must BOTH be below to count as LOS

  const ConflictRules({
    required this.minHorizontalDistancePx,
    required this.minVerticalSeparationFL,
  });

  double get warningDistancePx  => minHorizontalDistancePx * 1.45;
  double get advisoryDistancePx => minHorizontalDistancePx * 1.90;
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
