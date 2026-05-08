enum RouteProcedureType {
  star,
  sid,
  transition,
}

class RouteProcedure {
  final String id;
  final String name;
  final RouteProcedureType type;
  final List<String> waypointIds;
  final String? mergeWaypointId;

  const RouteProcedure({
    required this.id,
    required this.name,
    required this.type,
    required this.waypointIds,
    this.mergeWaypointId,
  });

  static RouteProcedureType parseType(Object? value) {
    switch (value) {
      case 'sid':
        return RouteProcedureType.sid;
      case 'transition':
        return RouteProcedureType.transition;
      case 'star':
      default:
        return RouteProcedureType.star;
    }
  }
}
