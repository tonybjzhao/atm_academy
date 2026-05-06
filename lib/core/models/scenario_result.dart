enum ScenarioRating { excellent, safe, needsImprovement, unsafe }

enum AlertLevel { normal, advisory, warning, los }

class CommandRecord {
  final int elapsedMs;
  final String callsign;
  final String command;
  final String feedback; // 'good' | 'neutral' | 'bad'
  final double minHorizBefore;
  final double minHorizAfter;

  const CommandRecord({
    required this.elapsedMs,
    required this.callsign,
    required this.command,
    required this.feedback,
    required this.minHorizBefore,
    required this.minHorizAfter,
  });
}

class ScenarioResult {
  final int score;
  final ScenarioRating rating;
  final bool hadLOS;
  final bool resolvedInFirstHalf;
  final int goodCommands;
  final int badCommands;
  final bool separationMaintained; // 5+ continuous safe seconds
  final AlertLevel levelAtFirstCommand;

  const ScenarioResult({
    required this.score,
    required this.rating,
    required this.hadLOS,
    required this.resolvedInFirstHalf,
    required this.goodCommands,
    required this.badCommands,
    required this.separationMaintained,
    required this.levelAtFirstCommand,
  });

  // Rating string key
  String get ratingKey {
    switch (rating) {
      case ScenarioRating.excellent:        return 'ratingExcellent';
      case ScenarioRating.safe:             return 'ratingSafe';
      case ScenarioRating.needsImprovement: return 'ratingNeedsImprovement';
      case ScenarioRating.unsafe:           return 'ratingUnsafe';
    }
  }
}
