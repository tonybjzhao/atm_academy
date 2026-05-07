/// What would have happened if the user had made a better decision.
/// Values are simple approximations — not physics-accurate — intended to
/// be convincing and educational rather than precise.
class ProjectedOutcome {
  /// When the alternative action would have been issued (seconds elapsed).
  final double timestampSeconds;

  /// Which aircraft the alternative action targeted.
  final String aircraftId;

  /// Human-readable description of the better action.
  /// e.g. "Turn QFA123 left 8 seconds earlier"
  final String alternativeAction;

  /// Estimated minimum separation if the better action had been taken (px).
  final double projectedSeparation;

  /// Whether the projected outcome would have avoided the conflict.
  final bool projectedConflictResolved;

  /// 1–2 sentences explaining the projected improvement.
  final String explanation;

  /// Short coaching-style insight (encouraging tone).
  final String insightText;

  const ProjectedOutcome({
    required this.timestampSeconds,
    required this.aircraftId,
    required this.alternativeAction,
    required this.projectedSeparation,
    required this.projectedConflictResolved,
    required this.explanation,
    required this.insightText,
  });
}
