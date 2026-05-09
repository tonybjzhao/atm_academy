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
}
