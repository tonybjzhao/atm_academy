import '../models/simulation_snapshot.dart';
import '../scoring/radar_v2_score.dart';

class RadarTrainingResult {
  final String scenarioTitle;
  final RadarV2ScoreSnapshot score;
  final SimulationSnapshot snapshot;
  final List<String> replayExplanation;

  const RadarTrainingResult({
    required this.scenarioTitle,
    required this.score,
    required this.snapshot,
    required this.replayExplanation,
  });

  int get separationLosses => score.separationLossCount;
  int get goArounds => snapshot.events
      .where((event) =>
          event.type == 'goAround' || event.label.contains('go-around'))
      .length;
  int get commandCount => score.commandCount;
  Duration get overloadDuration => score.totalOverloadDuration;
  int get ignoredCriticalAlerts => score.ignoredCriticalAlertCount;
  int get tunnelVisionEvents =>
      snapshot.attentionFocus.riskLevel.index >= 2 ? 1 : 0;
  int get expectationDriftEvents =>
      snapshot.expectationState.driftScore >= 0.24 ? 1 : 0;
}

class RadarTrainingResultBuilder {
  static RadarTrainingResult build({
    required String scenarioTitle,
    required RadarV2ScoreSnapshot score,
    required SimulationSnapshot snapshot,
  }) {
    return RadarTrainingResult(
      scenarioTitle: scenarioTitle,
      score: score,
      snapshot: snapshot,
      replayExplanation: buildReplayExplanation(snapshot),
    );
  }

  static List<String> buildReplayExplanation(SimulationSnapshot snapshot) {
    final lines = <String>[
      ...snapshot.attentionReportLines,
      ...snapshot.psychologyState.reportLines,
      ...snapshot.expectationState.reportLines,
    ];
    final cleaned = <String>[];
    for (final line in lines) {
      final normalized = line.trim();
      if (normalized.isEmpty || cleaned.contains(normalized)) continue;
      cleaned.add(normalized);
      if (cleaned.length == 5) break;
    }
    if (cleaned.isEmpty) {
      cleaned
          .add('Traffic flow remained stable with no major cognitive events.');
    }
    return List.unmodifiable(cleaned);
  }
}
