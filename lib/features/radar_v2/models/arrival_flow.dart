class ArrivalFlow {
  final String id;
  final String runwayId;
  final String mergeWaypointId;
  final String finalFixWaypointId;
  final String thresholdWaypointId;
  final double spacingTargetNm;
  final int stabilizedAltitudeFt;

  const ArrivalFlow({
    required this.id,
    required this.runwayId,
    required this.mergeWaypointId,
    required this.finalFixWaypointId,
    required this.thresholdWaypointId,
    required this.spacingTargetNm,
    required this.stabilizedAltitudeFt,
  });
}
