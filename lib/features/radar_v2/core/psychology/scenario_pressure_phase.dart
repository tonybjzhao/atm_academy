enum ScenarioPressurePhase {
  calm,
  building,
  busy,
  unstable,
  overload,
  recovery,
}

class ScenarioPsychologyState {
  final ScenarioPressurePhase phase;
  final double pressureMultiplier;
  final double eventDensityFactor;
  final double alertTimingFactor;
  final double spacingInstabilityProbability;
  final bool deceptiveCalmActive;
  final bool escalationChainActive;
  final bool attentionTrapActive;
  final String? activeChainId;
  final String audioLayer;
  final List<String> reportLines;

  const ScenarioPsychologyState({
    required this.phase,
    required this.pressureMultiplier,
    required this.eventDensityFactor,
    required this.alertTimingFactor,
    required this.spacingInstabilityProbability,
    this.deceptiveCalmActive = false,
    this.escalationChainActive = false,
    this.attentionTrapActive = false,
    this.activeChainId,
    this.audioLayer = 'calm ambience',
    this.reportLines = const [],
  });

  static const ScenarioPsychologyState idle = ScenarioPsychologyState(
    phase: ScenarioPressurePhase.calm,
    pressureMultiplier: 1,
    eventDensityFactor: 1,
    alertTimingFactor: 1,
    spacingInstabilityProbability: 0,
  );

  String get phaseLabel => switch (phase) {
        ScenarioPressurePhase.calm => 'calm',
        ScenarioPressurePhase.building => 'building',
        ScenarioPressurePhase.busy => 'busy',
        ScenarioPressurePhase.unstable => 'unstable',
        ScenarioPressurePhase.overload => 'overload',
        ScenarioPressurePhase.recovery => 'recovery',
      };
}
