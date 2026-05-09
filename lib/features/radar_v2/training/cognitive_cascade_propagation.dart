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
  final double contributionStrength;
  final List<String> evidenceFactors;

  const CascadePropagationEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.explanation,
    required this.confidence,
    required this.contributionStrength,
    this.evidenceFactors = const [],
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
      edges: List.unmodifiable(_inferEdges(result, nodes)),
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
        edges: List.unmodifiable(_inferEdges(result, nodes)),
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

  List<CascadePropagationEdge> _inferEdges(
    RadarTrainingResult result,
    List<CascadePropagationNode> nodes,
  ) {
    final edges = <CascadePropagationEdge>[];
    for (var targetIndex = 1; targetIndex < nodes.length; targetIndex++) {
      final target = nodes[targetIndex];
      final candidates = <_EdgeCandidate>[];
      for (var sourceIndex = 0; sourceIndex < targetIndex; sourceIndex++) {
        final source = nodes[sourceIndex];
        final candidate = _scoreCandidate(result, source, target, nodes);
        if (candidate.score >= 0.26) candidates.add(candidate);
      }
      candidates.sort((a, b) => b.score.compareTo(a.score));
      for (final candidate in candidates.take(2)) {
        edges.add(CascadePropagationEdge(
          fromNodeId: candidate.source.id,
          toNodeId: target.id,
          explanation: _edgeExplanation(
            candidate.source,
            target,
            candidate.evidenceFactors,
            candidate.interruptedByRecovery,
          ),
          confidence: candidate.confidence,
          contributionStrength: candidate.score,
          evidenceFactors: List.unmodifiable(candidate.evidenceFactors),
        ));
      }
    }
    return edges;
  }

  _EdgeCandidate _scoreCandidate(
    RadarTrainingResult result,
    CascadePropagationNode source,
    CascadePropagationNode target,
    List<CascadePropagationNode> nodes,
  ) {
    final temporal = _temporalProximity(source, target);
    final overlap = _durationOverlap(source, target);
    final alertDensity = _alertDensity(result);
    final workloadTrend = _workloadTrend(result, source, target);
    final attentionOverlap =
        _attentionDegradationOverlap(result, source, target);
    final unresolvedConflict = _unresolvedConflictFactor(result, target);
    final recoveryInterruption =
        _recoveryInterruptionOverlap(nodes, source, target);
    final typeCompatibility = _typeCompatibility(source.type, target.type);

    var score = temporal * 0.22 +
        overlap * 0.16 +
        alertDensity * 0.12 +
        workloadTrend * 0.14 +
        attentionOverlap * 0.14 +
        unresolvedConflict * 0.12 +
        typeCompatibility * 0.18;

    if (recoveryInterruption > 0) {
      score *= (1 - recoveryInterruption * 0.42);
    }
    if (source.type == CascadePropagationNodeType.stabilization &&
        target.type != CascadePropagationNodeType.recoveryBreakdown) {
      score *= 0.52;
    }
    if (source.type == CascadePropagationNodeType.stabilization &&
        target.type == CascadePropagationNodeType.recoveryBreakdown) {
      score += 0.16;
    }

    final factors = <String>[
      if (temporal >= 0.55) 'close timing',
      if (overlap >= 0.25) 'duration overlap',
      if (alertDensity >= 0.45) 'alert density',
      if (workloadTrend >= 0.45) 'workload trend',
      if (attentionOverlap >= 0.45) 'attention degradation overlap',
      if (unresolvedConflict >= 0.45) 'unresolved conflict pressure',
      if (recoveryInterruption > 0) 'recovery interruption reduced confidence',
    ];
    if (factors.isEmpty) factors.add('weak timing signal');

    final confidence = (score * 0.72 + temporal * 0.14 + overlap * 0.14)
        .clamp(0.18, recoveryInterruption > 0 ? 0.78 : 0.94)
        .toDouble();
    return _EdgeCandidate(
      source: source,
      score: score.clamp(0, 1).toDouble(),
      confidence: confidence,
      evidenceFactors: factors,
      interruptedByRecovery: recoveryInterruption > 0,
    );
  }

  String _edgeExplanation(
    CascadePropagationNode from,
    CascadePropagationNode to,
    List<String> factors,
    bool interruptedByRecovery,
  ) {
    final factorText = factors.take(3).join(', ');
    final recoveryClause = interruptedByRecovery
        ? ' Recovery activity weakens this inference.'
        : '';
    if (to.type == CascadePropagationNodeType.stabilization) {
      return 'Evidence suggests ${from.label.toLowerCase()} was interrupted by recovery activity ($factorText).';
    }
    return 'Evidence suggests ${from.label.toLowerCase()} likely contributed to ${to.label.toLowerCase()} through $factorText.$recoveryClause';
  }

  double _temporalProximity(
    CascadePropagationNode source,
    CascadePropagationNode target,
  ) {
    final gap = target.timestamp - source.timestamp;
    if (gap.isNegative) return 0;
    final seconds = gap.inSeconds;
    if (seconds <= 8) return 0.92;
    if (seconds <= 24) return 0.78;
    if (seconds <= 45) return 0.58;
    if (seconds <= 90) return 0.32;
    return 0.08;
  }

  double _durationOverlap(
    CascadePropagationNode source,
    CascadePropagationNode target,
  ) {
    final sourceEnd = source.timestamp + source.duration;
    final targetEnd = target.timestamp + target.duration;
    final start = source.timestamp > target.timestamp
        ? source.timestamp
        : target.timestamp;
    final end = sourceEnd < targetEnd ? sourceEnd : targetEnd;
    if (end <= start) return 0;
    return ((end - start).inSeconds / target.duration.inSeconds.clamp(1, 600))
        .clamp(0, 1)
        .toDouble();
  }

  double _alertDensity(RadarTrainingResult result) {
    final alertCount = result.snapshot.activeAlerts.length +
        result.snapshot.operationalAlerts.length;
    return (alertCount / 5).clamp(0, 1).toDouble();
  }

  double _workloadTrend(
    RadarTrainingResult result,
    CascadePropagationNode source,
    CascadePropagationNode target,
  ) {
    final base =
        (result.snapshot.cognitiveLoad.totalLoadScore / 10).clamp(0, 1);
    final overload =
        result.score.totalOverloadDuration > Duration.zero ? 0.22 : 0;
    final later = target.timestamp >= source.timestamp ? 0.12 : 0;
    return (base + overload + later).clamp(0, 1).toDouble();
  }

  double _attentionDegradationOverlap(
    RadarTrainingResult result,
    CascadePropagationNode source,
    CascadePropagationNode target,
  ) {
    final attentionLoad =
        (1 - result.snapshot.attentionFocus.scanCoverageQuality).clamp(0, 1);
    final typeSignal = source.type == CascadePropagationNodeType.fixation ||
            source.type == CascadePropagationNodeType.scanNeglect ||
            target.type == CascadePropagationNodeType.missedConflict
        ? 0.28
        : 0;
    return (attentionLoad + typeSignal).clamp(0, 1).toDouble();
  }

  double _unresolvedConflictFactor(
    RadarTrainingResult result,
    CascadePropagationNode target,
  ) {
    final conflictEvents = result.snapshot.events.where((event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('conflict') || lower.contains('separation');
    }).length;
    final scoreSignal =
        result.score.separationLossCount + result.score.lateResolutionCount;
    final targetSignal =
        target.type == CascadePropagationNodeType.missedConflict ||
                target.type == CascadePropagationNodeType.overloadIncrease ||
                target.type == CascadePropagationNodeType.delayedIntervention
            ? 0.24
            : 0;
    return ((conflictEvents + scoreSignal) / 4 + targetSignal)
        .clamp(0, 1)
        .toDouble();
  }

  double _recoveryInterruptionOverlap(
    List<CascadePropagationNode> nodes,
    CascadePropagationNode source,
    CascadePropagationNode target,
  ) {
    final recoveryNodes = nodes.where((node) {
      return (node.type == CascadePropagationNodeType.stabilization ||
              node.type == CascadePropagationNodeType.recoveryInterruption) &&
          node.timestamp > source.timestamp &&
          node.timestamp < target.timestamp;
    });
    if (recoveryNodes.isEmpty) return 0;
    return recoveryNodes
        .map((node) => node.visualWeight)
        .reduce((a, b) => a > b ? a : b)
        .clamp(0.2, 1)
        .toDouble();
  }

  double _typeCompatibility(
    CascadePropagationNodeType source,
    CascadePropagationNodeType target,
  ) {
    if (source == CascadePropagationNodeType.stabilization) {
      return target == CascadePropagationNodeType.recoveryBreakdown
          ? 0.72
          : 0.18;
    }
    if (target == CascadePropagationNodeType.missedConflict &&
        (source == CascadePropagationNodeType.scanNeglect ||
            source == CascadePropagationNodeType.workingMemoryFailure ||
            source == CascadePropagationNodeType.expectationDrift)) {
      return 0.86;
    }
    if (target == CascadePropagationNodeType.overloadIncrease &&
        (source == CascadePropagationNodeType.missedConflict ||
            source == CascadePropagationNodeType.workingMemoryFailure ||
            source == CascadePropagationNodeType.scanNeglect)) {
      return 0.78;
    }
    if (target == CascadePropagationNodeType.confidenceErosion &&
        (source == CascadePropagationNodeType.overloadIncrease ||
            source == CascadePropagationNodeType.expectationDrift)) {
      return 0.72;
    }
    if (target == CascadePropagationNodeType.delayedIntervention &&
        (source == CascadePropagationNodeType.confidenceErosion ||
            source == CascadePropagationNodeType.missedConflict ||
            source == CascadePropagationNodeType.scanNeglect)) {
      return 0.7;
    }
    if (target == CascadePropagationNodeType.recoveryBreakdown &&
        (source == CascadePropagationNodeType.recoveryInterruption ||
            source == CascadePropagationNodeType.overloadIncrease ||
            source == CascadePropagationNodeType.delayedIntervention)) {
      return 0.76;
    }
    return 0.34;
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

class _EdgeCandidate {
  final CascadePropagationNode source;
  final double score;
  final double confidence;
  final List<String> evidenceFactors;
  final bool interruptedByRecovery;

  const _EdgeCandidate({
    required this.source,
    required this.score,
    required this.confidence,
    required this.evidenceFactors,
    required this.interruptedByRecovery,
  });
}
