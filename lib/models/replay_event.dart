enum ReplayEventType {
  normal,
  conflictWarning,  // horizontal < warning threshold
  separationLoss,   // LOS occurred
  userVector,       // user issued heading command
  userAltitudeChange,
  userSpeedChange,
  recovered,        // conflict resolved after warning
}

/// One snapshot of an aircraft at a given moment in the replay.
class AircraftStateFrame {
  final double      timestampSeconds;
  final String      callsign;
  final double      x;
  final double      y;
  final int         altitude;  // FL style
  final double      heading;
  final double      speed;

  const AircraftStateFrame({
    required this.timestampSeconds,
    required this.callsign,
    required this.x,
    required this.y,
    required this.altitude,
    required this.heading,
    required this.speed,
  });
}

/// A notable event that occurred during the scenario.
class ReplayEvent {
  final double          timestampSeconds;
  final String          aircraftId;      // callsign, or '' for multi-aircraft events
  final double          x;
  final double          y;
  final ReplayEventType eventType;
  final String?         label;           // short display label

  const ReplayEvent({
    required this.timestampSeconds,
    required this.aircraftId,
    required this.x,
    required this.y,
    required this.eventType,
    this.label,
  });
}

/// A command the user issued during the scenario.
class UserAction {
  final double  timestampSeconds;
  final String  callsign;
  final String  command;    // 'left' | 'right' | 'climb' | 'descend' | 'slow' | 'fast'
  final String  feedback;   // 'good' | 'neutral' | 'bad'

  const UserAction({
    required this.timestampSeconds,
    required this.callsign,
    required this.command,
    required this.feedback,
  });

  String get commandLabel {
    switch (command) {
      case 'left':    return 'Turn left';
      case 'right':   return 'Turn right';
      case 'climb':   return 'Climb';
      case 'descend': return 'Descend';
      case 'slow':    return 'Slow';
      case 'fast':    return 'Accelerate';
      default:        return command;
    }
  }
}
