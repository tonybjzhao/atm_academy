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
  final List<String> controllerEvaluation;
  final List<String> commandTimingQuality;
  final List<String> hesitationWindows;
  final List<String> lateVectorRecognition;
  final List<String> neglectedAircraft;
  final List<String> scanBlindPeriods;
  final List<String> fixationWindows;
  final List<String> delayedAwarenessMoments;
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
    required this.controllerEvaluation,
    required this.commandTimingQuality,
    required this.hesitationWindows,
    required this.lateVectorRecognition,
    required this.neglectedAircraft,
    required this.scanBlindPeriods,
    required this.fixationWindows,
    required this.delayedAwarenessMoments,
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
      controllerEvaluation: buildControllerEvaluation(score, snapshot),
      commandTimingQuality: buildCommandTimingQuality(snapshot),
      hesitationWindows: buildHesitationWindows(snapshot),
      lateVectorRecognition: buildLateVectorRecognition(snapshot),
      neglectedAircraft: buildNeglectedAircraft(snapshot),
      scanBlindPeriods: buildScanBlindPeriods(snapshot),
      fixationWindows: buildFixationWindows(snapshot),
      delayedAwarenessMoments: buildDelayedAwarenessMoments(snapshot),
      topMistake: buildTopMistake(score, snapshot),
      bestRecovery: buildBestRecovery(score, snapshot, replayExplanation),
    );
  }

  static List<String> buildNeglectedAircraft(SimulationSnapshot snapshot) {
    final neglected = snapshot.attentionFocus.neglectedAircraftIds;
    if (neglected.isEmpty) {
      if (snapshot.attentionFocus.longestNeglect >= const Duration(seconds: 18)) {
        return [
          'No specific neglected track IDs captured, but max unseen interval '
              'reached ${snapshot.attentionFocus.longestNeglect.inSeconds}s.',
        ];
      }
      return const [];
    }
    return [
      'Neglected tracks: ${neglected.join(', ')}.',
      'Longest unseen interval: '
          '${snapshot.attentionFocus.longestNeglect.inSeconds}s.',
    ];
  }

  static List<String> buildScanBlindPeriods(SimulationSnapshot snapshot) {
    final periods = <String>[];
    for (final event in snapshot.events) {
      if (event.type != 'attentionScanBlind') continue;
      periods.add('${event.label} (T+${event.elapsed.inSeconds}s).');
      if (periods.length == 3) break;
    }
    if (periods.isEmpty &&
        snapshot.attentionFocus.scanBlindDuration >= const Duration(seconds: 12)) {
      periods.add(
        'Late-session scan blind period reached '
        '${snapshot.attentionFocus.scanBlindDuration.inSeconds}s.',
      );
    }
    return List.unmodifiable(periods);
  }

  static List<String> buildFixationWindows(SimulationSnapshot snapshot) {
    final windows = <String>[];
    for (final event in snapshot.events) {
      if (event.type != 'attentionFixationWindow') continue;
      windows.add('${event.label} (T+${event.elapsed.inSeconds}s).');
      if (windows.length == 3) break;
    }
    if (windows.isEmpty && snapshot.attentionFocus.fixationWindowCount > 0) {
      windows.add(
        'Fixation windows detected: ${snapshot.attentionFocus.fixationWindowCount}.',
      );
    }
    return List.unmodifiable(windows);
  }

  static List<String> buildDelayedAwarenessMoments(SimulationSnapshot snapshot) {
    final moments = <String>[];
    for (final event in snapshot.events) {
      if (event.type != 'attentionDelayedRecognition') continue;
      moments.add('${event.label} (T+${event.elapsed.inSeconds}s).');
      if (moments.length == 3) break;
    }
    if (moments.isEmpty && snapshot.attentionFocus.delayedAwarenessMoments > 0) {
      moments.add(
        'Delayed awareness moments observed: '
        '${snapshot.attentionFocus.delayedAwarenessMoments}.',
      );
    }
    return List.unmodifiable(moments);
  }

  static List<String> buildCommandTimingQuality(SimulationSnapshot snapshot) {
    final issued = snapshot.events.where((e) => e.type == 'commandIssued').toList();
    final acked = snapshot.events.where((e) => e.type == 'commandAcknowledged').toList();
    if (issued.isEmpty) {
      return const ['No radio cadence sample available.'];
    }

    final latencies = <int>[];
    for (final issue in issued) {
      final match = acked.where((ack) {
        if (ack.aircraftId != issue.aircraftId) return false;
        if (ack.elapsed < issue.elapsed) return false;
        return ack.elapsed - issue.elapsed <= const Duration(seconds: 12);
      });
      if (match.isNotEmpty) {
        latencies.add((match.first.elapsed - issue.elapsed).inSeconds);
      }
    }

    if (latencies.isEmpty) {
      return const ['No timely readbacks captured (all beyond 12s).'];
    }

    final avg = latencies.reduce((a, b) => a + b) / latencies.length;
    final sorted = [...latencies]..sort();
    final p90 = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
    final onCadencePct = (latencies.where((s) => s <= 5).length * 100 / latencies.length).round();
    final insights = <String>[];
    if (avg <= 2.5) {
      insights.add('Cadence was tight: avg readback ${avg.toStringAsFixed(1)}s.');
    } else if (avg <= 4.5) {
      insights.add('Cadence stayed workable: avg readback ${avg.toStringAsFixed(1)}s.');
    } else if (avg <= 6.5) {
      insights.add('Cadence started to stretch: avg readback ${avg.toStringAsFixed(1)}s.');
    } else {
      insights.add('Cadence was behind traffic demand: avg readback ${avg.toStringAsFixed(1)}s.');
    }
    insights.add('On-cadence readbacks (<=5s): $onCadencePct%. Tail latency: ${p90}s.');

    final delayedCount = latencies.where((s) => s >= 6).length;
    if (delayedCount > 0) {
      insights.add('$delayedCount late readback(s) (>=6s) during higher workload moments.');
    }
    return List.unmodifiable(insights);
  }

  static List<String> buildHesitationWindows(SimulationSnapshot snapshot) {
    final issued = snapshot.events.where((e) => e.type == 'commandIssued').toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    if (issued.length < 2) return const [];

    final windows = <String>[];
    for (var i = 1; i < issued.length; i++) {
      final gap = issued[i].elapsed - issued[i - 1].elapsed;
      if (gap < const Duration(seconds: 15)) continue;
      windows.add(
        'Command gap ${gap.inSeconds}s between T+${issued[i - 1].elapsed.inSeconds}s '
        'and T+${issued[i].elapsed.inSeconds}s; scan likely narrowed here.',
      );
      if (windows.length == 3) break;
    }
    return List.unmodifiable(windows);
  }

  static List<String> buildLateVectorRecognition(SimulationSnapshot snapshot) {
    final vectors = snapshot.events.where((e) {
      return e.type == 'commandIssued' && e.label.toLowerCase().contains('heading');
    }).toList();
    final conflictCues = snapshot.events.where((e) {
      final l = e.label.toLowerCase();
      return e.type == 'separationLoss' || e.type == 'separationWarning' || l.contains('conflict');
    }).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    if (vectors.isEmpty || conflictCues.isEmpty) return const [];

    final lines = <String>[];
    for (final cue in conflictCues) {
      final candidate = vectors.where((vector) {
        if (cue.aircraftId != null && vector.aircraftId != cue.aircraftId) {
          return false;
        }
        final delta = vector.elapsed - cue.elapsed;
        return delta >= const Duration(seconds: 6) &&
            delta <= const Duration(seconds: 30);
      });
      if (candidate.isEmpty) continue;
      final vector = candidate.first;
      final lag = (vector.elapsed - cue.elapsed).inSeconds;
      lines.add(
        'Vector call came ${lag}s after conflict cue at T+${cue.elapsed.inSeconds}s '
        '(issued T+${vector.elapsed.inSeconds}s).',
      );
      if (lines.length == 2) break;
    }
    return List.unmodifiable(lines);
  }

  static List<String> buildControllerEvaluation(
    RadarV2ScoreSnapshot score,
    SimulationSnapshot snapshot,
  ) {
    final notes = <String>[];
    if (score.lateResolutionCount > 0) {
      notes.add('Late intervention on at least one conflict pair.');
    }
    if (score.proactiveStabilizationBonus > 0 || score.anticipationScore >= 72) {
      notes.add('Good anticipation during workload transitions.');
    }
    if (score.commandEfficiency >= 82 && score.commandCount <= 8) {
      notes.add('Traffic prioritization improved under pressure.');
    }
    if (snapshot.expectationState.driftScore >= 0.24) {
      notes.add('Expectation drift observed; maintain broad scan discipline.');
    }
    if (notes.isEmpty) {
      notes.add('Control inputs were stable; continue earlier threat detection.');
    }
    return List.unmodifiable(notes.take(4));
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
