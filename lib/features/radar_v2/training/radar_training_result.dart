import '../models/simulation_snapshot.dart';
import '../scoring/radar_v2_score.dart';

class RadarTrainingResult {
  final String scenarioTitle;
  final String scenarioId;
  final RadarV2ScoreSnapshot score;
  final SimulationSnapshot snapshot;
  final List<String> replayExplanation;
  final List<String> timelineSummary;
  final List<ReplayMoment> replayMoments;
  final String topMistake;
  final String bestRecovery;

  const RadarTrainingResult({
    required this.scenarioTitle,
    required this.scenarioId,
    required this.score,
    required this.snapshot,
    required this.replayExplanation,
    required this.timelineSummary,
    required this.replayMoments,
    required this.topMistake,
    required this.bestRecovery,
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

class ReplayMoment {
  final Duration elapsed;
  final String label;
  final String type;

  const ReplayMoment({
    required this.elapsed,
    required this.label,
    required this.type,
  });
}

class RadarTrainingResultBuilder {
  static RadarTrainingResult build({
    required String scenarioTitle,
    required String scenarioId,
    required RadarV2ScoreSnapshot score,
    required SimulationSnapshot snapshot,
  }) {
    final replayExplanation = buildReplayExplanation(snapshot);
    return RadarTrainingResult(
      scenarioTitle: scenarioTitle,
      scenarioId: scenarioId,
      score: score,
      snapshot: snapshot,
      replayExplanation: replayExplanation,
      timelineSummary: buildTimelineSummary(snapshot, score),
      replayMoments: buildReplayMoments(snapshot),
      topMistake: buildTopMistake(score, snapshot),
      bestRecovery: buildBestRecovery(score, snapshot, replayExplanation),
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

  static List<String> buildTimelineSummary(
    SimulationSnapshot snapshot,
    RadarV2ScoreSnapshot score,
  ) {
    final summary = <String>[
      'T+0s: Scenario started',
      if (score.totalOverloadDuration > Duration.zero)
        'Overload lasted ${score.totalOverloadDuration.inSeconds}s',
      if (score.separationLossCount > 0)
        '${score.separationLossCount} separation loss event(s)',
      if (score.commandCount > 0) '${score.commandCount} controller commands',
      if (snapshot.expectationState.driftScore >= 0.24)
        'Expectation drift detected near final workload phase',
    ];
    if (summary.length == 1) {
      summary.add('Traffic remained inside planned operating limits');
    }
    return List.unmodifiable(summary.take(5));
  }

  static List<ReplayMoment> buildReplayMoments(SimulationSnapshot snapshot) {
    final moments = <ReplayMoment>[];
    for (final event in snapshot.events) {
      final lower = event.label.toLowerCase();
      final isImportant = event.type == 'separationLoss' ||
          event.type == 'goAround' ||
          lower.contains('conflict') ||
          lower.contains('alert') ||
          lower.contains('overload');
      if (!isImportant) continue;
      moments.add(ReplayMoment(
        elapsed: event.elapsed,
        label: event.label,
        type: event.type,
      ));
    }
    for (final line in [
      ...snapshot.psychologyState.reportLines,
      ...snapshot.expectationState.reportLines,
      ...snapshot.attentionReportLines,
    ]) {
      final seconds = _firstSeconds(line) ?? snapshot.elapsed.inSeconds;
      final lower = line.toLowerCase();
      final type = lower.contains('overload')
          ? 'overload'
          : lower.contains('separation')
              ? 'separationWarning'
              : lower.contains('tunnel') || lower.contains('attention')
                  ? 'attention'
                  : 'cognitive';
      moments.add(ReplayMoment(
        elapsed: Duration(seconds: seconds),
        label: line,
        type: type,
      ));
    }
    moments.sort((a, b) => a.elapsed.compareTo(b.elapsed));
    final unique = <String>{};
    return List.unmodifiable(moments.where((moment) {
      final key = '${moment.elapsed.inSeconds}:${moment.label}';
      return unique.add(key);
    }).take(12));
  }

  static String buildTopMistake(
    RadarV2ScoreSnapshot score,
    SimulationSnapshot snapshot,
  ) {
    if (score.separationLossCount > 0) {
      return 'Separation was lost. Intervene earlier or use a stronger vector.';
    }
    if (score.ignoredCriticalAlertCount > 0) {
      return 'A critical alert stayed unattended. Keep scanning outside the selected aircraft.';
    }
    if (snapshot.expectationState.falseRecoveryActive) {
      return 'False recovery lowered threat sensitivity. Keep checking the merge even after pressure drops.';
    }
    if (score.commandCount > 8) {
      return 'Command load was high. Fewer, earlier instructions would stabilize the flow.';
    }
    return 'No major mistake detected. Focus on smoother, earlier control.';
  }

  static String buildBestRecovery(
    RadarV2ScoreSnapshot score,
    SimulationSnapshot snapshot,
    List<String> explanation,
  ) {
    if (score.proactiveStabilizationBonus > 0) {
      return 'You stabilized workload after a busy phase and regained spare attention.';
    }
    if (score.separationLossCount == 0 && score.lateResolutionCount > 0) {
      return 'You recovered a late conflict without losing separation.';
    }
    if (snapshot.expectationState.driftScore > 0.2 && explanation.isNotEmpty) {
      return 'You kept the scenario recoverable despite expectation drift.';
    }
    return 'Best recovery will appear after a pressured event is resolved.';
  }

  static int? _firstSeconds(String line) {
    final match = RegExp(r'(\d+)s').firstMatch(line);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
