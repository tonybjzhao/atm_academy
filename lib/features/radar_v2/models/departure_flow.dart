class DepartureFlow {
  final String id;
  final String runwayId;
  final String sidProcedureId;
  final int releaseIntervalSeconds;
  final List<String> crossingRunwayIds;
  final int initialClimbFt;

  const DepartureFlow({
    required this.id,
    required this.runwayId,
    required this.sidProcedureId,
    this.releaseIntervalSeconds = 45,
    this.crossingRunwayIds = const [],
    this.initialClimbFt = 5000,
  });
}
