class HoldPattern {
  final String id;
  final String fixWaypointId;
  final double inboundHeadingDeg;
  final int legSeconds;
  final int stackAltitudeFt;

  const HoldPattern({
    required this.id,
    required this.fixWaypointId,
    required this.inboundHeadingDeg,
    required this.legSeconds,
    required this.stackAltitudeFt,
  });
}
