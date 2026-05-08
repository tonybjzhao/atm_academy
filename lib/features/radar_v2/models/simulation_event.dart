class SimulationEvent {
  final Duration elapsed;
  final String type;
  final String label;
  final String? aircraftId;

  const SimulationEvent({
    required this.elapsed,
    required this.type,
    required this.label,
    this.aircraftId,
  });
}
