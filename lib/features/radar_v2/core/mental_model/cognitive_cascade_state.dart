class CascadeChainSummary {
  final String chainId;
  final String rootMismatchId;
  final String rootLabel;
  final Duration startedAt;
  final Duration? endedAt;
  final List<String> secondaryFailures;
  final double amplification;
  final double recoveryQuality;

  const CascadeChainSummary({
    required this.chainId,
    required this.rootMismatchId,
    required this.rootLabel,
    required this.startedAt,
    this.endedAt,
    this.secondaryFailures = const [],
    required this.amplification,
    this.recoveryQuality = 0.5,
  });

  bool get active => endedAt == null;
}

class CognitiveCascadeState {
  final bool chainStartedThisTick;
  final bool chainEndedThisTick;
  final String? activeChainId;
  final String? rootSurpriseLabel;
  final double amplificationProbability;
  final double scanQualityPenalty;
  final double attentionBreadthPenalty;
  final double tunnelVisionRiskBoost;
  final bool stickyFocusActive;
  final bool intentionInterruptionActive;
  final bool recoveryInstabilityActive;
  final List<String> secondaryFailuresThisTick;
  final List<CascadeChainSummary> chainHistory;
  final List<String> reportLines;

  const CognitiveCascadeState({
    this.chainStartedThisTick = false,
    this.chainEndedThisTick = false,
    this.activeChainId,
    this.rootSurpriseLabel,
    this.amplificationProbability = 0,
    this.scanQualityPenalty = 0,
    this.attentionBreadthPenalty = 0,
    this.tunnelVisionRiskBoost = 0,
    this.stickyFocusActive = false,
    this.intentionInterruptionActive = false,
    this.recoveryInstabilityActive = false,
    this.secondaryFailuresThisTick = const [],
    this.chainHistory = const [],
    this.reportLines = const [],
  });

  static const CognitiveCascadeState idle = CognitiveCascadeState();
}
