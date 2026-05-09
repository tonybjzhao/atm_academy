import '../models/simulation_event.dart';
import 'radar_training_result.dart';

enum CascadePropagationNodeType {
  fixation,
  scanNeglect,
  workingMemoryFailure,
  expectationDrift,
  missedConflict,
  overloadIncrease,
  confidenceErosion,
  delayedIntervention,
  recoveryInterruption,
  stabilization,
  recoveryBreakdown,
}

class CascadePropagationNode {
  final String id;
  final CascadePropagationNodeType type;
  final String label;
  final String detail;
  final Duration timestamp;
  final Duration duration;
  final double severity;
  final double downstreamWeight;

  const CascadePropagationNode({
    required this.id,
    required this.type,
    required this.label,
    required this.detail,
    required this.timestamp,
    required this.duration,
    required this.severity,
    required this.downstreamWeight,
  });

  double get visualWeight =>
      (severity * 0.65 + downstreamWeight * 0.35).clamp(0.12, 1).toDouble();
}

class CascadePropagationEdge {
  final String fromNodeId;
  final String toNodeId;
  final String explanation;
  final double confidence;

  const CascadePropagationEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.explanation,
    required this.confidence,
  });
}

class CascadePropagationChain {
  final String id;
  final String title;
  final List<CascadePropagationNode> nodes;
  final List<CascadePropagationEdge> edges;

  const CascadePropagationChain({
    required this.id,
    required this.title,
    required this.nodes,
    required this.edges,
  });
}

class CognitiveCascadePropagationData {
  final List<CascadePropagationChain> chains;

  const CognitiveCascadePropagationData({required this.chains});

  static const empty = CognitiveCascadePropagationData(chains: []);
}

class CognitiveCascadePropagationBuilder {
  const CognitiveCascadePropagationBuilder();

  CognitiveCascadePropagationData build(RadarTrainingResult result) {
    final primary = _primaryChain(result);
    final parallel = _parallelChains(result);
    final chains = [
      if (primary.nodes.isNotEmpty) primary,
      ...parallel,
    ];
    return CognitiveCascadePropagationData(chains: List.unmodifiable(chains));
  }

  CascadePropagationChain _primaryChain(RadarTrainingResult result) {
    final nodes = <CascadePropagationNode>[];
    _addIf(
      nodes,
      _fixationNode(result),
    );
    _addIf(
      nodes,
      _scanNeglectNode(result),
    );
    _addIf(
      nodes,
      _workingMemoryNode(result),
    );
    _addIf(
      nodes,
      _missedConflictNode(result),
    );
    _addIf(
      nodes,
      _overloadNode(result),
    );
    _addIf(
      nodes,
      _expectationNode(result),
    );
    _addIf(
      nodes,
      _confidenceNode(result),
    );
    _addIf(
      nodes,
      _delayedInterventionNode(result),
    );
    _addIf(
      nodes,
      _recoveryInterruptionNode(result),
    );
    _addIf(
      nodes,
      _stabilizationNode(result),
    );
    _addIf(
      nodes,
      _recoveryBreakdownNode(result),
    );

    nodes.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return CascadePropagationChain(
      id: 'primary',
      title: 'Primary propagation chain',
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(_edgesFor(nodes)),
    );
  }

  List<CascadePropagationChain> _parallelChains(RadarTrainingResult result) {
    final chains = <CascadePropagationChain>[];
    final history = result.snapshot.cognitiveCascadeState.chainHistory;
    for (var i = 0; i < history.length; i++) {
      final chain = history[i];
      final nodes = <CascadePropagationNode>[
        CascadePropagationNode(
          id: 'parallel-$i-root',
          type: CascadePropagationNodeType.expectationDrift,
          label: 'Cascade origin',
          detail: chain.rootLabel,
          timestamp: chain.startedAt,
          duration:
              (chain.endedAt ?? result.snapshot.elapsed) - chain.startedAt,
          severity: chain.amplification.clamp(0.35, 1).toDouble(),
          downstreamWeight: chain.secondaryFailures.length.clamp(1, 4) / 4,
        ),
        for (var j = 0; j < chain.secondaryFailures.length; j++)
          CascadePropagationNode(
            id: 'parallel-$i-secondary-$j',
            type: _secondaryType(chain.secondaryFailures[j]),
            label: _secondaryLabel(chain.secondaryFailures[j]),
            detail: chain.secondaryFailures[j],
            timestamp: chain.startedAt + Duration(seconds: 18 + j * 12),
            duration: const Duration(seconds: 24),
            severity: 0.5 + (j * 0.08).clamp(0, 0.3),
            downstreamWeight: (chain.secondaryFailures.length - j) /
                chain.secondaryFailures.length.clamp(1, 6),
          ),
      ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      chains.add(CascadePropagationChain(
        id: 'parallel-$i',
        title: 'Parallel chain ${i + 1}',
        nodes: List.unmodifiable(nodes),
        edges: List.unmodifiable(_edgesFor(nodes)),
      ));
    }
    return chains.take(2).toList();
  }

  CascadePropagationNode? _fixationNode(RadarTrainingResult result) {
    final event = _firstEvent(result, ['attentionFixationWindow']);
    final focus = result.snapshot.attentionFocus;
    if (event == null && focus.fixationWindowCount == 0) return null;
    final timestamp = event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 70);
    return CascadePropagationNode(
      id: 'fixation',
      type: CascadePropagationNodeType.fixation,
      label: 'Fixation',
      detail: event?.label ??
          'Focus stayed narrow while other threats remained active.',
      timestamp: timestamp,
      duration: focus.focusDuration > Duration.zero
          ? focus.focusDuration
          : const Duration(seconds: 25),
      severity: _attentionSeverity(result),
      downstreamWeight: 0.86,
    );
  }

  CascadePropagationNode? _scanNeglectNode(RadarTrainingResult result) {
    final event = _firstEvent(result, ['attentionScanBlind']);
    final focus = result.snapshot.attentionFocus;
    if (event == null &&
        focus.scanBlindDuration == Duration.zero &&
        focus.scanCoverageQuality > 0.68 &&
        focus.longestNeglect < const Duration(seconds: 12)) {
      return null;
    }
    return CascadePropagationNode(
      id: 'scan-neglect',
      type: CascadePropagationNodeType.scanNeglect,
      label: 'Scan neglect',
      detail: event?.label ??
          'Scan coverage dropped and one or more tracks stayed unseen.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 58),
      duration: focus.scanBlindDuration > Duration.zero
          ? focus.scanBlindDuration
          : focus.longestNeglect,
      severity: (1 - focus.scanCoverageQuality).clamp(0.38, 1).toDouble(),
      downstreamWeight: 0.8,
    );
  }

  CascadePropagationNode? _workingMemoryNode(RadarTrainingResult result) {
    final memory = result.snapshot.workingMemoryState;
    final event = _firstEvent(result, [
      'workingMemoryForgotten',
      'workingMemoryInterrupted',
    ]);
    if (event == null &&
        memory.forgottenIntentionCount == 0 &&
        memory.interruptedWorkflowCount == 0 &&
        memory.delayedFollowThroughCount == 0) {
      return null;
    }
    return CascadePropagationNode(
      id: 'working-memory',
      type: CascadePropagationNodeType.workingMemoryFailure,
      label: 'Task memory failure',
      detail: event?.label ??
          'Pending intentions were interrupted or followed through late.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 50),
      duration: const Duration(seconds: 28),
      severity: ((memory.forgottenIntentionCount +
                  memory.interruptedWorkflowCount +
                  memory.delayedFollowThroughCount) /
              6)
          .clamp(0.4, 1)
          .toDouble(),
      downstreamWeight: 0.68,
    );
  }

  CascadePropagationNode? _missedConflictNode(RadarTrainingResult result) {
    final event = _firstMatchingEvent(result, (event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('separation') || lower.contains('conflict');
    });
    if (event == null && result.score.separationLossCount == 0) return null;
    return CascadePropagationNode(
      id: 'missed-conflict',
      type: CascadePropagationNodeType.missedConflict,
      label: 'Missed conflict',
      detail: event?.label ??
          'Conflict cue was not resolved before separation pressure rose.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 44),
      duration: const Duration(seconds: 30),
      severity: result.score.separationLossCount > 0 ? 1 : 0.72,
      downstreamWeight: 0.92,
    );
  }

  CascadePropagationNode? _overloadNode(RadarTrainingResult result) {
    final score = result.score;
    final snapshot = result.snapshot;
    if (score.totalOverloadDuration == Duration.zero &&
        snapshot.cognitiveLoad.totalLoadScore < 5.5) {
      return null;
    }
    final spikeAt = snapshot.cognitiveLoad.recentSpikes.isEmpty
        ? null
        : snapshot.cognitiveLoad.recentSpikes.first.occurredAt;
    return CascadePropagationNode(
      id: 'overload',
      type: CascadePropagationNodeType.overloadIncrease,
      label: 'Overload increase',
      detail: 'Workload rose as unresolved alerts and commands competed.',
      timestamp: spikeAt ?? _nearEnd(result, secondsBeforeEnd: 38),
      duration: score.totalOverloadDuration > Duration.zero
          ? score.totalOverloadDuration
          : const Duration(seconds: 32),
      severity: (snapshot.cognitiveLoad.totalLoadScore / 10)
          .clamp(0.58, 1)
          .toDouble(),
      downstreamWeight: 0.76,
    );
  }

  CascadePropagationNode? _expectationNode(RadarTrainingResult result) {
    final expectation = result.snapshot.expectationState;
    final event = _firstMatchingEvent(result, (event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('expectation') || lower.contains('mismatch');
    });
    if (event == null && expectation.driftScore < 0.18) return null;
    return CascadePropagationNode(
      id: 'expectation-drift',
      type: CascadePropagationNodeType.expectationDrift,
      label: 'Expectation drift',
      detail: event?.label ??
          'Sector behavior diverged from the expected traffic picture.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 32),
      duration: const Duration(seconds: 36),
      severity: expectation.driftScore.clamp(0.38, 1).toDouble(),
      downstreamWeight: 0.62,
    );
  }

  CascadePropagationNode? _confidenceNode(RadarTrainingResult result) {
    final meta = result.snapshot.metaCognitionState;
    final predictive = result.snapshot.predictiveMentalModelState;
    final erosion = 1 -
        ((meta.confidenceCalibrationQuality +
                predictive.aggregatePredictionConfidence) /
            2);
    if (erosion < 0.22 &&
        meta.inaccurateSelfAssessmentMoments == 0 &&
        predictive.surpriseOverloadMoments == 0) {
      return null;
    }
    return CascadePropagationNode(
      id: 'confidence-erosion',
      type: CascadePropagationNodeType.confidenceErosion,
      label: 'Confidence erosion',
      detail: 'Self-check reliability and prediction confidence fell together.',
      timestamp: _nearEnd(result, secondsBeforeEnd: 26),
      duration: const Duration(seconds: 28),
      severity: erosion.clamp(0.36, 1).toDouble(),
      downstreamWeight: 0.54,
    );
  }

  CascadePropagationNode? _delayedInterventionNode(RadarTrainingResult result) {
    final event = _firstMatchingEvent(result, (event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('delayed') || lower.contains('late');
    });
    if (event == null && result.score.lateResolutionCount == 0) return null;
    return CascadePropagationNode(
      id: 'delayed-intervention',
      type: CascadePropagationNodeType.delayedIntervention,
      label: 'Delayed intervention',
      detail: event?.label ??
          'A conflict was resolved later than the traffic picture required.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 20),
      duration: const Duration(seconds: 22),
      severity: result.score.lateResolutionCount > 0 ? 0.76 : 0.52,
      downstreamWeight: 0.5,
    );
  }

  CascadePropagationNode? _recoveryInterruptionNode(
      RadarTrainingResult result) {
    final event = _firstMatchingEvent(result, (event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('interrupted') || lower.contains('recovery');
    });
    if (event == null &&
        result.snapshot.cognitiveCascadeState.intentionInterruptionActive ==
            false) {
      return null;
    }
    return CascadePropagationNode(
      id: 'recovery-interruption',
      type: CascadePropagationNodeType.recoveryInterruption,
      label: 'Recovery interrupted',
      detail: event?.label ??
          'A recovery attempt competed with another active problem.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 14),
      duration: const Duration(seconds: 18),
      severity: 0.58,
      downstreamWeight: 0.38,
    );
  }

  CascadePropagationNode? _stabilizationNode(RadarTrainingResult result) {
    final event = _firstEvent(result, [
      'metaSuccessfulRecovery',
      'metaRecoveryAction',
      'cognitiveCascadeRecovery',
    ]);
    if (event == null && result.score.proactiveStabilizationBonus == 0) {
      return null;
    }
    return CascadePropagationNode(
      id: 'stabilization',
      type: CascadePropagationNodeType.stabilization,
      label: 'Stabilization',
      detail: event?.label ?? 'Traffic flow stabilized after recovery action.',
      timestamp: event?.elapsed ?? _nearEnd(result, secondsBeforeEnd: 8),
      duration: const Duration(seconds: 26),
      severity: 0.5,
      downstreamWeight: 0.2,
    );
  }

  CascadePropagationNode? _recoveryBreakdownNode(RadarTrainingResult result) {
    final cascade = result.snapshot.cognitiveCascadeState;
    if (!cascade.recoveryInstabilityActive &&
        result.score.separationLossCount == 0 &&
        result.score.ignoredCriticalAlertCount == 0) {
      return null;
    }
    return CascadePropagationNode(
      id: 'recovery-breakdown',
      type: CascadePropagationNodeType.recoveryBreakdown,
      label: 'Recovery breakdown',
      detail:
          'Recovery stayed unstable while safety-critical pressure remained.',
      timestamp: _nearEnd(result, secondsBeforeEnd: 6),
      duration: const Duration(seconds: 18),
      severity: result.score.separationLossCount > 0 ? 0.88 : 0.62,
      downstreamWeight: 0.32,
    );
  }

  List<CascadePropagationEdge> _edgesFor(List<CascadePropagationNode> nodes) {
    final edges = <CascadePropagationEdge>[];
    for (var i = 1; i < nodes.length; i++) {
      final from = nodes[i - 1];
      final to = nodes[i];
      edges.add(CascadePropagationEdge(
        fromNodeId: from.id,
        toNodeId: to.id,
        explanation: _edgeExplanation(from.type, to.type),
        confidence: ((from.severity + to.severity) / 2).clamp(0.42, 0.92),
      ));
    }
    return edges;
  }

  String _edgeExplanation(
    CascadePropagationNodeType from,
    CascadePropagationNodeType to,
  ) {
    if (from == CascadePropagationNodeType.fixation &&
        to == CascadePropagationNodeType.scanNeglect) {
      return 'Narrow focus reduced scan breadth, so unattended tracks stayed outside the active picture.';
    }
    if (from == CascadePropagationNodeType.scanNeglect &&
        to == CascadePropagationNodeType.missedConflict) {
      return 'Reduced scan coverage overlapped with an unresolved conflict cue.';
    }
    if (to == CascadePropagationNodeType.overloadIncrease) {
      return 'The unresolved issue added alert and command pressure, increasing workload.';
    }
    if (to == CascadePropagationNodeType.confidenceErosion) {
      return 'Prediction confidence and self-check reliability weakened under pressure.';
    }
    if (to == CascadePropagationNodeType.delayedIntervention) {
      return 'Recognition lag left less time for a clean recovery instruction.';
    }
    if (to == CascadePropagationNodeType.recoveryInterruption) {
      return 'Recovery was attempted while another problem still competed for attention.';
    }
    if (to == CascadePropagationNodeType.stabilization) {
      return 'A recovery action interrupted the degradation chain and restored control margin.';
    }
    if (to == CascadePropagationNodeType.recoveryBreakdown) {
      return 'The recovery window remained unstable and degradation resumed.';
    }
    return 'Timing and matching reports indicate this state contributed to the next degradation.';
  }

  CascadePropagationNodeType _secondaryType(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('memory')) {
      return CascadePropagationNodeType.workingMemoryFailure;
    }
    if (lower.contains('scan')) return CascadePropagationNodeType.scanNeglect;
    if (lower.contains('confidence')) {
      return CascadePropagationNodeType.confidenceErosion;
    }
    if (lower.contains('recovery')) {
      return CascadePropagationNodeType.recoveryBreakdown;
    }
    return CascadePropagationNodeType.overloadIncrease;
  }

  String _secondaryLabel(String label) {
    final type = _secondaryType(label);
    return switch (type) {
      CascadePropagationNodeType.workingMemoryFailure => 'Memory pressure',
      CascadePropagationNodeType.scanNeglect => 'Scan pressure',
      CascadePropagationNodeType.confidenceErosion => 'Confidence pressure',
      CascadePropagationNodeType.recoveryBreakdown => 'Recovery pressure',
      _ => 'Parallel pressure',
    };
  }

  void _addIf(
    List<CascadePropagationNode> nodes,
    CascadePropagationNode? node,
  ) {
    if (node != null) nodes.add(node);
  }

  SimulationEvent? _firstEvent(RadarTrainingResult result, List<String> types) {
    return _firstMatchingEvent(result, (event) => types.contains(event.type));
  }

  SimulationEvent? _firstMatchingEvent(
    RadarTrainingResult result,
    bool Function(SimulationEvent event) test,
  ) {
    final matches = result.snapshot.events.where(test).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    return matches.isEmpty ? null : matches.first;
  }

  double _attentionSeverity(RadarTrainingResult result) {
    final focus = result.snapshot.attentionFocus;
    return (focus.riskLevel.index / 3 +
            (1 - focus.scanCoverageQuality) +
            focus.ignoredCriticalCount * 0.16)
        .clamp(0.4, 1)
        .toDouble();
  }

  Duration _nearEnd(RadarTrainingResult result,
      {required int secondsBeforeEnd}) {
    final elapsed =
        result.snapshot.elapsed - Duration(seconds: secondsBeforeEnd);
    return elapsed < Duration.zero ? Duration.zero : elapsed;
  }
}
