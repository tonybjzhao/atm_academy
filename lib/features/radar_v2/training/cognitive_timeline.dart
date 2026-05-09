import 'debrief_insight.dart';
import 'radar_training_result.dart';

enum CognitiveTimelineLayerType {
  workload,
  attentionQuality,
  workingMemory,
  surpriseLoad,
  fixation,
  scanBlind,
  recovery,
  expectationConfidence,
  selfAssessment,
}

enum CognitiveTimelineEventType {
  separationWarning,
  delayedRecognition,
  forgottenIntention,
  expectationMismatch,
  cascadeOnset,
  overloadPeak,
  recovery,
  salience,
}

class CognitiveTimelineSegment {
  final Duration start;
  final Duration end;
  final double intensity;
  final String label;

  const CognitiveTimelineSegment({
    required this.start,
    required this.end,
    required this.intensity,
    required this.label,
  });
}

class CognitiveTimelineLayer {
  final CognitiveTimelineLayerType type;
  final String label;
  final List<CognitiveTimelineSegment> segments;

  const CognitiveTimelineLayer({
    required this.type,
    required this.label,
    required this.segments,
  });
}

class CognitiveTimelineMarker {
  final Duration elapsed;
  final CognitiveTimelineEventType type;
  final String label;
  final String? relatedInsightId;

  const CognitiveTimelineMarker({
    required this.elapsed,
    required this.type,
    required this.label,
    this.relatedInsightId,
  });
}

class CognitiveTimelineData {
  final Duration duration;
  final List<CognitiveTimelineLayer> layers;
  final List<CognitiveTimelineMarker> markers;
  final List<CognitiveTimelineSegment> salienceRegions;

  const CognitiveTimelineData({
    required this.duration,
    required this.layers,
    required this.markers,
    required this.salienceRegions,
  });
}

class CognitiveTimelineBuilder {
  const CognitiveTimelineBuilder();

  CognitiveTimelineData build(RadarTrainingResult result) {
    final duration = _durationFor(result);
    final markers = _buildMarkers(result, duration);
    final salienceRegions = _buildSalienceRegions(
      result.debriefSalience.primaryInsights,
      duration,
    );
    final layers = <CognitiveTimelineLayer>[
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.workload,
        label: 'Workload',
        segments: _workloadSegments(result, duration),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.attentionQuality,
        label: 'Attention',
        segments: _attentionSegments(result, duration),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.workingMemory,
        label: 'Memory',
        segments: _workingMemorySegments(result, duration),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.surpriseLoad,
        label: 'Surprise',
        segments: _surpriseSegments(result, duration),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.fixation,
        label: 'Fixation',
        segments: _eventSegments(
          result,
          duration,
          types: const ['attentionFixationWindow'],
          fallbackActive:
              result.snapshot.attentionFocus.fixationWindowCount > 0,
          fallbackLabel: 'Fixation risk',
        ),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.scanBlind,
        label: 'Scan blind',
        segments: _eventSegments(
          result,
          duration,
          types: const ['attentionScanBlind'],
          fallbackActive:
              result.snapshot.attentionFocus.scanBlindDuration > Duration.zero,
          fallbackLabel: 'Scan narrowing',
        ),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.recovery,
        label: 'Recovery',
        segments: _recoverySegments(result, duration),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.expectationConfidence,
        label: 'Expectation',
        segments: _expectationSegments(result, duration),
      ),
      CognitiveTimelineLayer(
        type: CognitiveTimelineLayerType.selfAssessment,
        label: 'Self-check',
        segments: _selfAssessmentSegments(result, duration),
      ),
    ];
    return CognitiveTimelineData(
      duration: duration,
      layers: List.unmodifiable(layers),
      markers: List.unmodifiable(markers),
      salienceRegions: List.unmodifiable(salienceRegions),
    );
  }

  Duration _durationFor(RadarTrainingResult result) {
    final seconds = <int>[
      result.snapshot.elapsed.inSeconds,
      for (final event in result.snapshot.events) event.elapsed.inSeconds,
      for (final moment in result.replayMoments) moment.elapsed.inSeconds,
    ];
    final maxSeconds = seconds.isEmpty
        ? 120
        : seconds.reduce((a, b) => a > b ? a : b).clamp(90, 1200);
    return Duration(seconds: maxSeconds);
  }

  List<CognitiveTimelineMarker> _buildMarkers(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final markers = <CognitiveTimelineMarker>[];
    for (final event in result.snapshot.events) {
      final type = _markerTypeFor(event.type, event.label);
      if (type == null) continue;
      markers.add(CognitiveTimelineMarker(
        elapsed: _clampDuration(event.elapsed, duration),
        type: type,
        label: event.label,
      ));
    }
    for (final insight in result.debriefSalience.primaryInsights) {
      final elapsed = insight.timestamp ?? _firstRelatedMoment(result, insight);
      markers.add(CognitiveTimelineMarker(
        elapsed: _clampDuration(elapsed ?? duration, duration),
        type: CognitiveTimelineEventType.salience,
        label: insight.title,
        relatedInsightId: insight.id,
      ));
    }
    markers.sort((a, b) => a.elapsed.compareTo(b.elapsed));
    final seen = <String>{};
    return markers.where((marker) {
      final key = '${marker.elapsed.inSeconds}:${marker.type}:${marker.label}';
      return seen.add(key);
    }).toList();
  }

  List<CognitiveTimelineSegment> _buildSalienceRegions(
    List<DebriefInsight> insights,
    Duration duration,
  ) {
    return insights.map((insight) {
      final center = insight.timestamp ?? Duration(seconds: duration.inSeconds);
      final start = center - const Duration(seconds: 15);
      final end = center + const Duration(seconds: 20);
      return CognitiveTimelineSegment(
        start: _clampDuration(start, duration),
        end: _clampDuration(end, duration),
        intensity: _severityIntensity(insight.severity),
        label: insight.title,
      );
    }).toList();
  }

  List<CognitiveTimelineSegment> _workloadSegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final segments = <CognitiveTimelineSegment>[
      CognitiveTimelineSegment(
        start: Duration.zero,
        end: duration,
        intensity:
            (result.snapshot.cognitiveLoad.totalLoadScore / 10).clamp(0, 1),
        label: 'Baseline workload',
      ),
    ];
    for (final spike in result.snapshot.cognitiveLoad.recentSpikes) {
      segments.add(_window(
        spike.occurredAt,
        duration,
        label: 'Overload peak',
        intensity: (spike.peakScore / 10).clamp(0.55, 1),
      ));
    }
    if (result.score.totalOverloadDuration > Duration.zero) {
      segments.add(CognitiveTimelineSegment(
        start: _clampDuration(
            duration - result.score.totalOverloadDuration, duration),
        end: duration,
        intensity: 0.78,
        label: 'Sustained overload',
      ));
    }
    return segments;
  }

  List<CognitiveTimelineSegment> _attentionSegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final attention = result.snapshot.attentionFocus;
    final intensity =
        (1 - attention.scanCoverageQuality).clamp(0, 1).toDouble();
    final segments = <CognitiveTimelineSegment>[
      CognitiveTimelineSegment(
        start: Duration.zero,
        end: duration,
        intensity: intensity,
        label: 'Attention quality',
      ),
    ];
    if (attention.longestNeglect >= const Duration(seconds: 12)) {
      segments.add(CognitiveTimelineSegment(
        start: _clampDuration(duration - attention.longestNeglect, duration),
        end: duration,
        intensity: 0.68,
        label: 'Long unseen interval',
      ));
    }
    return segments;
  }

  List<CognitiveTimelineSegment> _workingMemorySegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final memory = result.snapshot.workingMemoryState;
    final pressure = (memory.forgottenIntentionCount +
            memory.interruptedWorkflowCount +
            memory.delayedFollowThroughCount) /
        8;
    final segments = <CognitiveTimelineSegment>[
      CognitiveTimelineSegment(
        start: Duration.zero,
        end: duration,
        intensity: pressure.clamp(0, 1),
        label: 'Task stability',
      ),
    ];
    for (final item
        in memory.pendingIntentions.where((item) => item.forgotten)) {
      segments.add(CognitiveTimelineSegment(
        start: _clampDuration(item.createdAt, duration),
        end: _clampDuration(
            item.lastTouchedAt + const Duration(seconds: 20), duration),
        intensity: 0.72,
        label: item.typeLabel,
      ));
    }
    return segments;
  }

  List<CognitiveTimelineSegment> _surpriseSegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final state = result.snapshot.predictiveMentalModelState;
    final segments = <CognitiveTimelineSegment>[
      CognitiveTimelineSegment(
        start: Duration.zero,
        end: duration,
        intensity: state.surpriseLoad.clamp(0, 1),
        label: 'Surprise load',
      ),
    ];
    for (final mismatch in state.newlyDetectedMismatches) {
      segments.add(_window(
        mismatch.firstDetectedAt,
        duration,
        label: mismatch.typeLabel,
        intensity: mismatch.severity.clamp(0.35, 1),
      ));
    }
    return segments;
  }

  List<CognitiveTimelineSegment> _recoverySegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final segments = <CognitiveTimelineSegment>[];
    for (final action
        in result.snapshot.metaCognitionState.recentRecoveryActions) {
      segments.add(_window(
        action.triggeredAt,
        duration,
        label: action.action,
        intensity: action.effectiveness.clamp(0.35, 1),
      ));
    }
    for (final event in result.snapshot.events) {
      if (event.type != 'metaSuccessfulRecovery' &&
          event.type != 'metaRecoveryAction' &&
          event.type != 'cognitiveCascadeRecovery') {
        continue;
      }
      segments.add(_window(
        event.elapsed,
        duration,
        label: event.label,
        intensity: 0.72,
      ));
    }
    if (segments.isEmpty && result.score.proactiveStabilizationBonus > 0) {
      segments.add(CognitiveTimelineSegment(
        start: _clampDuration(duration - const Duration(seconds: 35), duration),
        end: duration,
        intensity: 0.58,
        label: 'Stabilized flow',
      ));
    }
    return segments;
  }

  List<CognitiveTimelineSegment> _expectationSegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final expectation = result.snapshot.expectationState;
    final predictive = result.snapshot.predictiveMentalModelState;
    final confidenceDrop =
        (1 - predictive.aggregatePredictionConfidence).clamp(0, 1);
    return [
      CognitiveTimelineSegment(
        start: Duration.zero,
        end: duration,
        intensity:
            (confidenceDrop + expectation.driftScore).clamp(0, 1).toDouble(),
        label: expectation.driftLabel,
      ),
      if (expectation.falseRecoveryActive)
        CognitiveTimelineSegment(
          start:
              _clampDuration(duration - const Duration(seconds: 45), duration),
          end: duration,
          intensity: 0.74,
          label: 'False recovery',
        ),
    ];
  }

  List<CognitiveTimelineSegment> _selfAssessmentSegments(
    RadarTrainingResult result,
    Duration duration,
  ) {
    final meta = result.snapshot.metaCognitionState;
    final assessment = meta.latestAssessment;
    final divergence = (assessment.estimatedWorkload -
            result.snapshot.cognitiveLoad.totalLoadScore / 10)
        .abs()
        .clamp(0, 1);
    return [
      CognitiveTimelineSegment(
        start: Duration.zero,
        end: duration,
        intensity: (divergence + (1 - meta.confidenceCalibrationQuality) * 0.5)
            .clamp(0, 1)
            .toDouble(),
        label: assessment.degradationBlindness
            ? 'Confidence collapse'
            : 'Self-assessment divergence',
      ),
    ];
  }

  List<CognitiveTimelineSegment> _eventSegments(
    RadarTrainingResult result,
    Duration duration, {
    required List<String> types,
    required bool fallbackActive,
    required String fallbackLabel,
  }) {
    final segments = <CognitiveTimelineSegment>[];
    for (final event in result.snapshot.events) {
      if (!types.contains(event.type)) continue;
      segments.add(_window(
        event.elapsed,
        duration,
        label: event.label,
        intensity: 0.76,
      ));
    }
    if (segments.isEmpty && fallbackActive) {
      segments.add(CognitiveTimelineSegment(
        start: _clampDuration(duration - const Duration(seconds: 30), duration),
        end: duration,
        intensity: 0.62,
        label: fallbackLabel,
      ));
    }
    return segments;
  }

  CognitiveTimelineSegment _window(
    Duration center,
    Duration duration, {
    required String label,
    required double intensity,
  }) {
    return CognitiveTimelineSegment(
      start: _clampDuration(center - const Duration(seconds: 10), duration),
      end: _clampDuration(center + const Duration(seconds: 18), duration),
      intensity: intensity.toDouble(),
      label: label,
    );
  }

  CognitiveTimelineEventType? _markerTypeFor(String type, String label) {
    final lower = '$type $label'.toLowerCase();
    if (lower.contains('separation') || lower.contains('conflict')) {
      return CognitiveTimelineEventType.separationWarning;
    }
    if (lower.contains('delayed') || lower.contains('late')) {
      return CognitiveTimelineEventType.delayedRecognition;
    }
    if (lower.contains('forgotten')) {
      return CognitiveTimelineEventType.forgottenIntention;
    }
    if (lower.contains('mismatch') || lower.contains('expectation')) {
      return CognitiveTimelineEventType.expectationMismatch;
    }
    if (lower.contains('cascade'))
      return CognitiveTimelineEventType.cascadeOnset;
    if (lower.contains('overload'))
      return CognitiveTimelineEventType.overloadPeak;
    if (lower.contains('recovery') || lower.contains('stabil')) {
      return CognitiveTimelineEventType.recovery;
    }
    return null;
  }

  Duration? _firstRelatedMoment(
    RadarTrainingResult result,
    DebriefInsight insight,
  ) {
    final related = result.replayMoments.where((moment) {
      final text = '${moment.label} ${moment.type}'.toLowerCase();
      final body = insight.body.toLowerCase();
      return body.contains(moment.type.toLowerCase()) ||
          insight.title.toLowerCase().split(' ').any(text.contains);
    });
    return related.isEmpty ? null : related.first.elapsed;
  }

  double _severityIntensity(DebriefInsightSeverity severity) {
    return switch (severity) {
      DebriefInsightSeverity.critical => 0.95,
      DebriefInsightSeverity.high => 0.78,
      DebriefInsightSeverity.medium => 0.54,
      DebriefInsightSeverity.low => 0.32,
    };
  }

  Duration _clampDuration(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (value > max) return max;
    return value;
  }
}
