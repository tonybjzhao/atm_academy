import 'alert_priority.dart';
import 'operational_alert.dart';

/// Manages the lifecycle of [OperationalAlert]s: registration, expiry,
/// acknowledgement, and workload contribution queries.
///
/// Designed to be owned by [ScenarioRuntime]. Not Flutter-dependent.
/// Call [tick] each simulation step to expire stale alerts.
class AlertManager {
  final Map<String, OperationalAlert> _alerts = {};

  /// Returns a sorted, unmodifiable view of currently active alerts.
  /// Sorted descending by [OperationalAlert.urgencyScore] (most urgent first).
  List<OperationalAlert> get activeAlerts {
    final list = List<OperationalAlert>.from(_alerts.values);
    list.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return List<OperationalAlert>.unmodifiable(list);
  }

  /// Returns the top [count] most urgent active alerts.
  List<OperationalAlert> topAlerts([int count = 3]) {
    final all = activeAlerts;
    return all.length <= count ? all : all.sublist(0, count);
  }

  /// Total workload contribution from all active alerts (capped at 10).
  double get workloadContribution {
    if (_alerts.isEmpty) return 0;
    // Sum with diminishing returns: each additional alert contributes less
    final sorted = activeAlerts.map((a) => a.workloadImpact).toList();
    var total = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      total += sorted[i] / (1.0 + i * 0.3);
    }
    return total.clamp(0, 10);
  }

  /// Number of currently active critical-priority alerts.
  int get criticalCount =>
      _alerts.values.where((a) => a.priority == AlertPriority.critical).length;

  /// Whether any critical alert is currently unacknowledged.
  bool get hasCriticalUnacknowledged => _alerts.values.any(
      (a) => a.priority == AlertPriority.critical && !a.acknowledged);

  /// Registers a new alert. Replaces any existing alert with the same id.
  void register(OperationalAlert alert) {
    _alerts[alert.id] = alert;
  }

  /// Registers an alert only if one with [id] does not already exist.
  /// Returns true if the alert was newly registered.
  bool registerOnce(OperationalAlert alert) {
    if (_alerts.containsKey(alert.id)) return false;
    _alerts[alert.id] = alert;
    return true;
  }

  /// Marks an existing alert as acknowledged. No-op if alert not found.
  void acknowledge(String id) {
    final existing = _alerts[id];
    if (existing == null) return;
    _alerts[id] = existing.copyWith(acknowledged: true);
  }

  /// Removes a specific alert by id.
  void dismiss(String id) => _alerts.remove(id);

  /// Removes all alerts whose type matches.
  void dismissByType(String type) =>
      _alerts.removeWhere((_, a) => a.type == type);

  /// Removes all alerts related to a specific aircraft.
  void dismissForAircraft(String aircraftId) => _alerts.removeWhere(
      (_, a) => a.relatedAircraftIds.contains(aircraftId));

  /// Advances the alert clock: removes all expired alerts.
  /// Should be called once per simulation tick.
  void tick(Duration elapsed) {
    _alerts.removeWhere((_, a) => a.isExpiredAt(elapsed));
  }

  /// Returns true if any active alert involves the given aircraft.
  bool hasAlertForAircraft(String aircraftId) => _alerts.values
      .any((a) => a.relatedAircraftIds.contains(aircraftId));

  /// Clears all alerts (e.g., on scenario reset).
  void reset() => _alerts.clear();

  /// Returns the most urgent alert involving a specific aircraft, or null.
  OperationalAlert? topAlertForAircraft(String aircraftId) {
    final matching = _alerts.values
        .where((a) => a.relatedAircraftIds.contains(aircraftId))
        .toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return matching.first;
  }
}
