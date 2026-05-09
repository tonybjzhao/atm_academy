enum PredictionMismatchType {
  delayedTurn,
  wrongAltitudeTrend,
  unstableApproach,
  unexpectedSpeed,
  missedHandoff,
  spacingNotStabilized,
}

class PredictionMismatchSnapshot {
  final String id;
  final String aircraftId;
  final PredictionMismatchType type;
  final Duration firstDetectedAt;
  final Duration lastSeenAt;
  final double severity;
  final double confidenceAtDetection;
  final bool lateRecognition;
  final bool resolved;

  const PredictionMismatchSnapshot({
    required this.id,
    required this.aircraftId,
    required this.type,
    required this.firstDetectedAt,
    required this.lastSeenAt,
    required this.severity,
    required this.confidenceAtDetection,
    this.lateRecognition = false,
    this.resolved = false,
  });

  String get typeLabel => switch (type) {
        PredictionMismatchType.delayedTurn => 'delayed turn',
        PredictionMismatchType.wrongAltitudeTrend => 'wrong altitude trend',
        PredictionMismatchType.unstableApproach => 'unstable approach',
        PredictionMismatchType.unexpectedSpeed => 'unexpected speed',
        PredictionMismatchType.missedHandoff => 'missed handoff',
        PredictionMismatchType.spacingNotStabilized =>
          'spacing not stabilizing',
      };
}

class PredictiveMentalModelState {
  final double aggregatePredictionConfidence;
  final double surpriseLoad;
  final int surpriseOverloadMoments;
  final int lateRecognitionCount;
  final int assumptionDrivenErrorCount;
  final int urgentReevaluationCount;
  final List<PredictionMismatchSnapshot> activeMismatches;
  final List<PredictionMismatchSnapshot> newlyDetectedMismatches;
  final List<String> resolvedMismatchIds;
  final List<String> reportLines;

  const PredictiveMentalModelState({
    this.aggregatePredictionConfidence = 0.55,
    this.surpriseLoad = 0,
    this.surpriseOverloadMoments = 0,
    this.lateRecognitionCount = 0,
    this.assumptionDrivenErrorCount = 0,
    this.urgentReevaluationCount = 0,
    this.activeMismatches = const [],
    this.newlyDetectedMismatches = const [],
    this.resolvedMismatchIds = const [],
    this.reportLines = const [],
  });

  static const PredictiveMentalModelState idle = PredictiveMentalModelState();
}
