class PilotBehaviorRealismProfile {
  final double acknowledgementDelayScale;
  final double variabilityChanceScale;
  final double executionDelayScale;
  final double complianceVariabilityScale;
  final double readbackVariabilityScale;
  final double weatherImpactScale;
  final double workloadImpactScale;

  const PilotBehaviorRealismProfile({
    required this.acknowledgementDelayScale,
    required this.variabilityChanceScale,
    required this.executionDelayScale,
    required this.complianceVariabilityScale,
    required this.readbackVariabilityScale,
    required this.weatherImpactScale,
    required this.workloadImpactScale,
  });

  static const PilotBehaviorRealismProfile balanced =
      PilotBehaviorRealismProfile(
    acknowledgementDelayScale: 1.0,
    variabilityChanceScale: 1.0,
    executionDelayScale: 1.0,
    complianceVariabilityScale: 1.0,
    readbackVariabilityScale: 1.0,
    weatherImpactScale: 1.0,
    workloadImpactScale: 1.0,
  );

  static const PilotBehaviorRealismProfile beginnerSafe =
      PilotBehaviorRealismProfile(
    acknowledgementDelayScale: 0.88,
    variabilityChanceScale: 0.72,
    executionDelayScale: 0.82,
    complianceVariabilityScale: 0.78,
    readbackVariabilityScale: 0.68,
    weatherImpactScale: 0.72,
    workloadImpactScale: 0.78,
  );

  static const PilotBehaviorRealismProfile intermediate =
      PilotBehaviorRealismProfile(
    acknowledgementDelayScale: 0.96,
    variabilityChanceScale: 0.9,
    executionDelayScale: 0.92,
    complianceVariabilityScale: 0.9,
    readbackVariabilityScale: 0.84,
    weatherImpactScale: 0.9,
    workloadImpactScale: 0.9,
  );

  static const PilotBehaviorRealismProfile advanced =
      PilotBehaviorRealismProfile(
    acknowledgementDelayScale: 1.08,
    variabilityChanceScale: 1.2,
    executionDelayScale: 1.16,
    complianceVariabilityScale: 1.15,
    readbackVariabilityScale: 1.24,
    weatherImpactScale: 1.2,
    workloadImpactScale: 1.18,
  );

  static const PilotBehaviorRealismProfile expert =
      PilotBehaviorRealismProfile(
    acknowledgementDelayScale: 1.16,
    variabilityChanceScale: 1.34,
    executionDelayScale: 1.24,
    complianceVariabilityScale: 1.28,
    readbackVariabilityScale: 1.34,
    weatherImpactScale: 1.28,
    workloadImpactScale: 1.26,
  );

  static PilotBehaviorRealismProfile fromDifficulty(int difficulty) {
    if (difficulty <= 2) return beginnerSafe;
    if (difficulty == 3) return intermediate;
    if (difficulty == 4) return advanced;
    return expert;
  }

  PilotBehaviorRealismProfile scale({
    required double acknowledgementDelay,
    required double variabilityChance,
    required double executionDelay,
    required double complianceVariability,
    required double readbackVariability,
    required double weatherImpact,
    required double workloadImpact,
  }) {
    return PilotBehaviorRealismProfile(
      acknowledgementDelayScale:
          (acknowledgementDelayScale * acknowledgementDelay).clamp(0.7, 1.5),
      variabilityChanceScale:
          (variabilityChanceScale * variabilityChance).clamp(0.55, 1.55),
      executionDelayScale:
          (executionDelayScale * executionDelay).clamp(0.7, 1.55),
      complianceVariabilityScale:
          (complianceVariabilityScale * complianceVariability)
              .clamp(0.7, 1.55),
      readbackVariabilityScale:
          (readbackVariabilityScale * readbackVariability)
              .clamp(0.6, 1.6),
      weatherImpactScale:
          (weatherImpactScale * weatherImpact).clamp(0.65, 1.65),
      workloadImpactScale:
          (workloadImpactScale * workloadImpact).clamp(0.65, 1.65),
    );
  }

  static PilotBehaviorRealismProfile fromScenarioContext({
    required int difficulty,
    required String weatherMode,
    required int weatherZoneCount,
    required double maxWeatherSeverity,
    required double densityScale,
    required double workloadPressureMultiplier,
    required int maxControllerLoad,
  }) {
    var profile = fromDifficulty(difficulty);

    final weatherHeavy = weatherMode == 'low_visibility' ||
        weatherZoneCount >= 2 ||
        maxWeatherSeverity >= 2.5;
    if (weatherHeavy) {
      profile = profile.scale(
        acknowledgementDelay: 1.04,
        variabilityChance: 1.06,
        executionDelay: 1.08,
        complianceVariability: 1.05,
        readbackVariability: 1.04,
        weatherImpact: 1.2,
        workloadImpact: 1.0,
      );
    }

    final trafficDense =
        densityScale >= 1.2 || workloadPressureMultiplier >= 1.15;
    if (trafficDense) {
      profile = profile.scale(
        acknowledgementDelay: 1.05,
        variabilityChance: 1.12,
        executionDelay: 1.08,
        complianceVariability: 1.08,
        readbackVariability: 1.02,
        weatherImpact: 1.0,
        workloadImpact: 1.18,
      );
    }

    if (maxControllerLoad <= 4) {
      profile = profile.scale(
        acknowledgementDelay: 0.93,
        variabilityChance: 0.9,
        executionDelay: 0.9,
        complianceVariability: 0.92,
        readbackVariability: 0.92,
        weatherImpact: 0.95,
        workloadImpact: 0.9,
      );
    }

    return profile;
  }
}
