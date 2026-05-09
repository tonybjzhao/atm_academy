import '../../models/simulation_snapshot.dart';
import '../attention/attention_focus_state.dart';
import '../cognitive_load/cognitive_load_level.dart';
import 'cognitive_cascade_state.dart';
import 'controller_expectation_state.dart';
import 'predictive_mental_model_state.dart';
import 'working_memory_state.dart';

class CognitiveCascadeEngine {
  _ActiveCascade? _active;
  Duration? _recoveryUntil;
  CognitiveLoadLevel _lastLoadLevel = CognitiveLoadLevel.calm;
  final List<CascadeChainSummary> _history = <CascadeChainSummary>[];

  CognitiveCascadeState evaluate({
    required SimulationSnapshot snapshot,
    required PredictiveMentalModelState predictive,
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required ControllerExpectationState expectation,
  }) {
    final elapsed = snapshot.elapsed;
    var startedThisTick = false;
    var endedThisTick = false;
    final secondaryThisTick = <String>[];

    if (_active == null && predictive.newlyDetectedMismatches.isNotEmpty) {
      final root = predictive.newlyDetectedMismatches.first;
      final amplification = _amplificationProbability(
        snapshot: snapshot,
        predictive: predictive,
        attention: attention,
      );
      final roll = _noise01('${root.id}:${elapsed.inSeconds}:cascade');
      if (roll < amplification) {
        startedThisTick = true;
        _active = _ActiveCascade(
          chainId: 'cascade:${elapsed.inMilliseconds}:${root.aircraftId}',
          rootMismatchId: root.id,
          rootLabel: '${root.aircraftId} ${root.typeLabel}',
          startedAt: elapsed,
          amplification: amplification,
        );
      }
    }

    if (_active != null) {
      final chain = _active!;
      final age = elapsed - chain.startedAt;

      _maybeTriggerSecondary(
        label: 'delayed recognition elsewhere',
        baseChance: 0.18,
        elapsed: elapsed,
        attention: attention,
        chain: chain,
        sink: secondaryThisTick,
      );
      _maybeTriggerSecondary(
        label: 'forgotten pending tasks',
        baseChance: 0.16,
        elapsed: elapsed,
        attention: attention,
        chain: chain,
        sink: secondaryThisTick,
      );
      _maybeTriggerSecondary(
        label: 'command burst pressure',
        baseChance: 0.14,
        elapsed: elapsed,
        attention: attention,
        chain: chain,
        sink: secondaryThisTick,
      );
      _maybeTriggerSecondary(
        label: 'unstable prioritization',
        baseChance: 0.17,
        elapsed: elapsed,
        attention: attention,
        chain: chain,
        sink: secondaryThisTick,
      );

      // End active cascade once surprise effects decay.
      if (age >= const Duration(seconds: 38) &&
          predictive.surpriseLoad < 0.45 &&
          attention.scanCoverageQuality > 0.62) {
        endedThisTick = true;
        final recoveryQuality = _recoveryQuality(
          chain: chain,
          attention: attention,
          workingMemory: workingMemory,
          expectation: expectation,
        );
        _history.add(CascadeChainSummary(
          chainId: chain.chainId,
          rootMismatchId: chain.rootMismatchId,
          rootLabel: chain.rootLabel,
          startedAt: chain.startedAt,
          endedAt: elapsed,
          secondaryFailures: List.unmodifiable(chain.secondaryFailures),
          amplification: chain.amplification,
          recoveryQuality: recoveryQuality,
        ));
        if (_history.length > 20) {
          _history.removeAt(0);
        }
        if (_lastLoadLevel.index >= CognitiveLoadLevel.overloaded.index) {
          _recoveryUntil = elapsed + const Duration(seconds: 24);
        }
        _active = null;
      }
    }

    final recoveryActive =
        _recoveryUntil != null && elapsed < (_recoveryUntil ?? elapsed);

    if (_lastLoadLevel.index >= CognitiveLoadLevel.overloaded.index &&
        snapshot.cognitiveLoad.currentLevel.index <= CognitiveLoadLevel.busy.index) {
      _recoveryUntil = elapsed + const Duration(seconds: 24);
    }
    _lastLoadLevel = snapshot.cognitiveLoad.currentLevel;

    final scanPenalty = _active == null
        ? 0.0
        : (0.08 + _active!.amplification * 0.24) *
            _decayFactor(elapsed, _active!.startedAt, 36);
    final breadthPenalty = _active == null
        ? 0.0
        : (0.07 + _active!.amplification * 0.2) *
            _decayFactor(elapsed, _active!.startedAt, 30);
    final tunnelBoost = _active == null
        ? 0.0
        : (0.06 + _active!.amplification * 0.22) *
            _decayFactor(elapsed, _active!.startedAt, 32);

    final stickyFocus = _active != null &&
        elapsed - _active!.startedAt <= const Duration(seconds: 20);

    final report = <String>[];
    if (_active != null) {
      report.add(
        'Cascade chain active from ${_active!.rootLabel} '
        '(amp ${(_active!.amplification * 100).round()}%).',
      );
    }
    if (secondaryThisTick.isNotEmpty) {
      report.add('Secondary failures: ${secondaryThisTick.join(', ')}.');
    }
    if (recoveryActive) {
      report.add('Recovery instability active: scan and command rhythm remain volatile.');
    }

    return CognitiveCascadeState(
      chainStartedThisTick: startedThisTick,
      chainEndedThisTick: endedThisTick,
      activeChainId: _active?.chainId,
      rootSurpriseLabel: _active?.rootLabel,
      amplificationProbability: _active?.amplification ?? 0,
      scanQualityPenalty: scanPenalty.clamp(0, 0.45),
      attentionBreadthPenalty: breadthPenalty.clamp(0, 0.4),
      tunnelVisionRiskBoost: tunnelBoost.clamp(0, 0.4),
      stickyFocusActive: stickyFocus,
      intentionInterruptionActive: _active != null,
      recoveryInstabilityActive: recoveryActive,
      secondaryFailuresThisTick: List.unmodifiable(secondaryThisTick),
      chainHistory: List.unmodifiable(_history),
      reportLines: List.unmodifiable(report.take(4)),
    );
  }

  void reset() {
    _active = null;
    _recoveryUntil = null;
    _lastLoadLevel = CognitiveLoadLevel.calm;
    _history.clear();
  }

  double _amplificationProbability({
    required SimulationSnapshot snapshot,
    required PredictiveMentalModelState predictive,
    required AttentionFocusState attention,
  }) {
    final rootSeverity = predictive.newlyDetectedMismatches.isEmpty
        ? 0.0
        : predictive.newlyDetectedMismatches.first.severity;
    final workload = (snapshot.cognitiveLoad.totalLoadScore / 10).clamp(0.0, 1.0);
    final fatigue = ((snapshot.elapsed.inSeconds / 1200) +
            (attention.overloadDuration.inSeconds / 180))
        .clamp(0.0, 1.0);
    final scan = (1 - attention.scanCoverageQuality).clamp(0.0, 1.0);
    final expectationConfidence =
        predictive.aggregatePredictionConfidence.clamp(0.0, 1.0);
    final interruptionDensity = ((snapshot.activeDistractions.length +
                attention.activeInterrupts.length) /
            5)
        .clamp(0.0, 1.0);

    final probability = 0.06 +
        rootSeverity * 0.28 +
        workload * 0.2 +
        fatigue * 0.12 +
        scan * 0.15 +
        expectationConfidence * 0.1 +
        interruptionDensity * 0.12;
    return probability.clamp(0.0, 0.95);
  }

  void _maybeTriggerSecondary({
    required String label,
    required double baseChance,
    required Duration elapsed,
    required AttentionFocusState attention,
    required _ActiveCascade chain,
    required List<String> sink,
  }) {
    if (chain.secondaryFailures.contains(label)) return;
    final scanPressure = (1 - attention.scanCoverageQuality).clamp(0.0, 1.0);
    final chance = (baseChance + chain.amplification * 0.24 + scanPressure * 0.2)
        .clamp(0.0, 0.9);
    final roll = _noise01('${chain.chainId}:$label:${elapsed.inSeconds}');
    if (roll < chance) {
      chain.secondaryFailures.add(label);
      sink.add(label);
    }
  }

  double _recoveryQuality({
    required _ActiveCascade chain,
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required ControllerExpectationState expectation,
  }) {
    final penalties = (chain.secondaryFailures.length * 0.12) +
        ((1 - attention.scanCoverageQuality) * 0.25) +
        (workingMemory.unrecoveredTaskCount * 0.08) +
        (expectation.driftScore * 0.2);
    return (1 - penalties).clamp(0.0, 1.0);
  }

  double _decayFactor(Duration now, Duration startedAt, int windowSeconds) {
    final age = (now - startedAt).inSeconds;
    if (age <= 0) return 1;
    if (age >= windowSeconds) return 0;
    final t = age / windowSeconds;
    return (1 - t * t).clamp(0.0, 1.0);
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

class _ActiveCascade {
  final String chainId;
  final String rootMismatchId;
  final String rootLabel;
  final Duration startedAt;
  final double amplification;
  final List<String> secondaryFailures = <String>[];

  _ActiveCascade({
    required this.chainId,
    required this.rootMismatchId,
    required this.rootLabel,
    required this.startedAt,
    required this.amplification,
  });
}
