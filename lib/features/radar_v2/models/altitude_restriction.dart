enum AltitudeRestrictionType {
  at,
  atOrAbove,
  atOrBelow,
}

class AltitudeRestriction {
  final String waypointId;
  final int altitudeFt;
  final AltitudeRestrictionType type;

  const AltitudeRestriction({
    required this.waypointId,
    required this.altitudeFt,
    required this.type,
  });

  static AltitudeRestrictionType parseType(Object? value) {
    switch (value?.toString()) {
      case 'atOrAbove':
        return AltitudeRestrictionType.atOrAbove;
      case 'atOrBelow':
        return AltitudeRestrictionType.atOrBelow;
      case 'at':
      case null:
        return AltitudeRestrictionType.at;
      default:
        throw FormatException('Unknown altitude restriction type: $value');
    }
  }
}
