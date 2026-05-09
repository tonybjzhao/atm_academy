import '../../models/simulation_snapshot.dart';
import '../alerts/alert_priority.dart';
import '../cognitive_load/cognitive_load_level.dart';
import '../psychology/scenario_pressure_phase.dart';
import 'controller_expectation_state.dart';
import 'expectation_confidence.dart';

class ExpectationTracker {
  ControllerExpectationState _state = ControllerExpectationState.idle;
  bool _initialized = false;
  bool _driftReported = false;
  bool _falseRecoveryReported = false;
  String? _anchoredFocusTarget;
  Duration _anchoredSince = Duration.zero;
  final List<String> _reportLines = <String>[];

  ControllerExpectationState evaluate(SimulationSnapshot snapshot) {
    final actual = _ActualSectorState.fromSnapshot(snapshot);
    if (!_initialized) {
      _initialized = true;
      _state = _stateFromActual(actual);
      return _state;
    }

    final overloaded = snapshot.cognitiveLoad.currentLevel.index >=
        CognitiveLoadLevel.overloaded.index;
    final saturated =
        snapshot.cognitiveLoad.currentLevel == CognitiveLoadLevel.saturated;
    final falseRecovery = _isFalseRecovery(snapshot, actual);
    final confirmationBias = overloaded || saturated || falseRecovery;
    final learningRate = falseRecovery
        ? 0.035
        : overloaded
            ? 0.055
            : 0.13;

    final runwayFlow = _state.runwayFlow.update(
      actual: actual.runwayFlow,
      learningRate: learningRate,
      underConfirmationBias: confirmationBias,
    );
    final spacingStability = _state.spacingStability.update(
      actual: actual.spacingInstability,
      learningRate: learningRate,
      underConfirmationBias: confirmationBias,
    );
    final aircraftSequencing = _state.aircraftSequencing.update(
      actual: actual.sequencePressure,
      learningRate: learningRate,
      underConfirmationBias: confirmationBias,
    );
    final alertPatterns = _state.alertPatterns.update(
      actual: actual.alertVolatility,
      learningRate: learningRate,
      underConfirmationBias: confirmationBias,
    );
    final weatherBehavior = _state.weatherBehavior.update(
      actual: actual.weatherInstability,
      learningRate: learningRate,
      underConfirmationBias: confirmationBias,
    );

    final driftScore = _weightedDrift(
      runwayFlow,
      spacingStability,
      aircraftSequencing,
      alertPatterns,
      weatherBehavior,
    );
    final attentionAnchored = _updateAnchoring(snapshot);
    final threatSensitivity = _threatSensitivity(
      confirmationBias: confirmationBias,
      falseRecovery: falseRecovery,
      driftScore: driftScore,
      saturated: saturated,
    );
    final driftLevel = _driftLevel(
      driftScore: driftScore,
      confirmationBias: confirmationBias,
      falseRecovery: falseRecovery,
      attentionAnchored: attentionAnchored,
    );

    if (!_driftReported && driftScore >= 0.32) {
      _driftReported = true;
      _addReport(
        'Controller expectation diverged from sector reality at ${snapshot.elapsed.inSeconds}s.',
      );
    }
    if (falseRecovery && !_falseRecoveryReported) {
      _falseRecoveryReported = true;
      _addReport('False recovery reduced threat sensitivity.');
    }
    if (attentionAnchored && confirmationBias) {
      _addReport('Attention remained anchored to prior conflict.');
    }

    _state = ControllerExpectationState(
      runwayFlow: runwayFlow,
      spacingStability: spacingStability,
      aircraftSequencing: aircraftSequencing,
      alertPatterns: alertPatterns,
      weatherBehavior: weatherBehavior,
      driftScore: driftScore,
      confirmationBiasActive: confirmationBias,
      falseRecoveryActive: falseRecovery,
      attentionAnchored: attentionAnchored,
      threatSensitivity: threatSensitivity,
      driftLevel: driftLevel,
      reportLines: List.unmodifiable(_reportLines.take(6)),
    );
    return _state;
  }

  void reset() {
    _state = ControllerExpectationState.idle;
    _initialized = false;
    _driftReported = false;
    _falseRecoveryReported = false;
    _anchoredFocusTarget = null;
    _anchoredSince = Duration.zero;
    _reportLines.clear();
  }

  ControllerExpectationState _stateFromActual(_ActualSectorState actual) {
    return ControllerExpectationState(
      runwayFlow: ControllerExpectation(
        expectedValue: actual.runwayFlow,
        actualValue: actual.runwayFlow,
        confidence: ExpectationConfidence.medium,
      ),
      spacingStability: ControllerExpectation(
        expectedValue: actual.spacingInstability,
        actualValue: actual.spacingInstability,
        confidence: ExpectationConfidence.medium,
      ),
      aircraftSequencing: ControllerExpectation(
        expectedValue: actual.sequencePressure,
        actualValue: actual.sequencePressure,
        confidence: ExpectationConfidence.medium,
      ),
      alertPatterns: ControllerExpectation(
        expectedValue: actual.alertVolatility,
        actualValue: actual.alertVolatility,
        confidence: ExpectationConfidence.medium,
      ),
      weatherBehavior: ControllerExpectation(
        expectedValue: actual.weatherInstability,
        actualValue: actual.weatherInstability,
        confidence: ExpectationConfidence.medium,
      ),
      driftScore: 0,
      confirmationBiasActive: false,
      falseRecoveryActive: false,
      attentionAnchored: false,
      threatSensitivity: 1,
      driftLevel: MentalModelDriftLevel.aligned,
    );
  }

  bool _isFalseRecovery(
    SimulationSnapshot snapshot,
    _ActualSectorState actual,
  ) {
    final psychology = snapshot.psychologyState;
    final calmPresentation = psychology.deceptiveCalmActive ||
        psychology.phase == ScenarioPressurePhase.recovery ||
        snapshot.cognitiveLoad.totalLoadScore < 3.0;
    final underlyingInstability = psychology.escalationChainActive ||
        actual.spacingInstability > 0.34 ||
        actual.weatherInstability > 0.34 ||
        actual.sequencePressure > 0.56;
    return calmPresentation && underlyingInstability;
  }

  bool _updateAnchoring(SimulationSnapshot snapshot) {
    final target = snapshot.attentionFocus.currentFocusTarget;
    if (target == null || target.isEmpty) {
      _anchoredFocusTarget = null;
      _anchoredSince = snapshot.elapsed;
      return false;
    }
    if (_anchoredFocusTarget != target) {
      _anchoredFocusTarget = target;
      _anchoredSince = snapshot.elapsed;
      return false;
    }
    final anchoredFor = snapshot.elapsed - _anchoredSince;
    return anchoredFor >= const Duration(seconds: 24) &&
        snapshot.operationalAlerts.length + snapshot.activeAlerts.length >= 2;
  }

  double _weightedDrift(
    ControllerExpectation runwayFlow,
    ControllerExpectation spacingStability,
    ControllerExpectation aircraftSequencing,
    ControllerExpectation alertPatterns,
    ControllerExpectation weatherBehavior,
  ) {
    final score = runwayFlow.drift * 0.18 +
        spacingStability.drift * 0.28 +
        aircraftSequencing.drift * 0.2 +
        alertPatterns.drift * 0.18 +
        weatherBehavior.drift * 0.16;
    return score.clamp(0, 1);
  }

  double _threatSensitivity({
    required bool confirmationBias,
    required bool falseRecovery,
    required double driftScore,
    required bool saturated,
  }) {
    var sensitivity = 1.0 - driftScore * 0.38;
    if (confirmationBias) sensitivity -= 0.12;
    if (falseRecovery) sensitivity -= 0.16;
    if (saturated) sensitivity -= 0.08;
    return sensitivity.clamp(0.48, 1.05);
  }

  MentalModelDriftLevel _driftLevel({
    required double driftScore,
    required bool confirmationBias,
    required bool falseRecovery,
    required bool attentionAnchored,
  }) {
    if (driftScore >= 0.46 || (attentionAnchored && driftScore >= 0.28)) {
      return MentalModelDriftLevel.criticalDrift;
    }
    if (falseRecovery) return MentalModelDriftLevel.falseRecovery;
    if (confirmationBias && driftScore >= 0.2) {
      return MentalModelDriftLevel.biased;
    }
    if (driftScore >= 0.18) return MentalModelDriftLevel.drifting;
    return MentalModelDriftLevel.aligned;
  }

  void _addReport(String line) {
    if (_reportLines.isNotEmpty && _reportLines.first == line) return;
    _reportLines.insert(0, line);
    if (_reportLines.length > 8) _reportLines.removeLast();
  }
}

class _ActualSectorState {
  final double runwayFlow;
  final double spacingInstability;
  final double sequencePressure;
  final double alertVolatility;
  final double weatherInstability;

  const _ActualSectorState({
    required this.runwayFlow,
    required this.spacingInstability,
    required this.sequencePressure,
    required this.alertVolatility,
    required this.weatherInstability,
  });

  factory _ActualSectorState.fromSnapshot(SimulationSnapshot snapshot) {
    final activeAircraft = snapshot.aircraft.where((a) => a.active).length;
    final occupiedRunways = snapshot.runwayStates
        .where((r) => r.isOccupiedAt(snapshot.elapsed))
        .length;
    final predictedConflicts =
        snapshot.separation.where((s) => s.isPredictedConflict).length;
    final separationLosses =
        snapshot.separation.where((s) => s.isLossOfSeparation).length;
    final weatherSeverity =
        snapshot.weatherZones.fold<int>(0, (sum, zone) => sum + zone.severity);
    final highPriorityAlerts = snapshot.operationalAlerts
        .where((alert) =>
            alert.priority == AlertPriority.high ||
            alert.priority == AlertPriority.critical)
        .length;

    return _ActualSectorState(
      runwayFlow:
          (occupiedRunways * 0.38 + snapshot.departureFlows.length * 0.08)
              .clamp(0, 1),
      spacingInstability:
          (snapshot.psychologyState.spacingInstabilityProbability +
                  predictedConflicts * 0.16 +
                  separationLosses * 0.35)
              .clamp(0, 1),
      sequencePressure: (activeAircraft / snapshot.maxControllerLoad +
              snapshot.sectorPressureIndex / 8)
          .clamp(0, 1),
      alertVolatility:
          ((snapshot.operationalAlerts.length + snapshot.activeAlerts.length) *
                      0.11 +
                  highPriorityAlerts * 0.15)
              .clamp(0, 1),
      weatherInstability: (weatherSeverity * 0.08 +
              (snapshot.psychologyState.escalationChainActive ? 0.22 : 0) +
              (snapshot.psychologyState.deceptiveCalmActive ? 0.08 : 0))
          .clamp(0, 1),
    );
  }
}
