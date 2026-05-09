import 'dart:math' as math;

import '../../models/simulation_snapshot.dart';
import '../attention/attention_focus_state.dart';
import 'cognitive_cascade_state.dart';
import 'predictive_mental_model_state.dart';
import 'working_memory_state.dart';
import 'meta_cognition_state.dart';

class MetaCognitionEngine {
  final double experienceLevel;
  final List<MetaAssessmentSnapshot> _history = <MetaAssessmentSnapshot>[];
  final List<MetaRecoveryAction> _recoveryHistory = <MetaRecoveryAction>[];
  int _inaccurateMoments = 0;
  int _unnoticedOverloadMoments = 0;
  int _successfulRecoveryCount = 0;

  MetaCognitionEngine({
    required this.experienceLevel,
  });

  MetaCognitionState evaluate({
    required SimulationSnapshot snapshot,
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required PredictiveMentalModelState predictive,
    required CognitiveCascadeState cascade,
  }) {
    final elapsed = snapshot.elapsed;

    final actualWorkload = (snapshot.cognitiveLoad.totalLoadScore / 10).clamp(0.0, 1.0);
    final actualScanQuality = attention.scanCoverageQuality.clamp(0.0, 1.0);
    final actualConfidenceReliability =
        predictive.aggregatePredictionConfidence.clamp(0.0, 1.0);
    final actualTaskSaturation =
        (workingMemory.pendingIntentions.length / 8).clamp(0.0, 1.0);
    final actualFixationRisk =
        (attention.riskLevel.index / 3).clamp(0.0, 1.0).toDouble();

    final accuracy = _estimationAccuracy(
      fatigue: _fatigue(snapshot),
      overloadDuration: attention.overloadDuration,
      surpriseIntensity: predictive.surpriseLoad,
      recoveryQuality: _latestRecoveryQuality(cascade),
    );

    final estimationNoise = (1 - accuracy) *
        (0.3 + _noise01('meta:noise:${elapsed.inSeconds}') * 0.7);
    final stressBias = (actualWorkload * 0.35 + predictive.surpriseLoad * 0.25)
        .clamp(0.0, 0.5);

    final estimatedWorkload =
        (actualWorkload + estimationNoise * 0.32 - _experienceBias() * 0.08)
            .clamp(0.0, 1.0);
    final estimatedScanQuality =
        (actualScanQuality + stressBias * 0.25 + estimationNoise * 0.2)
            .clamp(0.0, 1.0);
    final estimatedConfidenceReliability =
        (actualConfidenceReliability + stressBias * 0.2 + estimationNoise * 0.18)
            .clamp(0.0, 1.0);
    final estimatedTaskSaturation =
        (actualTaskSaturation - _experienceBias() * 0.1 - estimationNoise * 0.1)
            .clamp(0.0, 1.0);
    final estimatedFixationRisk =
        (actualFixationRisk - estimationNoise * 0.2 - stressBias * 0.15)
            .clamp(0.0, 1.0);

    final degradationBlindness = _degradationBlindness(
      actualWorkload: actualWorkload,
      actualFixationRisk: actualFixationRisk,
      actualTaskSaturation: actualTaskSaturation,
      accuracy: accuracy,
      elapsed: elapsed,
    );

    final assessment = MetaAssessmentSnapshot(
      elapsed: elapsed,
      estimatedWorkload: estimatedWorkload,
      estimatedScanQuality: estimatedScanQuality,
      estimatedConfidenceReliability: estimatedConfidenceReliability,
      estimatedTaskSaturation: estimatedTaskSaturation,
      estimatedFixationRisk: estimatedFixationRisk,
      calibrationAccuracy: accuracy,
      degradationBlindness: degradationBlindness,
    );
    _history.add(assessment);
    if (_history.length > 300) {
      _history.removeAt(0);
    }

    final inaccurate = _isInaccurateAssessment(
      assessment: assessment,
      actualWorkload: actualWorkload,
      actualScanQuality: actualScanQuality,
      actualTaskSaturation: actualTaskSaturation,
      actualFixationRisk: actualFixationRisk,
    );
    if (inaccurate) {
      _inaccurateMoments += 1;
    }
    if (degradationBlindness && actualWorkload >= 0.7) {
      _unnoticedOverloadMoments += 1;
    }

    final recoveryActions = _computeRecoveryActions(
      elapsed: elapsed,
      assessment: assessment,
      actualWorkload: actualWorkload,
      actualScanQuality: actualScanQuality,
      actualTaskSaturation: actualTaskSaturation,
      actualFixationRisk: actualFixationRisk,
      predictive: predictive,
      cascade: cascade,
    );
    if (recoveryActions.isNotEmpty) {
      _recoveryHistory.insertAll(0, recoveryActions);
      if (_recoveryHistory.length > 40) {
        _recoveryHistory.removeRange(40, _recoveryHistory.length);
      }
      for (final action in recoveryActions) {
        if (action.effectiveness >= 0.6) {
          _successfulRecoveryCount += 1;
        }
      }
    }

    final lines = <String>[];
    if (inaccurate) {
      lines.add('Self-assessment drifted from actual cognitive state.');
    }
    if (degradationBlindness) {
      lines.add('Degradation blindness: overload cues not fully recognized.');
    }
    if (recoveryActions.isNotEmpty) {
      lines.add(
        'Meta-recovery actions: ${recoveryActions.map((a) => a.action).join(', ')}.',
      );
    }

    return MetaCognitionState(
      latestAssessment: assessment,
      inaccurateSelfAssessmentMoments: _inaccurateMoments,
      unnoticedOverloadMoments: _unnoticedOverloadMoments,
      successfulSelfRecoveryCount: _successfulRecoveryCount,
      confidenceCalibrationQuality: _calibrationQuality(),
      recentRecoveryActions: List.unmodifiable(_recoveryHistory.take(6)),
      reportLines: List.unmodifiable(lines.take(4)),
    );
  }

  void reset() {
    _history.clear();
    _recoveryHistory.clear();
    _inaccurateMoments = 0;
    _unnoticedOverloadMoments = 0;
    _successfulRecoveryCount = 0;
  }

  double _estimationAccuracy({
    required double fatigue,
    required Duration overloadDuration,
    required double surpriseIntensity,
    required double recoveryQuality,
  }) {
    final overload = (overloadDuration.inSeconds / 120).clamp(0.0, 1.0);
    final base = 0.44 + experienceLevel * 0.42;
    final penalty = fatigue * 0.2 + overload * 0.23 + surpriseIntensity * 0.19;
    final bonus = recoveryQuality * 0.14;
    return (base - penalty + bonus).clamp(0.08, 0.98);
  }

  double _fatigue(SimulationSnapshot snapshot) {
    final elapsedFatigue = (snapshot.elapsed.inSeconds / 1500).clamp(0.0, 1.0);
    final loadFatigue = (snapshot.cognitiveLoad.totalLoadScore / 10) * 0.4;
    return (elapsedFatigue + loadFatigue).clamp(0.0, 1.0);
  }

  double _experienceBias() {
    return (experienceLevel - 0.5).clamp(-0.4, 0.4);
  }

  bool _degradationBlindness({
    required double actualWorkload,
    required double actualFixationRisk,
    required double actualTaskSaturation,
    required double accuracy,
    required Duration elapsed,
  }) {
    if (actualWorkload < 0.62) return false;
    final blindChance = 0.08 +
        (actualWorkload * 0.24) +
        (actualFixationRisk * 0.2) +
        (actualTaskSaturation * 0.16) +
        ((1 - accuracy) * 0.28);
    return _noise01('meta:blind:${elapsed.inSeconds}') <
        blindChance.clamp(0.0, 0.92);
  }

  bool _isInaccurateAssessment({
    required MetaAssessmentSnapshot assessment,
    required double actualWorkload,
    required double actualScanQuality,
    required double actualTaskSaturation,
    required double actualFixationRisk,
  }) {
    final workloadError = (assessment.estimatedWorkload - actualWorkload).abs();
    final scanError = (assessment.estimatedScanQuality - actualScanQuality).abs();
    final saturationError =
        (assessment.estimatedTaskSaturation - actualTaskSaturation).abs();
    final fixationError =
        (assessment.estimatedFixationRisk - actualFixationRisk).abs();
    return workloadError > 0.25 ||
        scanError > 0.25 ||
        saturationError > 0.25 ||
        fixationError > 0.25;
  }

  List<MetaRecoveryAction> _computeRecoveryActions({
    required Duration elapsed,
    required MetaAssessmentSnapshot assessment,
    required double actualWorkload,
    required double actualScanQuality,
    required double actualTaskSaturation,
    required double actualFixationRisk,
    required PredictiveMentalModelState predictive,
    required CognitiveCascadeState cascade,
  }) {
    final actions = <MetaRecoveryAction>[];
    if (assessment.degradationBlindness) return actions;

    final pressure = (actualWorkload * 0.3 +
            (1 - actualScanQuality) * 0.2 +
            actualTaskSaturation * 0.2 +
            actualFixationRisk * 0.15 +
            predictive.surpriseLoad * 0.15)
        .clamp(0.0, 1.0);

    if (pressure < 0.45) return actions;

    final baseEffectiveness =
        (assessment.calibrationAccuracy * 0.55 + _experienceBias() * 0.25 + 0.25)
            .clamp(0.1, 0.95);

    if (actualScanQuality < 0.62) {
      actions.add(MetaRecoveryAction(
        action: 'widen scan deliberately',
        triggeredAt: elapsed,
        effectiveness: (baseEffectiveness + 0.08).clamp(0.1, 1.0),
      ));
    }
    if (actualWorkload > 0.65 || predictive.surpriseLoad > 0.6) {
      actions.add(MetaRecoveryAction(
        action: 'slow command tempo',
        triggeredAt: elapsed,
        effectiveness: baseEffectiveness,
      ));
    }
    if (actualFixationRisk > 0.45 || cascade.stickyFocusActive) {
      actions.add(MetaRecoveryAction(
        action: 're-anchor priorities',
        triggeredAt: elapsed,
        effectiveness: (baseEffectiveness - 0.05).clamp(0.1, 1.0),
      ));
    }
    if (predictive.surpriseLoad > 0.58 || cascade.intentionInterruptionActive) {
      actions.add(MetaRecoveryAction(
        action: 'reset mental model assumptions',
        triggeredAt: elapsed,
        effectiveness: (baseEffectiveness - 0.02).clamp(0.1, 1.0),
      ));
    }
    if (actualTaskSaturation > 0.5) {
      actions.add(MetaRecoveryAction(
        action: 'clear working-memory backlog',
        triggeredAt: elapsed,
        effectiveness: (baseEffectiveness + 0.04).clamp(0.1, 1.0),
      ));
    }

    return actions.take(3).toList(growable: false);
  }

  double _latestRecoveryQuality(CognitiveCascadeState cascade) {
    if (cascade.chainHistory.isEmpty) return 0.55;
    return cascade.chainHistory.last.recoveryQuality;
  }

  double _calibrationQuality() {
    if (_history.isEmpty) return 0.55;
    final avg = _history
            .map((item) => item.calibrationAccuracy)
            .reduce((a, b) => a + b) /
        _history.length;
    final miscalPenalty = (_inaccurateMoments / math.max(1, _history.length)) * 0.35;
    return (avg - miscalPenalty).clamp(0.0, 1.0);
  }

  double _noise01(String seed) {
    var hash = 2166136261;
    for (final code in seed.codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return (hash & 0x7fffffff) / 0x7fffffff;
  }
}
