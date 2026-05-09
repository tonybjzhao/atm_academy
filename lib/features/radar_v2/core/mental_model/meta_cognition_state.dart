class MetaAssessmentSnapshot {
  final Duration elapsed;
  final double estimatedWorkload;
  final double estimatedScanQuality;
  final double estimatedConfidenceReliability;
  final double estimatedTaskSaturation;
  final double estimatedFixationRisk;
  final double calibrationAccuracy;
  final bool degradationBlindness;

  const MetaAssessmentSnapshot({
    required this.elapsed,
    required this.estimatedWorkload,
    required this.estimatedScanQuality,
    required this.estimatedConfidenceReliability,
    required this.estimatedTaskSaturation,
    required this.estimatedFixationRisk,
    required this.calibrationAccuracy,
    this.degradationBlindness = false,
  });
}

class MetaRecoveryAction {
  final String action;
  final Duration triggeredAt;
  final double effectiveness;

  const MetaRecoveryAction({
    required this.action,
    required this.triggeredAt,
    required this.effectiveness,
  });
}

class MetaCognitionState {
  final MetaAssessmentSnapshot latestAssessment;
  final int inaccurateSelfAssessmentMoments;
  final int unnoticedOverloadMoments;
  final int successfulSelfRecoveryCount;
  final double confidenceCalibrationQuality;
  final List<MetaRecoveryAction> recentRecoveryActions;
  final List<String> reportLines;

  const MetaCognitionState({
    required this.latestAssessment,
    this.inaccurateSelfAssessmentMoments = 0,
    this.unnoticedOverloadMoments = 0,
    this.successfulSelfRecoveryCount = 0,
    this.confidenceCalibrationQuality = 0.55,
    this.recentRecoveryActions = const [],
    this.reportLines = const [],
  });

  static const MetaCognitionState idle = MetaCognitionState(
    latestAssessment: MetaAssessmentSnapshot(
      elapsed: Duration.zero,
      estimatedWorkload: 0,
      estimatedScanQuality: 1,
      estimatedConfidenceReliability: 0.55,
      estimatedTaskSaturation: 0,
      estimatedFixationRisk: 0,
      calibrationAccuracy: 0.55,
    ),
  );
}
