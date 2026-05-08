/// Represents the urgency and criticality state of an aircraft.
///
/// Aircraft can be in different emergency or priority states that affect
/// scoring (reward prioritizing critical flights) and gameplay
/// (critical flights demand controller attention).
class AircraftUrgency {
  /// Priority weight from 0 (lowest) to 10 (highest).
  /// Default is 5 (normal priority).
  /// Used for scoring: penalize delayed attention to high-priority aircraft.
  final int priorityWeight;

  /// Emergency state indicating the type of emergency or special handling.
  final EmergencyState emergencyState;

  /// Remaining fuel in minutes. Null if unknown or not tracked.
  /// When fuel urgency is high (< 30 min remaining), should be elevated.
  final int? fuelMinutesRemaining;

  /// For medical emergencies, tracks urgency level (1–10, higher = more critical).
  /// Null if not applicable.
  final int? medicalUrgency;

  /// For unstable approach state, tracks severity (1–10).
  /// Null if not applicable.
  final int? unstableApproachSeverity;

  const AircraftUrgency({
    this.priorityWeight = 5,
    this.emergencyState = EmergencyState.normal,
    this.fuelMinutesRemaining,
    this.medicalUrgency,
    this.unstableApproachSeverity,
  });

  /// Returns true if this is a critical flight requiring immediate attention.
  bool get isCritical =>
      emergencyState != EmergencyState.normal || priorityWeight >= 8;

  /// Returns effective priority considering emergencies.
  /// Base priorityWeight is boosted by emergency state.
  int get effectivePriority {
    var effective = priorityWeight;
    switch (emergencyState) {
      case EmergencyState.normal:
        break;
      case EmergencyState.fuelCritical:
        effective = (effective + 3).clamp(0, 10);
      case EmergencyState.medical:
        effective = (effective + 4).clamp(0, 10);
      case EmergencyState.unstableApproach:
        effective = (effective + 2).clamp(0, 10);
    }
    return effective;
  }

  AircraftUrgency copyWith({
    int? priorityWeight,
    EmergencyState? emergencyState,
    int? fuelMinutesRemaining,
    int? medicalUrgency,
    int? unstableApproachSeverity,
  }) =>
      AircraftUrgency(
        priorityWeight: priorityWeight ?? this.priorityWeight,
        emergencyState: emergencyState ?? this.emergencyState,
        fuelMinutesRemaining: fuelMinutesRemaining ?? this.fuelMinutesRemaining,
        medicalUrgency: medicalUrgency ?? this.medicalUrgency,
        unstableApproachSeverity:
            unstableApproachSeverity ?? this.unstableApproachSeverity,
      );

  @override
  String toString() =>
      'AircraftUrgency(priority=$priorityWeight, emergency=$emergencyState, '
      'fuel=$fuelMinutesRemaining, medical=$medicalUrgency, unstable=$unstableApproachSeverity)';
}

/// Emergency states that elevate aircraft priority and scoring sensitivity.
enum EmergencyState {
  /// Normal flight, no special handling.
  normal,

  /// Fuel critical: aircraft running low on fuel, must land ASAP.
  /// Triggers ~30 min fuel remaining warning.
  fuelCritical,

  /// Medical emergency: passenger or crew medical event requiring immediate handling.
  /// Diversion may be needed; high priority.
  medical,

  /// Unstable approach: aircraft not stabilized on approach (speed/altitude/descent).
  /// Must be corrected or go-around declared.
  unstableApproach,
}
