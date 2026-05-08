import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/alert_manager.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/alert_priority.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/operational_alert.dart';

OperationalAlert _makeAlert({
  required String id,
  required String type,
  AlertPriority priority = AlertPriority.medium,
  Duration createdAt = Duration.zero,
  Duration? expiresAt,
  int workloadImpact = 5,
}) =>
    OperationalAlert(
      id: id,
      type: type,
      priority: priority,
      createdAt: createdAt,
      expiresAt: expiresAt,
      workloadImpact: workloadImpact,
    );

void main() {
  group('AlertManager — lifecycle', () {
    late AlertManager manager;

    setUp(() => manager = AlertManager());

    test('starts empty', () {
      expect(manager.activeAlerts, isEmpty);
    });

    test('register adds an alert', () {
      manager.register(
          _makeAlert(id: 'a1', type: OperationalAlertType.separationLoss));
      expect(manager.activeAlerts.length, 1);
    });

    test('dismiss removes alert by id', () {
      manager.register(
          _makeAlert(id: 'a1', type: OperationalAlertType.separationLoss));
      manager.dismiss('a1');
      expect(manager.activeAlerts, isEmpty);
    });

    test('acknowledge sets acknowledged flag', () {
      manager
          .register(_makeAlert(id: 'a1', type: OperationalAlertType.goAround));
      manager.acknowledge('a1');
      expect(manager.activeAlerts.first.acknowledged, isTrue);
    });

    test('tick expires alerts past their expiresAt', () {
      manager.register(_makeAlert(
        id: 'exp1',
        type: OperationalAlertType.runwayOccupancy,
        expiresAt: const Duration(seconds: 10),
      ));
      expect(manager.activeAlerts.length, 1);
      manager.tick(const Duration(seconds: 11));
      expect(manager.activeAlerts, isEmpty);
    });

    test('tick keeps alerts that have not expired', () {
      manager.register(_makeAlert(
        id: 'alive',
        type: OperationalAlertType.runwayOccupancy,
        expiresAt: const Duration(seconds: 20),
      ));
      manager.tick(const Duration(seconds: 10));
      expect(manager.activeAlerts.length, 1);
    });

    test('registerOnce returns true first time, false second time', () {
      final alert = _makeAlert(id: 'once', type: OperationalAlertType.lowFuel);
      expect(manager.registerOnce(alert), isTrue);
      expect(manager.registerOnce(alert), isFalse);
      expect(manager.activeAlerts.length, 1);
    });

    test('dismissByType removes all alerts of that type', () {
      manager
          .register(_makeAlert(id: '1', type: OperationalAlertType.goAround));
      manager
          .register(_makeAlert(id: '2', type: OperationalAlertType.goAround));
      manager.register(
          _makeAlert(id: '3', type: OperationalAlertType.separationLoss));
      manager.dismissByType(OperationalAlertType.goAround);
      expect(manager.activeAlerts.length, 1);
      expect(
          manager.activeAlerts.first.type, OperationalAlertType.separationLoss);
    });

    test('reset clears all alerts', () {
      manager.register(
          _makeAlert(id: 'r1', type: OperationalAlertType.separationLoss));
      manager
          .register(_makeAlert(id: 'r2', type: OperationalAlertType.goAround));
      manager.reset();
      expect(manager.activeAlerts, isEmpty);
    });
  });

  group('AlertManager — priority ordering', () {
    late AlertManager manager;

    setUp(() => manager = AlertManager());

    test('critical alert ranks before medium', () {
      manager.register(_makeAlert(
        id: 'med',
        type: OperationalAlertType.runwayOccupancy,
        priority: AlertPriority.medium,
      ));
      manager.register(_makeAlert(
        id: 'crit',
        type: OperationalAlertType.separationLoss,
        priority: AlertPriority.critical,
      ));
      expect(manager.activeAlerts.first.id, 'crit');
    });

    test('topAlerts returns at most N alerts', () {
      for (var i = 0; i < 5; i++) {
        manager.register(
            _makeAlert(id: 'a$i', type: OperationalAlertType.goAround));
      }
      expect(manager.topAlerts(3).length, 3);
    });

    test('topAlerts returns all when fewer than N', () {
      manager
          .register(_makeAlert(id: 'x1', type: OperationalAlertType.goAround));
      expect(manager.topAlerts(5).length, 1);
    });
  });

  group('AlertManager — workload contribution', () {
    late AlertManager manager;

    setUp(() => manager = AlertManager());

    test('single critical alert contributes positive workload', () {
      manager.register(_makeAlert(
        id: 'c1',
        type: OperationalAlertType.separationLoss,
        priority: AlertPriority.critical,
        workloadImpact: 9,
      ));
      expect(manager.workloadContribution, greaterThan(0));
    });

    test('workload contribution is capped at 10', () {
      for (var i = 0; i < 20; i++) {
        manager.register(_makeAlert(
          id: 'f$i',
          type: OperationalAlertType.separationLoss,
          priority: AlertPriority.critical,
          workloadImpact: 10,
        ));
      }
      expect(manager.workloadContribution, lessThanOrEqualTo(10.0));
    });

    test('criticalCount tracks unacknowledged critical alerts', () {
      manager.register(_makeAlert(
        id: 'crit1',
        type: OperationalAlertType.separationLoss,
        priority: AlertPriority.critical,
      ));
      manager.register(_makeAlert(
        id: 'crit2',
        type: OperationalAlertType.medicalEmergency,
        priority: AlertPriority.critical,
      ));
      expect(manager.criticalCount, 2);
      expect(manager.hasCriticalUnacknowledged, isTrue);
      manager.acknowledge('crit1');
      manager.acknowledge('crit2');
      expect(manager.hasCriticalUnacknowledged, isFalse);
    });
  });
}
