import 'dart:math' as math;

import '../../models/simulation_event.dart';
import '../../models/simulation_snapshot.dart';
import '../alerts/operational_alert.dart';
import '../attention/attention_focus_state.dart';
import '../cognitive_load/cognitive_load_state.dart';
import 'working_memory_state.dart';

class WorkingMemoryEngine {
  final Map<String, _TrackedIntention> _intentions = <String, _TrackedIntention>{};
  final Set<String> _processedEventKeys = <String>{};
  Duration? _lastElapsed;
  int _recoveredTaskCount = 0;
  int _catchUpBurstCount = 0;
  double _stressRecoveryLoad = 0;

  WorkingMemoryState evaluate({
    required SimulationSnapshot snapshot,
    required AttentionFocusState attentionFocus,
    required CognitiveLoadState cognitiveLoad,
    required List<OperationalAlert> operationalAlerts,
  }) {
    final elapsed = snapshot.elapsed;
    final delta = _lastElapsed == null
        ? const Duration(seconds: 1)
        : elapsed - _lastElapsed!;
    _lastElapsed = elapsed;

    _ingestEvents(snapshot.events, elapsed);
    _seedConflictIntentions(snapshot, operationalAlerts, elapsed);
    _seedHandoffIntentions(snapshot, elapsed);

    var interruptedWorkflowCount = 0;
    var delayedFollowThroughCount = 0;
    var forgottenIntentionCount = 0;

    for (final tracked in _intentions.values) {
      if (tracked.resolved) continue;
      _updateInterruptionState(
        tracked,
        attentionFocus: attentionFocus,
        snapshot: snapshot,
      );
      _decaySalience(
        tracked,
        delta: delta,
        cognitiveLoad: cognitiveLoad,
        attentionFocus: attentionFocus,
      );
      tracked.overdue = _isOverdue(tracked, elapsed);
      if (tracked.overdue && !tracked.forgotten) {
        delayedFollowThroughCount += 1;
      }
      if (tracked.salience < 0.28 && tracked.overdue) {
        tracked.forgotten = true;
      }
      if (tracked.forgotten) forgottenIntentionCount += 1;
      if (tracked.interrupted) interruptedWorkflowCount += 1;
    }

    _resolveFromEvents(snapshot.events, elapsed);
    _updateCatchUpBursts(snapshot.events, elapsed);

    final pending = _intentions.values
        .where((tracked) => !tracked.resolved)
        .map((tracked) => tracked.toSnapshot())
        .toList(growable: false)
      ..sort((a, b) => a.salience.compareTo(b.salience));

    final unrecoveredTaskCount = _intentions.values
        .where((tracked) => tracked.forgotten && !tracked.resolved)
        .length;

    final lines = <String>[];
    if (pending.where((i) => i.forgotten).isNotEmpty) {
      lines.add(
        'Forgotten intentions detected: ${pending.where((i) => i.forgotten).length}.',
      );
    }
    if (interruptedWorkflowCount > 0) {
      lines.add('Interrupted workflow chains: $interruptedWorkflowCount.');
    }
    if (delayedFollowThroughCount > 0) {
      lines.add('Delayed follow-through tasks: $delayedFollowThroughCount.');
    }
    if (_recoveredTaskCount > 0) {
      lines.add('Recovered intentions late: $_recoveredTaskCount.');
    }
    if (_catchUpBurstCount > 0) {
      lines.add('Catch-up command bursts after reminders: $_catchUpBurstCount.');
    }

    return WorkingMemoryState(
      pendingIntentions: List.unmodifiable(pending),
      forgottenIntentionCount: forgottenIntentionCount,
      interruptedWorkflowCount: interruptedWorkflowCount,
      delayedFollowThroughCount: delayedFollowThroughCount,
      recoveredTaskCount: _recoveredTaskCount,
      unrecoveredTaskCount: unrecoveredTaskCount,
      catchUpBurstCount: _catchUpBurstCount,
      stressRecoveryLoad: _stressRecoveryLoad.clamp(0, 2.5),
      reportLines: List.unmodifiable(lines.take(5)),
    );
  }

  void reset() {
    _intentions.clear();
    _processedEventKeys.clear();
    _lastElapsed = null;
    _recoveredTaskCount = 0;
    _catchUpBurstCount = 0;
    _stressRecoveryLoad = 0;
  }

  void _ingestEvents(List<SimulationEvent> events, Duration elapsed) {
    for (final event in events) {
      final key = '${event.elapsed.inMilliseconds}:${event.type}:${event.label}:${event.aircraftId ?? ''}';
      if (!_processedEventKeys.add(key)) continue;
      if (event.type != 'commandIssued') continue;

      final type = _typeFromCommandLabel(event.label);
      if (type == null) continue;
      final intentionId =
          'cmd:${event.elapsed.inMilliseconds}:${event.aircraftId ?? 'na'}:${type.name}';
      _intentions[intentionId] = _TrackedIntention(
        id: intentionId,
        type: type,
        createdAt: event.elapsed,
        lastTouchedAt: event.elapsed,
        targetAircraftIds:
            event.aircraftId == null ? const [] : [event.aircraftId!],
      );

      if (type == PendingIntentionType.runwayReassignment &&
          event.aircraftId != null) {
        final flowId = 'flow:${event.aircraftId!}:${event.elapsed.inMilliseconds}';
        _intentions.putIfAbsent(
          flowId,
          () => _TrackedIntention(
            id: flowId,
            type: PendingIntentionType.sequencingAdjustment,
            createdAt: elapsed,
            lastTouchedAt: elapsed,
            targetAircraftIds: [event.aircraftId!],
          ),
        );
      }
    }
  }

  void _seedConflictIntentions(
    SimulationSnapshot snapshot,
    List<OperationalAlert> operationalAlerts,
    Duration elapsed,
  ) {
    final unresolvedConflicts = snapshot.separation.where((separation) {
      return separation.isPredictedConflict || separation.isLossOfSeparation;
    });
    for (final conflict in unresolvedConflicts) {
      final key = 'conflict:${_pairKey(conflict.aircraftAId, conflict.aircraftBId)}';
      _intentions.putIfAbsent(
        key,
        () => _TrackedIntention(
          id: key,
          type: PendingIntentionType.sequencingAdjustment,
          createdAt: elapsed,
          lastTouchedAt: elapsed,
          targetAircraftIds: [conflict.aircraftAId, conflict.aircraftBId],
        ),
      );
    }

    for (final alert in operationalAlerts) {
      if (alert.type != 'runway_change') continue;
      final key = 'runway:${alert.id}';
      _intentions.putIfAbsent(
        key,
        () => _TrackedIntention(
          id: key,
          type: PendingIntentionType.runwayReassignment,
          createdAt: elapsed,
          lastTouchedAt: elapsed,
          targetRunwayId: alert.relatedRunwayId,
          targetAircraftIds: alert.relatedAircraftIds,
        ),
      );
    }
  }

  void _seedHandoffIntentions(
    SimulationSnapshot snapshot,
    Duration elapsed,
  ) {
    for (final flow in snapshot.arrivalFlows) {
      final threshold = snapshot.waypoints[flow.thresholdWaypointId];
      if (threshold == null) continue;
      for (final aircraft in snapshot.aircraft) {
        if (!aircraft.active || aircraft.intent.isDeparture) continue;
        if (aircraft.intent.assignedRunwayId != flow.runwayId) continue;
        final dx = aircraft.xNm - threshold.xNm;
        final dy = aircraft.yNm - threshold.yNm;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance > 6.5) continue;
        final key = 'handoff:${aircraft.id}';
        _intentions.putIfAbsent(
          key,
          () => _TrackedIntention(
            id: key,
            type: PendingIntentionType.handoffIntention,
            createdAt: elapsed,
            lastTouchedAt: elapsed,
            targetAircraftIds: [aircraft.id],
          ),
        );
      }
    }
  }

  void _resolveFromEvents(List<SimulationEvent> events, Duration elapsed) {
    final recentAcknowledgements = events.where((event) {
      return event.type == 'commandAcknowledged' &&
          elapsed - event.elapsed <= const Duration(seconds: 40);
    });

    for (final ack in recentAcknowledgements) {
      for (final tracked in _intentions.values) {
        if (tracked.resolved) continue;
        if (ack.aircraftId != null &&
            tracked.targetAircraftIds.isNotEmpty &&
            !tracked.targetAircraftIds.contains(ack.aircraftId)) {
          continue;
        }
        final matches = _ackMatchesIntention(ack.label, tracked.type);
        if (!matches) continue;
        tracked.resolved = true;
        tracked.lastTouchedAt = ack.elapsed;
        if (tracked.forgotten) {
          _recoveredTaskCount += 1;
          _stressRecoveryLoad += 0.14;
        }
      }
    }

    for (final event in events) {
      if (event.type != 'handoff') continue;
      if (event.aircraftId == null) continue;
      for (final tracked in _intentions.values) {
        if (tracked.resolved ||
            tracked.type != PendingIntentionType.handoffIntention) {
          continue;
        }
        if (!tracked.targetAircraftIds.contains(event.aircraftId)) continue;
        tracked.resolved = true;
        tracked.lastTouchedAt = event.elapsed;
      }
    }
  }

  void _updateCatchUpBursts(List<SimulationEvent> events, Duration elapsed) {
    if (_recoveredTaskCount == 0) return;
    final recentIssued = events.where((event) {
      return event.type == 'commandIssued' &&
          elapsed - event.elapsed <= const Duration(seconds: 12);
    }).length;
    if (recentIssued >= 3) {
      _catchUpBurstCount = math.max(_catchUpBurstCount, 1);
      _stressRecoveryLoad += 0.06;
    }
  }

  void _updateInterruptionState(
    _TrackedIntention tracked, {
    required AttentionFocusState attentionFocus,
    required SimulationSnapshot snapshot,
  }) {
    final hasInterrupts = snapshot.activeDistractions.isNotEmpty ||
        attentionFocus.activeInterrupts.isNotEmpty;
    if (!hasInterrupts) return;
    final focus = attentionFocus.currentFocusTarget;
    final focusedAircraft = focus != null && focus.startsWith('aircraft:')
        ? focus.substring('aircraft:'.length)
        : null;
    final relevantToFocus = focusedAircraft != null &&
        tracked.targetAircraftIds.contains(focusedAircraft);
    if (!relevantToFocus && attentionFocus.competingHighPriorityAlertCount > 0) {
      tracked.interrupted = true;
    }
  }

  void _decaySalience(
    _TrackedIntention tracked, {
    required Duration delta,
    required CognitiveLoadState cognitiveLoad,
    required AttentionFocusState attentionFocus,
  }) {
    final seconds = math.max(1, delta.inSeconds);
    final loadWeight = (cognitiveLoad.totalLoadScore / 10).clamp(0.0, 1.0);
    final interruptWeight =
        (attentionFocus.activeInterrupts.length / 3).clamp(0.0, 1.0);
    final interruptionBoost = tracked.interrupted ? 0.009 : 0.0;
    var decay = 0.004 + loadWeight * 0.005 + interruptWeight * 0.004 + interruptionBoost;

    if (attentionFocus.currentFocusTarget != null &&
        attentionFocus.currentFocusTarget!.startsWith('aircraft:')) {
      final focused =
          attentionFocus.currentFocusTarget!.substring('aircraft:'.length);
      if (tracked.targetAircraftIds.contains(focused)) {
        tracked.lastTouchedAt = _lastElapsed ?? tracked.lastTouchedAt;
        decay *= 0.42;
      }
    }

    tracked.salience = (tracked.salience - decay * seconds).clamp(0.05, 1.0);
  }

  bool _isOverdue(_TrackedIntention tracked, Duration elapsed) {
    final age = elapsed - tracked.createdAt;
    final threshold = switch (tracked.type) {
      PendingIntentionType.plannedDescent => const Duration(seconds: 28),
      PendingIntentionType.expectedTurn => const Duration(seconds: 24),
      PendingIntentionType.runwayReassignment => const Duration(seconds: 40),
      PendingIntentionType.sequencingAdjustment => const Duration(seconds: 34),
      PendingIntentionType.handoffIntention => const Duration(seconds: 45),
    };
    return age >= threshold;
  }

  PendingIntentionType? _typeFromCommandLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('heading') || lower.contains('direct')) {
      return PendingIntentionType.expectedTurn;
    }
    if (lower.contains('altitude') || lower.contains('descend')) {
      return PendingIntentionType.plannedDescent;
    }
    if (lower.contains('speed')) {
      return PendingIntentionType.sequencingAdjustment;
    }
    if (lower.contains('runway')) {
      return PendingIntentionType.runwayReassignment;
    }
    if (lower.contains('hold')) {
      return PendingIntentionType.sequencingAdjustment;
    }
    return null;
  }

  bool _ackMatchesIntention(String label, PendingIntentionType type) {
    final lower = label.toLowerCase();
    return switch (type) {
      PendingIntentionType.expectedTurn =>
        lower.contains('heading') || lower.contains('direct'),
      PendingIntentionType.plannedDescent => lower.contains('altitude'),
      PendingIntentionType.runwayReassignment =>
        lower.contains('runway') || lower.contains('heading'),
      PendingIntentionType.sequencingAdjustment =>
        lower.contains('speed') || lower.contains('hold') || lower.contains('heading'),
      PendingIntentionType.handoffIntention => lower.contains('handoff'),
    };
  }

  String _pairKey(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}:${ids[1]}';
  }
}

class _TrackedIntention {
  final String id;
  final PendingIntentionType type;
  final Duration createdAt;
  Duration lastTouchedAt;
  final List<String> targetAircraftIds;
  final String? targetRunwayId;
  double salience = 1.0;
  bool interrupted = false;
  bool overdue = false;
  bool forgotten = false;
  bool resolved = false;

  _TrackedIntention({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.lastTouchedAt,
    this.targetAircraftIds = const [],
    this.targetRunwayId,
  });

  PendingIntentionSnapshot toSnapshot() {
    return PendingIntentionSnapshot(
      id: id,
      type: type,
      createdAt: createdAt,
      lastTouchedAt: lastTouchedAt,
      targetAircraftIds: List.unmodifiable(targetAircraftIds),
      targetRunwayId: targetRunwayId,
      salience: salience,
      interrupted: interrupted,
      overdue: overdue,
      forgotten: forgotten,
      resolved: resolved,
    );
  }
}
