import 'dart:math' as math;

import '../../models/arrival_flow.dart';
import '../../models/aircraft_state.dart';
import '../../models/simulation_snapshot.dart';
import '../attention/attention_focus_state.dart';
import '../cognitive_load/cognitive_load_state.dart';
import 'controller_expectation_state.dart';
import 'predictive_mental_model_state.dart';

class PredictiveMentalModelEngine {
  final Map<String, _AircraftPredictionRecord> _records =
      <String, _AircraftPredictionRecord>{};
  final Map<String, _ActiveMismatch> _mismatches = <String, _ActiveMismatch>{};
  int _surpriseOverloadMoments = 0;

  PredictiveMentalModelState evaluate({
    required SimulationSnapshot snapshot,
    required ControllerExpectationState expectationState,
    required AttentionFocusState attentionFocus,
    required CognitiveLoadState cognitiveLoad,
  }) {
    final elapsed = snapshot.elapsed;
    final activeIds = snapshot.aircraft
        .where((aircraft) => aircraft.active)
        .map((aircraft) => aircraft.id)
        .toSet();
    _records.removeWhere((id, _) => !activeIds.contains(id));

    final newlyDetected = <PredictionMismatchSnapshot>[];
    final touchedMismatchKeys = <String>{};

    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      final record = _records.putIfAbsent(
        aircraft.id,
        () => _AircraftPredictionRecord(aircraftId: aircraft.id),
      );

      final alignedFlags = <bool>[];

      _observeDelayedTurn(
        aircraft: aircraft,
        record: record,
        snapshot: snapshot,
        touchedMismatchKeys: touchedMismatchKeys,
        newlyDetected: newlyDetected,
        attentionFocus: attentionFocus,
      );
      alignedFlags.add(!_hasMismatch(aircraft.id, PredictionMismatchType.delayedTurn));

      _observeAltitudeTrend(
        aircraft: aircraft,
        record: record,
        snapshot: snapshot,
        touchedMismatchKeys: touchedMismatchKeys,
        newlyDetected: newlyDetected,
        attentionFocus: attentionFocus,
      );
      alignedFlags
          .add(!_hasMismatch(aircraft.id, PredictionMismatchType.wrongAltitudeTrend));

      _observeUnexpectedSpeed(
        aircraft: aircraft,
        record: record,
        snapshot: snapshot,
        touchedMismatchKeys: touchedMismatchKeys,
        newlyDetected: newlyDetected,
        attentionFocus: attentionFocus,
      );
      alignedFlags
          .add(!_hasMismatch(aircraft.id, PredictionMismatchType.unexpectedSpeed));

      _observeApproachAndHandoff(
        aircraft: aircraft,
        record: record,
        snapshot: snapshot,
        touchedMismatchKeys: touchedMismatchKeys,
        newlyDetected: newlyDetected,
        attentionFocus: attentionFocus,
      );
      alignedFlags
          .add(!_hasMismatch(aircraft.id, PredictionMismatchType.unstableApproach));
      alignedFlags
          .add(!_hasMismatch(aircraft.id, PredictionMismatchType.missedHandoff));
      alignedFlags.add(
          !_hasMismatch(aircraft.id, PredictionMismatchType.spacingNotStabilized));

      final alignedCount = alignedFlags.where((value) => value).length;
      final ratio = alignedFlags.isEmpty ? 1.0 : alignedCount / alignedFlags.length;
      final confidenceDelta = ratio >= 0.8 ? 0.018 : -0.038;
      final loadPenalty = (cognitiveLoad.totalLoadScore / 10) * 0.01;
      record.confidence = (record.confidence + confidenceDelta - loadPenalty)
          .clamp(0.08, 0.98);
      record.lastHeadingError = _headingError(aircraft);
      record.lastAltitudeError = _altitudeError(aircraft).abs();
      record.lastSpeedError = _speedError(aircraft).abs();
    }

    final resolvedIds = <String>[];
    for (final entry in _mismatches.entries) {
      final key = entry.key;
      final mismatch = entry.value;
      if (touchedMismatchKeys.contains(key)) continue;
      if (elapsed - mismatch.lastSeenAt < const Duration(seconds: 8)) continue;
      mismatch.resolved = true;
      resolvedIds.add(key);
    }
    for (final id in resolvedIds) {
      _mismatches.remove(id);
    }

    final activeMismatches = _mismatches.values
        .where((item) => !item.resolved)
        .map((item) => item.toSnapshot())
        .toList(growable: false)
      ..sort((a, b) => b.severity.compareTo(a.severity));

    final surpriseLoad = _surpriseLoad(
      activeMismatches: activeMismatches,
      attentionFocus: attentionFocus,
      cognitiveLoad: cognitiveLoad,
    );
    if (surpriseLoad >= 0.72 && newlyDetected.isNotEmpty) {
      _surpriseOverloadMoments += 1;
    }

    final lateRecognitionCount = activeMismatches.where((m) => m.lateRecognition).length;
    final assumptionErrors = activeMismatches
        .where((m) => m.confidenceAtDetection >= 0.72)
        .length;

    final lines = <String>[];
    if (activeMismatches.isNotEmpty) {
      lines.add('Prediction mismatches active: ${activeMismatches.length}.');
    }
    if (lateRecognitionCount > 0) {
      lines.add('Late recognition of abnormal behavior: $lateRecognitionCount.');
    }
    if (surpriseLoad >= 0.6) {
      lines.add('Surprise load elevated to ${(surpriseLoad * 100).round()}%.');
    }
    if (assumptionErrors > 0) {
      lines.add('Assumption-driven errors observed: $assumptionErrors.');
    }

    return PredictiveMentalModelState(
      aggregatePredictionConfidence: _aggregateConfidence(),
      surpriseLoad: surpriseLoad,
      surpriseOverloadMoments: _surpriseOverloadMoments,
      lateRecognitionCount: lateRecognitionCount,
      assumptionDrivenErrorCount: assumptionErrors,
      urgentReevaluationCount: newlyDetected.length,
      activeMismatches: List.unmodifiable(activeMismatches),
      newlyDetectedMismatches: List.unmodifiable(newlyDetected),
      resolvedMismatchIds: List.unmodifiable(resolvedIds),
      reportLines: List.unmodifiable(lines.take(5)),
    );
  }

  void reset() {
    _records.clear();
    _mismatches.clear();
    _surpriseOverloadMoments = 0;
  }

  void _observeDelayedTurn({
    required AircraftState aircraft,
    required _AircraftPredictionRecord record,
    required SimulationSnapshot snapshot,
    required Set<String> touchedMismatchKeys,
    required List<PredictionMismatchSnapshot> newlyDetected,
    required AttentionFocusState attentionFocus,
  }) {
    final assigned = aircraft.intent.assignedHeadingDeg;
    if (assigned == null) {
      record.clearDeviation(PredictionMismatchType.delayedTurn);
      return;
    }
    final error = _headingError(aircraft);
    final noTurnProgress = error > 16 && (record.lastHeadingError - error) < 0.8;
    _observeViolation(
      aircraftId: aircraft.id,
      type: PredictionMismatchType.delayedTurn,
      condition: noTurnProgress,
      severity: (error / 65).clamp(0.2, 1.0),
      now: snapshot.elapsed,
      confidence: record.confidence,
      attentionFocus: attentionFocus,
      touchedMismatchKeys: touchedMismatchKeys,
      newlyDetected: newlyDetected,
      firstDeviationAt: record.firstDeviationAt,
    );
  }

  void _observeAltitudeTrend({
    required AircraftState aircraft,
    required _AircraftPredictionRecord record,
    required SimulationSnapshot snapshot,
    required Set<String> touchedMismatchKeys,
    required List<PredictionMismatchSnapshot> newlyDetected,
    required AttentionFocusState attentionFocus,
  }) {
    final assigned = aircraft.intent.assignedAltitudeFt;
    if (assigned == null) {
      record.clearDeviation(PredictionMismatchType.wrongAltitudeTrend);
      return;
    }
    final delta = assigned - aircraft.altitudeFt;
    final expectedClimb = delta > 200;
    final expectedDescend = delta < -200;
    final wrongTrend = (expectedClimb && aircraft.verticalSpeedFpm < 100) ||
        (expectedDescend && aircraft.verticalSpeedFpm > -100);
    final severeGap = delta.abs() > 600;
    _observeViolation(
      aircraftId: aircraft.id,
      type: PredictionMismatchType.wrongAltitudeTrend,
      condition: wrongTrend && severeGap,
      severity: (delta.abs() / 1800).clamp(0.2, 1.0),
      now: snapshot.elapsed,
      confidence: record.confidence,
      attentionFocus: attentionFocus,
      touchedMismatchKeys: touchedMismatchKeys,
      newlyDetected: newlyDetected,
      firstDeviationAt: record.firstDeviationAt,
    );
  }

  void _observeUnexpectedSpeed({
    required AircraftState aircraft,
    required _AircraftPredictionRecord record,
    required SimulationSnapshot snapshot,
    required Set<String> touchedMismatchKeys,
    required List<PredictionMismatchSnapshot> newlyDetected,
    required AttentionFocusState attentionFocus,
  }) {
    final assigned = aircraft.intent.assignedSpeedKt;
    if (assigned == null) {
      record.clearDeviation(PredictionMismatchType.unexpectedSpeed);
      return;
    }
    final speedError = (aircraft.groundSpeedKt - assigned).abs();
    _observeViolation(
      aircraftId: aircraft.id,
      type: PredictionMismatchType.unexpectedSpeed,
      condition: speedError > 20,
      severity: (speedError / 60).clamp(0.2, 1.0),
      now: snapshot.elapsed,
      confidence: record.confidence,
      attentionFocus: attentionFocus,
      touchedMismatchKeys: touchedMismatchKeys,
      newlyDetected: newlyDetected,
      firstDeviationAt: record.firstDeviationAt,
    );
  }

  void _observeApproachAndHandoff({
    required AircraftState aircraft,
    required _AircraftPredictionRecord record,
    required SimulationSnapshot snapshot,
    required Set<String> touchedMismatchKeys,
    required List<PredictionMismatchSnapshot> newlyDetected,
    required AttentionFocusState attentionFocus,
  }) {
    final runwayId = aircraft.intent.assignedRunwayId;
    if (runwayId == null || aircraft.intent.isDeparture) {
      record.clearDeviation(PredictionMismatchType.unstableApproach);
      record.clearDeviation(PredictionMismatchType.missedHandoff);
      record.clearDeviation(PredictionMismatchType.spacingNotStabilized);
      return;
    }

    final flow = snapshot.arrivalFlows
        .where((item) => item.runwayId == runwayId)
        .toList(growable: false);
    if (flow.isEmpty) return;
    final threshold = snapshot.waypoints[flow.first.thresholdWaypointId];
    if (threshold == null) return;

    final distanceToThreshold = _distance(
      aircraft.xNm,
      aircraft.yNm,
      threshold.xNm,
      threshold.yNm,
    );

    final assignedSpeed = aircraft.intent.assignedSpeedKt ?? aircraft.groundSpeedKt;
    final assignedAlt = aircraft.intent.assignedAltitudeFt ?? aircraft.altitudeFt;
    final unstable = distanceToThreshold < 10.5 &&
        ((aircraft.groundSpeedKt - assignedSpeed).abs() > 24 ||
            (aircraft.altitudeFt - assignedAlt).abs() > 750 ||
            aircraft.verticalSpeedFpm.abs() > 1700);

    _observeViolation(
      aircraftId: aircraft.id,
      type: PredictionMismatchType.unstableApproach,
      condition: unstable,
      severity: ((10.5 - distanceToThreshold) / 10.5).clamp(0.2, 1.0),
      now: snapshot.elapsed,
      confidence: record.confidence,
      attentionFocus: attentionFocus,
      touchedMismatchKeys: touchedMismatchKeys,
      newlyDetected: newlyDetected,
      firstDeviationAt: record.firstDeviationAt,
    );

    final spacingUnstable = _spacingUnstable(snapshot, aircraft, flow.first);
    _observeViolation(
      aircraftId: aircraft.id,
      type: PredictionMismatchType.spacingNotStabilized,
      condition: distanceToThreshold < 14 && spacingUnstable,
      severity: 0.56,
      now: snapshot.elapsed,
      confidence: record.confidence,
      attentionFocus: attentionFocus,
      touchedMismatchKeys: touchedMismatchKeys,
      newlyDetected: newlyDetected,
      firstDeviationAt: record.firstDeviationAt,
    );

    final missedHandoff = distanceToThreshold < 1.6 &&
        aircraft.airborneSeconds > 180 &&
        !snapshot.events.any((event) {
          return event.type == 'handoff' && event.aircraftId == aircraft.id;
        });

    _observeViolation(
      aircraftId: aircraft.id,
      type: PredictionMismatchType.missedHandoff,
      condition: missedHandoff,
      severity: (1.6 - distanceToThreshold).clamp(0.25, 1.0),
      now: snapshot.elapsed,
      confidence: record.confidence,
      attentionFocus: attentionFocus,
      touchedMismatchKeys: touchedMismatchKeys,
      newlyDetected: newlyDetected,
      firstDeviationAt: record.firstDeviationAt,
    );
  }

  bool _spacingUnstable(
    SimulationSnapshot snapshot,
    AircraftState aircraft,
    ArrivalFlow flow,
  ) {
    final sameRunway = snapshot.aircraft.where((item) {
      return item.active &&
          !item.intent.isDeparture &&
          item.id != aircraft.id &&
          item.intent.assignedRunwayId == flow.runwayId;
    }).toList(growable: false);
    if (sameRunway.isEmpty) return false;
    for (final other in sameRunway) {
      final distance = _distance(aircraft.xNm, aircraft.yNm, other.xNm, other.yNm);
      if (distance < flow.spacingTargetNm * 0.7) return true;
    }
    return false;
  }

  void _observeViolation({
    required String aircraftId,
    required PredictionMismatchType type,
    required bool condition,
    required double severity,
    required Duration now,
    required double confidence,
    required AttentionFocusState attentionFocus,
    required Set<String> touchedMismatchKeys,
    required List<PredictionMismatchSnapshot> newlyDetected,
    required Map<PredictionMismatchType, Duration> firstDeviationAt,
  }) {
    final key = '${type.name}:$aircraftId';
    if (!condition) {
      firstDeviationAt.remove(type);
      return;
    }

    final first = firstDeviationAt.putIfAbsent(type, () => now);
    final exposure = now - first;
    final poorAttention = attentionFocus.scanCoverageQuality < 0.58 ||
        attentionFocus.scanBlindDuration >= const Duration(seconds: 8);
    final threshold = poorAttention
        ? const Duration(seconds: 10)
        : const Duration(seconds: 4);
    if (exposure < threshold) return;

    touchedMismatchKeys.add(key);
    final existing = _mismatches[key];
    if (existing == null) {
      final mismatch = _ActiveMismatch(
        id: key,
        aircraftId: aircraftId,
        type: type,
        firstDetectedAt: now,
        lastSeenAt: now,
        severity: severity,
        confidenceAtDetection: confidence,
        lateRecognition: poorAttention,
      );
      _mismatches[key] = mismatch;
      newlyDetected.add(mismatch.toSnapshot());
      return;
    }

    existing.lastSeenAt = now;
    existing.severity = math.max(existing.severity, severity);
    if (poorAttention) existing.lateRecognition = true;
  }

  bool _hasMismatch(String aircraftId, PredictionMismatchType type) {
    return _mismatches.containsKey('${type.name}:$aircraftId');
  }

  double _aggregateConfidence() {
    if (_records.isEmpty) return 0.55;
    final sum = _records.values
        .fold<double>(0, (current, item) => current + item.confidence);
    return (sum / _records.length).clamp(0.0, 1.0);
  }

  double _surpriseLoad({
    required List<PredictionMismatchSnapshot> activeMismatches,
    required AttentionFocusState attentionFocus,
    required CognitiveLoadState cognitiveLoad,
  }) {
    if (activeMismatches.isEmpty) return 0;
    final mismatchWeight = activeMismatches
            .map((mismatch) => mismatch.severity)
            .fold<double>(0, (a, b) => a + b) /
        activeMismatches.length;
    final confidenceTrap = activeMismatches
            .map((mismatch) => mismatch.confidenceAtDetection)
            .fold<double>(0, (a, b) => a + b) /
        activeMismatches.length;
    final load = (mismatchWeight * 0.45 +
            confidenceTrap * 0.22 +
            (1 - attentionFocus.scanCoverageQuality) * 0.18 +
            (cognitiveLoad.totalLoadScore / 10) * 0.15)
        .clamp(0.0, 1.0);
    return load;
  }

  double _headingError(AircraftState aircraft) {
    final assigned = aircraft.intent.assignedHeadingDeg;
    if (assigned == null) return 0;
    return _shortestAngleDelta(aircraft.headingDeg, assigned).abs();
  }

  double _altitudeError(AircraftState aircraft) {
    final assigned = aircraft.intent.assignedAltitudeFt;
    if (assigned == null) return 0;
    return (assigned - aircraft.altitudeFt).toDouble();
  }

  double _speedError(AircraftState aircraft) {
    final assigned = aircraft.intent.assignedSpeedKt;
    if (assigned == null) return 0;
    return aircraft.groundSpeedKt - assigned;
  }

  double _shortestAngleDelta(double fromDeg, double toDeg) {
    return ((toDeg - fromDeg + 540) % 360) - 180;
  }

  double _distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _AircraftPredictionRecord {
  final String aircraftId;
  double confidence = 0.55;
  double lastHeadingError = 0;
  double lastAltitudeError = 0;
  double lastSpeedError = 0;
  final Map<PredictionMismatchType, Duration> firstDeviationAt =
      <PredictionMismatchType, Duration>{};

  _AircraftPredictionRecord({required this.aircraftId});

  void clearDeviation(PredictionMismatchType type) {
    firstDeviationAt.remove(type);
  }
}

class _ActiveMismatch {
  final String id;
  final String aircraftId;
  final PredictionMismatchType type;
  final Duration firstDetectedAt;
  Duration lastSeenAt;
  double severity;
  final double confidenceAtDetection;
  bool lateRecognition;
  bool resolved = false;

  _ActiveMismatch({
    required this.id,
    required this.aircraftId,
    required this.type,
    required this.firstDetectedAt,
    required this.lastSeenAt,
    required this.severity,
    required this.confidenceAtDetection,
    this.lateRecognition = false,
  });

  PredictionMismatchSnapshot toSnapshot() {
    return PredictionMismatchSnapshot(
      id: id,
      aircraftId: aircraftId,
      type: type,
      firstDetectedAt: firstDetectedAt,
      lastSeenAt: lastSeenAt,
      severity: severity,
      confidenceAtDetection: confidenceAtDetection,
      lateRecognition: lateRecognition,
      resolved: resolved,
    );
  }
}
