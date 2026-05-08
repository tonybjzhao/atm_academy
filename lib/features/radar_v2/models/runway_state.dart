class RunwayState {
  final String runwayId;
  final Duration occupiedUntil;
  final String? occupiedByAircraftId;

  const RunwayState({
    required this.runwayId,
    required this.occupiedUntil,
    this.occupiedByAircraftId,
  });

  bool isOccupiedAt(Duration elapsed) => occupiedUntil > elapsed;
}
