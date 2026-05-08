sealed class ControllerCommand {
  final String aircraftId;
  final Duration issuedAt;

  const ControllerCommand({
    required this.aircraftId,
    required this.issuedAt,
  });
}

class AssignHeading extends ControllerCommand {
  final double headingDeg;

  const AssignHeading({
    required super.aircraftId,
    required super.issuedAt,
    required this.headingDeg,
  });
}

class AssignAltitude extends ControllerCommand {
  final int altitudeFt;

  const AssignAltitude({
    required super.aircraftId,
    required super.issuedAt,
    required this.altitudeFt,
  });
}

class AssignSpeed extends ControllerCommand {
  final double speedKt;

  const AssignSpeed({
    required super.aircraftId,
    required super.issuedAt,
    required this.speedKt,
  });
}

class DirectToWaypoint extends ControllerCommand {
  final String waypointId;

  const DirectToWaypoint({
    required super.aircraftId,
    required super.issuedAt,
    required this.waypointId,
  });
}
