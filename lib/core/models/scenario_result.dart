enum ScenarioRating { excellent, safe, needsImprovement, unsafe }

enum AlertLevel { normal, advisory, warning, los }

class ScenarioResult {
  // ── Core ──────────────────────────────────────────────────────────────────
  final int            score;          // 0–120
  final ScenarioRating rating;
  final bool           hadLOS;
  final bool           warningReached; // advisory/warning zone hit (but not LOS)
  final bool           resolvedInFirstHalf;
  final bool           separationMaintained; // 5+ continuous safe seconds

  // ── Separation metrics ────────────────────────────────────────────────────
  final double       minHorizontalDistancePx;
  final int          minVerticalDistanceFt;   // ft (altitude diff × 100)
  final double       closestPointTimeSec;     // elapsed seconds when closest
  final List<String> conflictPair;            // e.g. ['QFA123', 'UAE406']

  // ── Command metrics ────────────────────────────────────────────────────────
  final double   reactionTimeSec;            // 0 = no command issued
  final bool     selectedAircraftCorrect;    // selected from conflict pair
  final int      goodCommands;
  final int      badCommands;
  final int      neutralCommands;
  final AlertLevel levelAtFirstCommand;

  // ── Scoring breakdown ─────────────────────────────────────────────────────
  final List<String> penaltyBreakdown; // e.g. "Loss of separation: −60"
  final List<String> bonusBreakdown;   // e.g. "Correct aircraft selected: +10"

  // ── Narrative explanation (English — dynamically generated) ───────────────
  final String replayExplanationShort; // 1 sentence
  final String replayExplanationLong;  // 2–3 sentences

  const ScenarioResult({
    required this.score,
    required this.rating,
    required this.hadLOS,
    required this.warningReached,
    required this.resolvedInFirstHalf,
    required this.separationMaintained,
    required this.minHorizontalDistancePx,
    required this.minVerticalDistanceFt,
    required this.closestPointTimeSec,
    required this.conflictPair,
    required this.reactionTimeSec,
    required this.selectedAircraftCorrect,
    required this.goodCommands,
    required this.badCommands,
    required this.neutralCommands,
    required this.levelAtFirstCommand,
    required this.penaltyBreakdown,
    required this.bonusBreakdown,
    required this.replayExplanationShort,
    required this.replayExplanationLong,
  });

  String get ratingKey {
    switch (rating) {
      case ScenarioRating.excellent:        return 'ratingExcellent';
      case ScenarioRating.safe:             return 'ratingSafe';
      case ScenarioRating.needsImprovement: return 'ratingNeedsImprovement';
      case ScenarioRating.unsafe:           return 'ratingUnsafe';
    }
  }
}
