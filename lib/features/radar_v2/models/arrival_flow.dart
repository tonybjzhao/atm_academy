class ArrivalFlow {
  final String id;
  final String runwayId;
  final String? procedureId;
  final String mergeWaypointId;
  final String finalFixWaypointId;
  final String thresholdWaypointId;
  final String? goAroundMergeWaypointId;
  final List<String> goAroundRouteWaypointIds;
  final double spacingTargetNm;
  final int stabilizedAltitudeFt;

  const ArrivalFlow({
    required this.id,
    required this.runwayId,
    this.procedureId,
    required this.mergeWaypointId,
    required this.finalFixWaypointId,
    required this.thresholdWaypointId,
    this.goAroundMergeWaypointId,
    this.goAroundRouteWaypointIds = const [],
    required this.spacingTargetNm,
    required this.stabilizedAltitudeFt,
  });
}
