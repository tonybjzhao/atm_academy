class AircraftIntent {
  final double? assignedHeadingDeg;
  final double? assignedSpeedKt;
  final int? assignedAltitudeFt;
  final List<String> route;
  final String? directToWaypointId;
  final bool hold;

  const AircraftIntent({
    this.assignedHeadingDeg,
    this.assignedSpeedKt,
    this.assignedAltitudeFt,
    this.route = const [],
    this.directToWaypointId,
    this.hold = false,
  });

  const AircraftIntent.empty()
      : assignedHeadingDeg = null,
        assignedSpeedKt = null,
        assignedAltitudeFt = null,
        route = const [],
        directToWaypointId = null,
        hold = false;

  AircraftIntent copyWith({
    double? assignedHeadingDeg,
    double? assignedSpeedKt,
    int? assignedAltitudeFt,
    List<String>? route,
    String? directToWaypointId,
    bool? hold,
    bool clearAssignedHeading = false,
    bool clearAssignedSpeed = false,
    bool clearAssignedAltitude = false,
    bool clearDirectTo = false,
  }) {
    return AircraftIntent(
      assignedHeadingDeg: clearAssignedHeading
          ? null
          : assignedHeadingDeg ?? this.assignedHeadingDeg,
      assignedSpeedKt:
          clearAssignedSpeed ? null : assignedSpeedKt ?? this.assignedSpeedKt,
      assignedAltitudeFt: clearAssignedAltitude
          ? null
          : assignedAltitudeFt ?? this.assignedAltitudeFt,
      route: route ?? this.route,
      directToWaypointId:
          clearDirectTo ? null : directToWaypointId ?? this.directToWaypointId,
      hold: hold ?? this.hold,
    );
  }
}
