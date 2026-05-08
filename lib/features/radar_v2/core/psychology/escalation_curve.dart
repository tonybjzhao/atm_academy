import 'scenario_pressure_phase.dart';

class EscalationCurve {
  final Duration cycleDuration;
  final Duration deceptiveCalmStart;
  final Duration deceptiveCalmEnd;
  final Duration chainStart;
  final Duration chainEnd;
  final Duration recoveryStart;

  const EscalationCurve({
    this.cycleDuration = const Duration(seconds: 260),
    this.deceptiveCalmStart = const Duration(seconds: 58),
    this.deceptiveCalmEnd = const Duration(seconds: 86),
    this.chainStart = const Duration(seconds: 118),
    this.chainEnd = const Duration(seconds: 178),
    this.recoveryStart = const Duration(seconds: 210),
  });

  ScenarioPressurePhase phaseAt(Duration elapsed) {
    final seconds = elapsed.inSeconds % cycleDuration.inSeconds;
    if (seconds < 45) return ScenarioPressurePhase.calm;
    if (seconds < 92) return ScenarioPressurePhase.building;
    if (seconds < 126) return ScenarioPressurePhase.busy;
    if (seconds < 178) return ScenarioPressurePhase.unstable;
    if (seconds < 210) return ScenarioPressurePhase.overload;
    return ScenarioPressurePhase.recovery;
  }

  bool deceptiveCalmAt(Duration elapsed) {
    final seconds = elapsed.inSeconds % cycleDuration.inSeconds;
    return seconds >= deceptiveCalmStart.inSeconds &&
        seconds <= deceptiveCalmEnd.inSeconds;
  }

  bool escalationChainAt(Duration elapsed) {
    final seconds = elapsed.inSeconds % cycleDuration.inSeconds;
    return seconds >= chainStart.inSeconds && seconds <= chainEnd.inSeconds;
  }

  bool attentionTrapAt(Duration elapsed) {
    final seconds = elapsed.inSeconds % cycleDuration.inSeconds;
    return (seconds >= 96 && seconds <= 118) ||
        (seconds >= 184 && seconds <= 204);
  }
}
