import 'aircraft_state.dart';
import 'separation_result.dart';

class SimulationSnapshot {
  final int tick;
  final Duration elapsed;
  final List<AircraftState> aircraft;
  final List<SeparationResult> separation;

  const SimulationSnapshot({
    required this.tick,
    required this.elapsed,
    required this.aircraft,
    required this.separation,
  });

  AircraftState? aircraftById(String id) {
    for (final target in aircraft) {
      if (target.id == id) return target;
    }
    return null;
  }
}
