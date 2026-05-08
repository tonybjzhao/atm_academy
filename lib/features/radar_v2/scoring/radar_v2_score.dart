import 'dart:math' as math;

import '../commands/controller_command.dart';
import '../models/simulation_snapshot.dart';

class RadarV2ScoreSnapshot {
  final int score;
  final int commandCount;
  final int separationLossCount;
  final int lateResolutionCount;
  final int lastDelta;
  final String? lastReason;
  final List<String> penalties;

  const RadarV2ScoreSnapshot({
    required this.score,
    required this.commandCount,
    required this.separationLossCount,
    required this.lateResolutionCount,
    required this.lastDelta,
    required this.lastReason,
    required this.penalties,
  });

  String get grade {
    if (score >= 90) return 'A';
    if (score >= 75) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }
}

class RadarV2ScoreTracker {
  final Set<String> _separationLossKeys = <String>{};
  final Set<String> _lateConflictKeys = <String>{};
  final Set<String> _weatherKeys = <String>{};
  final Set<String> _flowSpacingKeys = <String>{};
  final Set<String> _controllerLoadKeys = <String>{};
  final Set<String> _runwayOverloadKeys = <String>{};
  int _score = 100;
  int _commandCount = 0;
  int _altitudeCommandCount = 0;
  int _lastDelta = 0;
  String? _lastReason;
  final List<String> _penalties = <String>[];

  RadarV2ScoreSnapshot get snapshot => RadarV2ScoreSnapshot(
        score: _score.clamp(0, 100),
        commandCount: _commandCount,
        separationLossCount: _separationLossKeys.length,
        lateResolutionCount: _lateConflictKeys.length,
        lastDelta: _lastDelta,
        lastReason: _lastReason,
        penalties: List<String>.unmodifiable(_penalties),
      );

  void recordCommand(ControllerCommand command, SimulationSnapshot snapshot) {
    _commandCount += 1;

    if (_commandCount > 8) {
      _penalize(1, 'Excessive command load');
    }

    if (command is AssignAltitude) {
      _altitudeCommandCount += 1;
      final involvedInAlert = snapshot.separation.any((result) {
        final involved = result.aircraftAId == command.aircraftId ||
            result.aircraftBId == command.aircraftId;
        return involved &&
            (result.isLossOfSeparation || result.isPredictedConflict);
      });
      if (!involvedInAlert || _altitudeCommandCount > 3) {
        _penalize(3, 'Unnecessary altitude change');
      }
    }
  }

  void observe(SimulationSnapshot snapshot) {
    for (final result in snapshot.separation) {
      final key = _pairKey(result.aircraftAId, result.aircraftBId);
      if (result.isLossOfSeparation && _separationLossKeys.add(key)) {
        _penalize(25, 'Separation loss');
      }
      if (result.isPredictedConflict &&
          (result.timeToConflict?.inSeconds ?? 999) <= 45 &&
          _lateConflictKeys.add(key)) {
        _penalize(5, 'Late resolution');
      }
    }
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      for (final zone in snapshot.weatherZones) {
        final dx = aircraft.xNm - zone.xNm;
        final dy = aircraft.yNm - zone.yNm;
        final key = '${aircraft.id}:${zone.id}';
        if (dx * dx + dy * dy < zone.radiusNm * zone.radiusNm &&
            _weatherKeys.add(key)) {
          _penalize(2 * zone.severity, 'Weather penetration');
          return;
        }
      }
    }
    _observeArrivalSpacing(snapshot);
    _observeControllerLoad(snapshot);
    _observeRunwayPressure(snapshot);
  }

  void _observeArrivalSpacing(SimulationSnapshot snapshot) {
    for (final flow in snapshot.arrivalFlows) {
      final arrivals = snapshot.aircraft
          .where((aircraft) =>
              aircraft.active &&
              aircraft.intent.assignedRunwayId == flow.runwayId)
          .toList(growable: false);
      if (arrivals.length < 2) continue;
      final finalFix = snapshot.waypoints[flow.finalFixWaypointId];
      final threshold = snapshot.waypoints[flow.thresholdWaypointId];
      if (finalFix == null || threshold == null) continue;
      arrivals.sort((a, b) {
        final aDistance = _distanceToThresholdAlongFinal(
          a.xNm,
          a.yNm,
          finalFix.xNm,
          finalFix.yNm,
          threshold.xNm,
          threshold.yNm,
        );
        final bDistance = _distanceToThresholdAlongFinal(
          b.xNm,
          b.yNm,
          finalFix.xNm,
          finalFix.yNm,
          threshold.xNm,
          threshold.yNm,
        );
        return aDistance.compareTo(bDistance);
      });
      for (var i = 0; i < arrivals.length - 1; i++) {
        final leading = arrivals[i];
        final trailing = arrivals[i + 1];
        final lateral = _distance(
          leading.xNm,
          leading.yNm,
          trailing.xNm,
          trailing.yNm,
        );
        final key = '${flow.id}:${leading.id}:${trailing.id}';
        if (lateral < flow.spacingTargetNm && _flowSpacingKeys.add(key)) {
          _penalize(4, 'Arrival spacing compressed');
        }
      }
    }
  }

  void _observeControllerLoad(SimulationSnapshot snapshot) {
    final activeCount = snapshot.aircraft.where((item) => item.active).length;
    final key = 'load:${snapshot.elapsed.inSeconds ~/ 30}';
    if (activeCount > snapshot.maxControllerLoad &&
        _controllerLoadKeys.add(key)) {
      _penalize(3, 'Controller workload high');
    }
  }

  void _observeRunwayPressure(SimulationSnapshot snapshot) {
    for (final flow in snapshot.arrivalFlows) {
      final state = snapshot.runwayState(flow.runwayId);
      if (state == null || !state.isOccupiedAt(snapshot.elapsed)) continue;
      final threshold = snapshot.waypoints[flow.thresholdWaypointId];
      if (threshold == null) continue;
      for (final aircraft in snapshot.aircraft) {
        if (!aircraft.active ||
            aircraft.intent.assignedRunwayId != flow.runwayId) {
          continue;
        }
        if (_distance(
              aircraft.xNm,
              aircraft.yNm,
              threshold.xNm,
              threshold.yNm,
            ) <
            8) {
          final key = '${flow.runwayId}:${aircraft.id}';
          if (_runwayOverloadKeys.add(key)) {
            _penalize(4, 'Runway occupancy pressure');
          }
        }
      }
    }
  }

  void _penalize(int points, String reason) {
    _score -= points;
    _lastDelta = -points;
    _lastReason = reason;
    _penalties.add('-$points $reason');
    if (_penalties.length > 5) {
      _penalties.removeAt(0);
    }
  }

  String _pairKey(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}:${ids[1]}';
  }

  double _distance(
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _distanceToThresholdAlongFinal(
    double x,
    double y,
    double finalX,
    double finalY,
    double thresholdX,
    double thresholdY,
  ) {
    final vx = thresholdX - finalX;
    final vy = thresholdY - finalY;
    final lengthSquared = vx * vx + vy * vy;
    if (lengthSquared == 0) return _distance(x, y, thresholdX, thresholdY);
    final projected =
        (((x - finalX) * vx + (y - finalY) * vy) / lengthSquared).clamp(0, 1);
    final px = finalX + vx * projected;
    final py = finalY + vy * projected;
    return _distance(px, py, thresholdX, thresholdY);
  }
}
