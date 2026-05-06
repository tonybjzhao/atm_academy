class RadarAircraftStart {
  final String callsign;
  final double x;
  final double y;
  final double heading;
  final double speed; // base speed; multiplied by LevelConfig.speedMultiplier at runtime
  final int altitude; // FL style: 320 = FL320

  const RadarAircraftStart({
    required this.callsign,
    required this.x,
    required this.y,
    required this.heading,
    required this.speed,
    required this.altitude,
  });
}

class RadarLevelConfig {
  final int level;
  final String scenarioKey;       // ARB key for scenario name
  final String tipKey;            // ARB key shown on failure
  final String primaryTechnique;  // 'heading' | 'altitude' | 'speed' | 'mixed'
  final int timeLimitSeconds;
  final int startingScore;
  final int successBonus;
  final double speedMultiplier;
  final double conflictDistancePx;
  final int requiredClearSeconds;
  final List<RadarAircraftStart> aircraft;

  const RadarLevelConfig({
    required this.level,
    required this.scenarioKey,
    required this.tipKey,
    required this.primaryTechnique,
    required this.timeLimitSeconds,
    required this.startingScore,
    required this.successBonus,
    required this.speedMultiplier,
    required this.conflictDistancePx,
    required this.requiredClearSeconds,
    required this.aircraft,
  });

  // Ticks needed for "clear" at 50 ms per tick
  int get requiredClearTicks => requiredClearSeconds * 20;

  static const int maxLevel = 10;

  // Resolved at runtime via radar_levels.dart
  static RadarLevelConfig Function(int) _resolver =
      (n) => throw StateError('Call RadarLevelConfig.setResolver() before use');

  static void setResolver(RadarLevelConfig Function(int) fn) => _resolver = fn;

  static RadarLevelConfig forLevel(int n) => _resolver(n);
}
