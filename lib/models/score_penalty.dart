enum ScorePenaltyType {
  separationLoss,
  conflictWarningUnresolved,
  lateVector,
  wrongAircraftSelected,
  noCommandIssued,
  ineffectiveCommand,
  inefficientRoute,
  excessiveHeadingChange,
  unsafeAltitudeClearance,
}

class ScorePenalty {
  final double          timestampSeconds;
  final ScorePenaltyType type;
  final int             pointsLost;
  final String          title;
  final String          explanation;
  final String          recommendation;

  const ScorePenalty({
    required this.timestampSeconds,
    required this.type,
    required this.pointsLost,
    required this.title,
    required this.explanation,
    required this.recommendation,
  });
}

class ScoreBonus {
  final String title;
  final int    pointsGained;
  final String explanation;

  const ScoreBonus({
    required this.title,
    required this.pointsGained,
    required this.explanation,
  });
}
