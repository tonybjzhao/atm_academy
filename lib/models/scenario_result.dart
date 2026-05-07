import 'replay_event.dart';
import 'score_penalty.dart';

enum ScenarioGrade { excellent, good, needsPractice, reviewRequired }

extension ScenarioGradeLabel on ScenarioGrade {
  String get label {
    switch (this) {
      case ScenarioGrade.excellent:      return 'Excellent';
      case ScenarioGrade.good:           return 'Good';
      case ScenarioGrade.needsPractice:  return 'Needs Practice';
      case ScenarioGrade.reviewRequired: return 'Review Required';
    }
  }

  static ScenarioGrade fromScore(int score) {
    if (score >= 90) return ScenarioGrade.excellent;
    if (score >= 75) return ScenarioGrade.good;
    if (score >= 60) return ScenarioGrade.needsPractice;
    return ScenarioGrade.reviewRequired;
  }
}

/// Rich scenario result used for the result screen and debrief panel.
/// Built by ScoringEngine from the existing ScenarioEngine output.
class DetailedScenarioResult {
  final String scenarioId;
  final String scenarioTitle;
  final int    finalScore;
  final int    maxScore;
  final ScenarioGrade grade;

  final DateTime startedAt;
  final DateTime completedAt;

  /// All notable events during the scenario (used for radar replay + timeline).
  final List<ReplayEvent> replayEvents;

  /// All intermediate aircraft frames (used for smooth radar playback).
  final List<AircraftStateFrame> replayFrames;

  /// User commands issued during the scenario.
  final List<UserAction> userActions;

  /// Why points were deducted.
  final List<ScorePenalty> penalties;

  /// Why points were awarded.
  final List<ScoreBonus> bonuses;

  /// One-sentence result summary.
  final String summaryText;

  /// 2–4 concrete improvement tips.
  final List<String> improvementTips;

  /// true if a loss-of-separation occurred.
  final bool hadLOS;

  /// Minimum horizontal distance reached (px).
  final double minHorizDistPx;

  const DetailedScenarioResult({
    required this.scenarioId,
    required this.scenarioTitle,
    required this.finalScore,
    required this.maxScore,
    required this.grade,
    required this.startedAt,
    required this.completedAt,
    required this.replayEvents,
    required this.replayFrames,
    required this.userActions,
    required this.penalties,
    required this.bonuses,
    required this.summaryText,
    required this.improvementTips,
    required this.hadLOS,
    required this.minHorizDistPx,
  });

  double get percentageScore => maxScore == 0 ? 0 : finalScore / maxScore * 100;
  Duration get duration => completedAt.difference(startedAt);

  double get totalDurationSeconds =>
      replayFrames.isEmpty ? 6.0 : replayFrames.last.timestampSeconds;
}
