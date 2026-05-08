import '../alerts/alert_priority.dart';
import '../alerts/operational_alert.dart';
import 'attention_focus_state.dart';

class IgnoredAlertTracker {
  final Map<String, _IgnoredAlertRecord> _records =
      <String, _IgnoredAlertRecord>{};

  List<IgnoredAlertSnapshot> update({
    required Duration elapsed,
    required Iterable<OperationalAlert> alerts,
    required String? focusTarget,
    required bool overloaded,
  }) {
    final activeIds = <String>{};
    for (final alert in alerts) {
      activeIds.add(alert.id);
      if (alert.acknowledged || !_isHighPriority(alert)) {
        _records.remove(alert.id);
        continue;
      }
      if (_matchesFocus(alert, focusTarget)) {
        _records.remove(alert.id);
        continue;
      }
      _records.putIfAbsent(
        alert.id,
        () => _IgnoredAlertRecord(alert: alert, firstIgnoredAt: elapsed),
      );
    }
    _records.removeWhere((id, _) => !activeIds.contains(id));

    final snapshots = _records.values.map((record) {
      final ignoredFor = elapsed - record.firstIgnoredAt;
      return IgnoredAlertSnapshot(
        alertId: record.alert.id,
        alertType: record.alert.type,
        priority: record.alert.priority,
        ignoredFor: ignoredFor,
        severity: _severityFor(record.alert, ignoredFor, overloaded),
        relatedAircraftIds: record.alert.relatedAircraftIds,
        relatedRunwayId: record.alert.relatedRunwayId,
      );
    }).toList(growable: false);
    snapshots.sort((a, b) {
      final severity = b.severity.compareTo(a.severity);
      if (severity != 0) return severity;
      return b.ignoredFor.compareTo(a.ignoredFor);
    });
    return List<IgnoredAlertSnapshot>.unmodifiable(snapshots);
  }

  void reset() => _records.clear();

  bool _isHighPriority(OperationalAlert alert) {
    return alert.priority == AlertPriority.high ||
        alert.priority == AlertPriority.critical;
  }

  bool _matchesFocus(OperationalAlert alert, String? focusTarget) {
    if (focusTarget == null) return false;
    if (focusTarget == 'alert:${alert.id}') return true;
    if (alert.relatedRunwayId != null &&
        focusTarget == 'runway:${alert.relatedRunwayId}') {
      return true;
    }
    for (final aircraftId in alert.relatedAircraftIds) {
      if (focusTarget == 'aircraft:$aircraftId') return true;
    }
    return false;
  }

  int _severityFor(
    OperationalAlert alert,
    Duration ignoredFor,
    bool overloaded,
  ) {
    var severity = alert.priority == AlertPriority.critical ? 2 : 1;
    if (ignoredFor >= const Duration(seconds: 15)) severity += 1;
    if (ignoredFor >= const Duration(seconds: 30)) severity += 1;
    if (overloaded) severity += 1;
    return severity.clamp(1, 5);
  }
}

class _IgnoredAlertRecord {
  final OperationalAlert alert;
  final Duration firstIgnoredAt;

  const _IgnoredAlertRecord({
    required this.alert,
    required this.firstIgnoredAt,
  });
}
