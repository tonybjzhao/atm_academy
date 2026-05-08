import '../../models/simulation_snapshot.dart';
import '../cognitive_load/cognitive_load_level.dart';
import 'escalation_curve.dart';
import 'linked_event_chain.dart';
import 'scenario_pressure_phase.dart';

class PressurePacingEngine {
  final EscalationCurve curve;
  LinkedEventChain? _activeChain;
  ScenarioPressurePhase _lastPhase = ScenarioPressurePhase.calm;
  int _lastFalseCalmReportCycle = -1;
  final List<String> _reportLines = <String>[];

  PressurePacingEngine({this.curve = const EscalationCurve()});

  ScenarioPsychologyState evaluate(SimulationSnapshot snapshot) {
    final elapsed = snapshot.elapsed;
    final phase = curve.phaseAt(elapsed);
    final deceptiveCalm = curve.deceptiveCalmAt(elapsed);
    final attentionTrap = curve.attentionTrapAt(elapsed);
    final cycleIndex = elapsed.inSeconds ~/ curve.cycleDuration.inSeconds;
    if (curve.escalationChainAt(elapsed) && _activeChain == null) {
      _activeChain = LinkedEventChain.weatherDeviation(elapsed);
      _addReport(
        'Workload collapse began after weather deviation chain at ${elapsed.inSeconds}s.',
      );
    }
    if (!curve.escalationChainAt(elapsed)) {
      _activeChain = null;
    }
    if (phase != _lastPhase) {
      if (phase == ScenarioPressurePhase.recovery) {
        _addReport('Recovery period started at ${elapsed.inSeconds}s.');
      }
      if (phase == ScenarioPressurePhase.overload) {
        _addReport('Overload onset point at ${elapsed.inSeconds}s.');
      }
      _lastPhase = phase;
    }
    if (deceptiveCalm && _lastFalseCalmReportCycle != cycleIndex) {
      _lastFalseCalmReportCycle = cycleIndex;
      _addReport('False confidence period active near ${elapsed.inSeconds}s.');
    }

    final chainStep = _activeChain?.activeStepAt(elapsed);
    final phaseValues = _phaseValues(phase);
    final loadBoost = snapshot.cognitiveLoad.currentLevel.index >=
            CognitiveLoadLevel.overloaded.index
        ? 0.12
        : 0.0;
    final chainBump = chainStep?.pressureBump ?? 0;

    return ScenarioPsychologyState(
      phase: phase,
      pressureMultiplier:
          (phaseValues.pressureMultiplier + loadBoost + chainBump)
              .clamp(0.45, 2.2),
      eventDensityFactor: deceptiveCalm ? 0.55 : phaseValues.eventDensityFactor,
      alertTimingFactor: deceptiveCalm ? 1.35 : phaseValues.alertTimingFactor,
      spacingInstabilityProbability: (phaseValues.spacingInstability +
              (chainStep == null ? 0 : chainStep.pressureBump * 0.18))
          .clamp(0, 0.7),
      deceptiveCalmActive: deceptiveCalm,
      escalationChainActive: _activeChain != null,
      attentionTrapActive: attentionTrap,
      activeChainId: _activeChain?.id,
      audioLayer: _audioLayerFor(phase, attentionTrap, deceptiveCalm),
      reportLines: List.unmodifiable(_reportLines.take(6)),
    );
  }

  void reset() {
    _activeChain = null;
    _lastPhase = ScenarioPressurePhase.calm;
    _lastFalseCalmReportCycle = -1;
    _reportLines.clear();
  }

  ({
    double pressureMultiplier,
    double eventDensityFactor,
    double alertTimingFactor,
    double spacingInstability
  }) _phaseValues(ScenarioPressurePhase phase) {
    return switch (phase) {
      ScenarioPressurePhase.calm => (
          pressureMultiplier: 0.7,
          eventDensityFactor: 0.75,
          alertTimingFactor: 1.25,
          spacingInstability: 0.02,
        ),
      ScenarioPressurePhase.building => (
          pressureMultiplier: 0.95,
          eventDensityFactor: 1.0,
          alertTimingFactor: 1.05,
          spacingInstability: 0.06,
        ),
      ScenarioPressurePhase.busy => (
          pressureMultiplier: 1.15,
          eventDensityFactor: 1.1,
          alertTimingFactor: 0.92,
          spacingInstability: 0.12,
        ),
      ScenarioPressurePhase.unstable => (
          pressureMultiplier: 1.42,
          eventDensityFactor: 1.18,
          alertTimingFactor: 0.78,
          spacingInstability: 0.24,
        ),
      ScenarioPressurePhase.overload => (
          pressureMultiplier: 1.62,
          eventDensityFactor: 0.82,
          alertTimingFactor: 0.68,
          spacingInstability: 0.32,
        ),
      ScenarioPressurePhase.recovery => (
          pressureMultiplier: 0.82,
          eventDensityFactor: 0.7,
          alertTimingFactor: 1.15,
          spacingInstability: 0.05,
        ),
    };
  }

  String _audioLayerFor(
    ScenarioPressurePhase phase,
    bool attentionTrap,
    bool deceptiveCalm,
  ) {
    if (deceptiveCalm) return 'calm ambience';
    if (attentionTrap) return 'radio density increase';
    return switch (phase) {
      ScenarioPressurePhase.calm => 'calm ambience',
      ScenarioPressurePhase.building => 'radio density increase',
      ScenarioPressurePhase.busy => 'subtle overload pulse',
      ScenarioPressurePhase.unstable => 'escalation tension texture',
      ScenarioPressurePhase.overload => 'subtle overload pulse',
      ScenarioPressurePhase.recovery => 'calm ambience',
    };
  }

  void _addReport(String line) {
    if (_reportLines.isNotEmpty && _reportLines.first == line) return;
    _reportLines.insert(0, line);
    if (_reportLines.length > 8) _reportLines.removeLast();
  }
}
