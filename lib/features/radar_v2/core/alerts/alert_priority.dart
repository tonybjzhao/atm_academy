/// Four-tier urgency classification for operational alerts.
///
/// Drives visual treatment, audio cues, and workload impact scoring:
/// - [low]      Informational — no immediate action required
/// - [medium]   Advisory — monitor and plan; action within ~2 min
/// - [high]     Urgent — action within ~60s
/// - [critical] Immediate — action within seconds or loss of separation
enum AlertPriority {
  low,
  medium,
  high,
  critical;

  /// Numeric weight used for sorting (higher = more urgent).
  int get sortWeight => switch (this) {
        AlertPriority.low => 1,
        AlertPriority.medium => 2,
        AlertPriority.high => 4,
        AlertPriority.critical => 8,
      };

  String get label => switch (this) {
        AlertPriority.low => 'LOW',
        AlertPriority.medium => 'MED',
        AlertPriority.high => 'HIGH',
        AlertPriority.critical => 'CRIT',
      };
}

/// Known operational alert type identifiers.
///
/// Used as [OperationalAlert.type] string values. Prefer these constants
/// over raw strings to avoid typos and enable exhaustive handling.
class OperationalAlertType {
  static const String predictedConflict = 'predicted_conflict';
  static const String separationLoss = 'separation_loss';
  static const String runwayOccupancy = 'runway_occupancy';
  static const String departureQueueSaturation = 'departure_queue_saturation';
  static const String weatherEscalation = 'weather_escalation';
  static const String goAround = 'go_around';
  static const String runwayChange = 'runway_change';
  static const String lowFuel = 'low_fuel';
  static const String unstableSpacing = 'unstable_spacing';
  static const String medicalEmergency = 'medical_emergency';
  static const String engineFailure = 'engine_failure';
  static const String abnormalBehavior = 'abnormal_behavior';

  /// Default priority for each alert type.
  static AlertPriority defaultPriority(String type) => switch (type) {
        separationLoss => AlertPriority.critical,
        medicalEmergency => AlertPriority.critical,
        engineFailure => AlertPriority.critical,
        goAround => AlertPriority.high,
        predictedConflict => AlertPriority.high,
        runwayOccupancy => AlertPriority.high,
        lowFuel => AlertPriority.high,
        unstableSpacing => AlertPriority.medium,
        abnormalBehavior => AlertPriority.high,
        weatherEscalation => AlertPriority.medium,
        departureQueueSaturation => AlertPriority.medium,
        runwayChange => AlertPriority.low,
        _ => AlertPriority.medium,
      };

  /// Workload impact score (1–10) contributed by each alert type.
  static int workloadImpact(String type) => switch (type) {
        separationLoss => 10,
        medicalEmergency => 9,
        engineFailure => 10,
        goAround => 8,
        predictedConflict => 7,
        runwayOccupancy => 6,
        lowFuel => 6,
        unstableSpacing => 5,
        abnormalBehavior => 6,
        weatherEscalation => 4,
        departureQueueSaturation => 3,
        runwayChange => 2,
        _ => 3,
      };
}
