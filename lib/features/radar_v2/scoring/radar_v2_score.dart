import 'dart:math' as math;

import '../commands/controller_command.dart';
import '../models/simulation_snapshot.dart';

class RadarV2ScoreSnapshot {
  final int score;
  final int commandCount;
  final int separationLossCount;
  final int lateResolutionCount;
  final double spacingStability;
  final double throughputEfficiency;
  final double weatherManagement;
  final double commandEfficiency;
  final double anticipationScore;
  final int lastDelta;
  final String? lastReason;
  final List<String> penalties;

  const RadarV2ScoreSnapshot({
    required this.score,
    required this.commandCount,
    required this.separationLossCount,
    required this.lateResolutionCount,
    required this.spacingStability,
    required this.throughputEfficiency,
    required this.weatherManagement,
    required this.commandEfficiency,
    required this.anticipationScore,
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
  final Set<String> _holdPenaltyKeys = <String>{};
  final Set<String> _vectorPenaltyKeys = <String>{};
  final Set<String> _arrivalDelayPenaltyKeys = <String>{};
  final Map<String, Duration> _conflictFirstSeen = <String, Duration>{};
  final Map<String, bool> _conflictWasResolved = <String, bool>{};
  final Set<String> _earlyResolutionBonusKeys = <String>{};
  final Set<String> _lateResolutionPenaltyKeys = <String>{};
  final Set<String> _stabilizedFinalKeys = <String>{};
  final Set<String> _sequencingBonusKeys = <String>{};
  Set<String> _lastActiveAircraftIds = <String>{};
  int _ticksObserved = 0;
  int _stableSpacingTicks = 0;
  int _weatherSafeTicks = 0;
  int _throughputCount = 0;
  int _earlyResolutionCount = 0;
  int _proactiveSequencingCount = 0;
  int _stabilizedFinalsCount = 0;
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
        spacingStability: _percentage(_stableSpacingTicks, _ticksObserved),
        throughputEfficiency: (_throughputCount * 12).clamp(0, 100).toDouble(),
        weatherManagement: _percentage(_weatherSafeTicks, _ticksObserved),
        commandEfficiency:
            (100 - math.max(0, (_commandCount - 6) * 5)).toDouble(),
        anticipationScore: _calculateAnticipationScore(),
        lastDelta: _lastDelta,
        lastReason: _lastReason,
        penalties: List<String>.unmodifiable(_penalties),
      );

  /// Calculates controller anticipation score (0–100).
  /// Based on early resolutions, proactive sequencing, stabilized finals.
  double _calculateAnticipationScore() {
    var score = 50.0; // Base neutral score
    score += (_earlyResolutionCount * 5).clamp(0, 25).toDouble();
    score += (_proactiveSequencingCount * 3).clamp(0, 20).toDouble();
    score += (_stabilizedFinalsCount * 2).clamp(0, 20).toDouble();
    score -= _lateResolutionPenaltyKeys.length * 5;
    return score.clamp(0, 100);
  }

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
    _ticksObserved += 1;
    var spacingStableThisTick = true;
    var weatherIncursionThisTick = false;
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
          weatherIncursionThisTick = true;
          _penalize(2 * zone.severity, 'Weather penetration');
        }
        if (dx * dx + dy * dy < zone.radiusNm * zone.radiusNm) {
          weatherIncursionThisTick = true;
        }
      }
    }
    spacingStableThisTick = _observeArrivalSpacing(snapshot);
    _observeControllerLoad(snapshot);
    _observeRunwayPressure(snapshot);
    _observeFuelDelayPressure(snapshot);
    _observeAnticipation(snapshot);
    _observeThroughput(snapshot);
    if (spacingStableThisTick) {
      _stableSpacingTicks += 1;
    }
    if (!weatherIncursionThisTick) {
      _weatherSafeTicks += 1;
    }
  }

  bool _observeArrivalSpacing(SimulationSnapshot snapshot) {
    var stable = true;
    for (final flow in snapshot.arrivalFlows) {
      final arrivals = snapshot.aircraft
          .where((aircraft) =>
              aircraft.active &&
              !aircraft.intent.isDeparture &&
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
          stable = false;
          _penalize(4, 'Arrival spacing compressed');
        }
      }
    }
    return stable;
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

  void _observeFuelDelayPressure(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;

      final holdBucket = aircraft.cumulativeHoldSeconds ~/ 120;
      final holdKey = '${aircraft.id}:$holdBucket';
      if (holdBucket > 0 && _holdPenaltyKeys.add(holdKey)) {
        _penalize(2, 'Fuel pressure from prolonged hold');
      }

      final vectorBucket = aircraft.cumulativeVectorSeconds ~/ 150;
      final vectorKey = '${aircraft.id}:$vectorBucket';
      if (vectorBucket > 0 && _vectorPenaltyKeys.add(vectorKey)) {
        _penalize(2, 'Fuel pressure from excessive vectoring');
      }

      if (aircraft.intent.isDeparture) continue;
      final runwayId = aircraft.intent.assignedRunwayId;
      if (runwayId == null) continue;
      final flow = snapshot.arrivalFlows.where((item) => item.runwayId == runwayId);
      if (flow.isEmpty) continue;
      final threshold = snapshot.waypoints[flow.first.thresholdWaypointId];
      if (threshold == null) continue;
      final distance = _distance(
        aircraft.xNm,
        aircraft.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      final delayBucket = aircraft.airborneSeconds ~/ 180;
      final delayKey = '${aircraft.id}:$delayBucket';
      if (aircraft.airborneSeconds > 600 &&
          distance > 10 &&
          delayBucket > 0 &&
          _arrivalDelayPenaltyKeys.add(delayKey)) {
        _penalize(3, 'Arrival delay pressure');
      }
    }
  }

  void _observeThroughput(SimulationSnapshot snapshot) {
    final activeIds = snapshot.aircraft
        .where((aircraft) => aircraft.active)
        .map((aircraft) => aircraft.id)
        .toSet();
    for (final previousId in _lastActiveAircraftIds) {
      if (!activeIds.contains(previousId)) {
        _throughputCount += 1;
      }
    }
    _lastActiveAircraftIds = activeIds;
  }

  void _observeAnticipation(SimulationSnapshot snapshot) {
    // Track early vs late conflict resolutions
    for (final result in snapshot.separation.where((r) => r.isPredictedConflict)) {
      final key = _pairKey(result.aircraftAId, result.aircraftBId);
      
      // Mark as first seen if not already
      _conflictFirstSeen.putIfAbsent(key, () => snapshot.elapsed);
      
      // Check if conflict was resolved (no longer predicted)
      if (_conflictWasResolved[key] != true) {
        final timeToConflict = result.timeToConflict?.inSeconds ?? 999;
        
        // Early resolution: >30s warning time (bonus)
        if (timeToConflict > 30 && _earlyResolutionBonusKeys.add(key)) {
          _earlyResolutionCount += 1;
        }
      }
    }
    
    // Check for conflicts that no longer exist (were resolved)
    final currentConflictKeys = snapshot.separation
        .where((r) => r.isPredictedConflict)
        .map((r) => _pairKey(r.aircraftAId, r.aircraftBId))
        .toSet();
    
    for (final previousKey in _conflictFirstSeen.keys) {
      if (!currentConflictKeys.contains(previousKey) && 
          _conflictWasResolved[previousKey] != true) {
        _conflictWasResolved[previousKey] = true;
        
        // Check if it was resolved late (less than 5s warning)
        final wasLateResolution = _lateConflictKeys.contains(previousKey);
        if (wasLateResolution && _lateResolutionPenaltyKeys.add(previousKey)) {
          // Already penalized separately, but tracking for anticipation score
        }
      }
    }
    
    // Track stabilized finals (≥8NM on final at proper speed/altitude)
    for (final flow in snapshot.arrivalFlows) {
      final arrivals = snapshot.aircraft
          .where((aircraft) =>
              aircraft.active &&
              !aircraft.intent.isDeparture &&
              aircraft.intent.assignedRunwayId == flow.runwayId)
          .toList(growable: false);
      
      for (final aircraft in arrivals) {
        final threshold = snapshot.waypoints[flow.thresholdWaypointId];
        if (threshold == null) continue;
        
        final distance = _distance(
          aircraft.xNm,
          aircraft.yNm,
          threshold.xNm,
          threshold.yNm,
        );
        
        // On approach, ≥8NM distance, at target speed ±15kt, at target alt ±500ft
        final isStabilized = distance >= 8 &&
            distance <= 25 &&
            (aircraft.groundSpeedKt - 
              (aircraft.intent.assignedSpeedKt ?? aircraft.groundSpeedKt)).abs() <= 15 &&
            (aircraft.altitudeFt - 
              (aircraft.intent.assignedAltitudeFt ?? aircraft.altitudeFt)).abs() <= 500;
        
        if (isStabilized) {
          final key = '${flow.runwayId}:${aircraft.id}';
          if (_stabilizedFinalKeys.add(key)) {
            _stabilizedFinalsCount += 1;
          }
        }
      }
    }
    
    // Track proactive sequencing (aircraft on short final in correct order)
    for (final flow in snapshot.arrivalFlows) {
      final arrivals = snapshot.aircraft
          .where((aircraft) =>
              aircraft.active &&
              !aircraft.intent.isDeparture &&
              aircraft.intent.assignedRunwayId == flow.runwayId)
          .toList(growable: false);
      if (arrivals.length < 2) continue;
      
      final finalFix = snapshot.waypoints[flow.finalFixWaypointId];
      final threshold = snapshot.waypoints[flow.thresholdWaypointId];
      if (finalFix == null || threshold == null) continue;
      
      arrivals.sort((a, b) {
        final aDistance = _distanceToThresholdAlongFinal(
          a.xNm, a.yNm, finalFix.xNm, finalFix.yNm, 
          threshold.xNm, threshold.yNm,
        );
        final bDistance = _distanceToThresholdAlongFinal(
          b.xNm, b.yNm, finalFix.xNm, finalFix.yNm,
          threshold.xNm, threshold.yNm,
        );
        return aDistance.compareTo(bDistance);
      });
      
      // Check if sequence is maintained with proper spacing
      var sequencedCount = 0;
      for (var i = 0; i < arrivals.length - 1; i++) {
        final leading = arrivals[i];
        final trailing = arrivals[i + 1];
        final distance = _distance(
          leading.xNm, leading.yNm, trailing.xNm, trailing.yNm,
        );
        
        // Short final: within 10NM of threshold with proper spacing
        final leadingToThreshold = _distance(
          leading.xNm, leading.yNm, threshold.xNm, threshold.yNm,
        );
        
        if (leadingToThreshold < 10 && 
            distance >= flow.spacingTargetNm * 0.7) {  // 70% of target = good sequencing
          sequencedCount += 1;
        }
      }
      
      if (sequencedCount > 0) {
        final key = '${flow.id}:sequence:${snapshot.elapsed.inSeconds ~/ 10}';
        if (_sequencingBonusKeys.add(key)) {
          _proactiveSequencingCount += 1;
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

  double _percentage(int value, int total) {
    if (total <= 0) return 100;
    return (value / total * 100).clamp(0, 100).toDouble();
  }
}
