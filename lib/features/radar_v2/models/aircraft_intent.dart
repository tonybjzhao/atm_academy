class AircraftIntent {
  final double? assignedHeadingDeg;
  final double? assignedSpeedKt;
  final int? assignedAltitudeFt;
  final List<String> route;
  final String? directToWaypointId;
  final String? assignedRunwayId;
  final String? assignedProcedureId;
  final String? holdPatternId;
  final bool hold;
  final bool isDeparture;

  const AircraftIntent({
    this.assignedHeadingDeg,
    this.assignedSpeedKt,
    this.assignedAltitudeFt,
    this.route = const [],
    this.directToWaypointId,
    this.assignedRunwayId,
    this.assignedProcedureId,
    this.holdPatternId,
    this.hold = false,
    this.isDeparture = false,
  });

  const AircraftIntent.empty()
      : assignedHeadingDeg = null,
        assignedSpeedKt = null,
        assignedAltitudeFt = null,
        route = const [],
        directToWaypointId = null,
        assignedRunwayId = null,
        assignedProcedureId = null,
        holdPatternId = null,
        hold = false,
        isDeparture = false;

  AircraftIntent copyWith({
    double? assignedHeadingDeg,
    double? assignedSpeedKt,
    int? assignedAltitudeFt,
    List<String>? route,
    String? directToWaypointId,
    String? assignedRunwayId,
    String? assignedProcedureId,
    String? holdPatternId,
    bool? hold,
    bool? isDeparture,
    bool clearAssignedHeading = false,
    bool clearAssignedSpeed = false,
    bool clearAssignedAltitude = false,
    bool clearDirectTo = false,
    bool clearAssignedRunway = false,
    bool clearHoldPattern = false,
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
      assignedRunwayId: clearAssignedRunway
          ? null
          : assignedRunwayId ?? this.assignedRunwayId,
      assignedProcedureId: assignedProcedureId ?? this.assignedProcedureId,
      holdPatternId:
          clearHoldPattern ? null : holdPatternId ?? this.holdPatternId,
      hold: hold ?? this.hold,
      isDeparture: isDeparture ?? this.isDeparture,
    );
  }
}
