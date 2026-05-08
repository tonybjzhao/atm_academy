import 'dart:math' as math;

import '../alerts/alert_priority.dart';
import '../alerts/operational_alert.dart';
import 'replay_workload_frame.dart';

// ── Data types ────────────────────────────────────────────────────────────────

/// A burst of commands issued in a short window — indicates reactive/panic mode.
class CommandBurstWindow {
  final Duration start;
  final Duration end;
  final int commandCount;
  final double peakWorkloadScore;

  const CommandBurstWindow({
    required this.start,
    required this.end,
    required this.commandCount,
    required this.peakWorkloadScore,
  });

  Duration get duration => end - start;
  double get commandsPerMinute =>
      commandCount / math.max(1, duration.inSeconds / 60.0);
}

/// An alert that was not acknowledged or acted upon during its active window.
class IgnoredAlertRecord {
  final String alertId;
  final String alertType;
  final AlertPriority priority;
  final Duration firedAt;
  final Duration? expiredAt;
  final Duration ignoredFor;

  const IgnoredAlertRecord({
    required this.alertId,
    required this.alertType,
    required this.priority,
    required this.firedAt,
    this.expiredAt,
    required this.ignoredFor,
  });
}

/// A period where the controller focused on one object at the expense of others.
class FixationPeriod {
  final String fixatedObjectId;
  final Duration start;
  final Duration end;
  final Duration ignoredAlertDuration;
  final double detectionLatencySeconds;

  const FixationPeriod({
    required this.fixatedObjectId,
    required this.start,
    required this.end,
    required this.ignoredAlertDuration,
    required this.detectionLatencySeconds,
  });

  Duration get duration => end - start;
}

/// The root-cause narrative explaining why workload collapsed.
class WorkloadCollapseReason {
  /// One-line summary of the collapse cause.
  final String headline;

  /// Ordered contributing factors (most significant first).
  final List<String> contributingFactors;

  /// The elapsed time at which the collapse became unrecoverable.
  final Duration? collapsedAt;

  const WorkloadCollapseReason({
    required this.headline,
    required this.contributingFactors,
    this.collapsedAt,
  });
}

/// Full post-scenario cognition analytics report.
class CognitionAnalyticsReport {
  /// The frame where workload score was highest.
  final ReplayWorkloadFrame? peakOverloadMoment;

  /// Total time the controller spent in overloaded or saturated state.
  final Duration totalOverloadDuration;

  /// Saturation-specific duration (subset of overloadDuration).
  final Duration totalSaturationDuration;

  /// Command bursts detected (>4 commands in <15 s).
  final List<CommandBurstWindow> commandBursts;

  /// Critical/high alerts that were never acknowledged.
  final List<IgnoredAlertRecord> ignoredCriticalAlerts;

  /// Longest single unresolved alert record.
  final IgnoredAlertRecord? longestUnresolvedAlert;

  /// Detected fixation periods.
  final List<FixationPeriod> fixationPeriods;

  /// Narrative explanation of workload collapse (null if no collapse occurred).
  final WorkloadCollapseReason? collapseReason;

  /// Overall cognition quality score (0–100).
  final int cognitionScore;

  const CognitionAnalyticsReport({
    required this.peakOverloadMoment,
    required this.totalOverloadDuration,
    required this.totalSaturationDuration,
    required this.commandBursts,
    required this.ignoredCriticalAlerts,
    required this.longestUnresolvedAlert,
    required this.fixationPeriods,
    required this.collapseReason,
    required this.cognitionScore,
  });

  bool get hadColapse => collapseReason != null;
  bool get isClean => cognitionScore >= 80;
}

// ── Builder / accumulator ─────────────────────────────────────────────────────

/// Accumulates simulation events during a scenario run and generates a
/// [CognitionAnalyticsReport] at the end.
///
/// Wire into [ScenarioRuntime] — call [recordTick] each tick and
/// [recordCommand] when a command is issued.  Call [generateReport] when the
/// scenario ends.
class CognitionAnalyticsTracker {
  // Workload timeline (fed from ReplayWorkloadTimeline)
  final ReplayWorkloadTimeline _timeline;

  // Command timestamps for burst detection
  final List<({Duration elapsed, String aircraftId})> _commands = [];

  // Alert lifecycle tracking
  final Map<String, _AlertLifecycle> _alertLifecycles = {};

  // Fixation records (from TunnelVisionEngine)
  final List<FixationPeriod> _fixationPeriods = [];
  String? _currentFixationId;
  Duration? _currentFixationStart;
  double _currentFixationMaxLatency = 0;

  CognitionAnalyticsTracker({ReplayWorkloadTimeline? timeline})
      : _timeline = timeline ?? ReplayWorkloadTimeline();

  ReplayWorkloadTimeline get timeline => _timeline;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Records the workload snapshot for this tick. Call every simulation tick.
  void recordTick(ReplayWorkloadFrame frame) {
    _timeline.addFrame(frame);
  }

  /// Records a command issued by the controller.
  void recordCommand({
    required Duration elapsed,
    required String aircraftId,
  }) {
    _commands.add((elapsed: elapsed, aircraftId: aircraftId));
    // Mark any related alert as responded to
    for (final entry in _alertLifecycles.values) {
      if (!entry.responded && entry.relatedAircraftIds.contains(aircraftId)) {
        entry.respondedAt = elapsed;
        entry.responded = true;
      }
    }
  }

  /// Registers an alert entering the controller's queue.
  void registerAlert(OperationalAlert alert) {
    _alertLifecycles[alert.id] = _AlertLifecycle(
      id: alert.id,
      type: alert.type,
      priority: alert.priority,
      firedAt: alert.createdAt,
      relatedAircraftIds: alert.relatedAircraftIds,
    );
  }

  /// Marks an alert as resolved/dismissed.
  void resolveAlert(String alertId, Duration elapsed) {
    final lc = _alertLifecycles[alertId];
    if (lc != null) lc.resolvedAt = elapsed;
  }

  /// Records the current tunnel-vision fixation state.
  ///
  /// [fixatedObjectId] null means no active fixation.
  void recordFixationState({
    required String? fixatedObjectId,
    required Duration elapsed,
    required double detectionLatencySeconds,
    required Duration ignoredAlertDuration,
  }) {
    if (fixatedObjectId == null) {
      if (_currentFixationId != null) {
        // Fixation ended — record the period
        _fixationPeriods.add(FixationPeriod(
          fixatedObjectId: _currentFixationId!,
          start: _currentFixationStart!,
          end: elapsed,
          ignoredAlertDuration: ignoredAlertDuration,
          detectionLatencySeconds: _currentFixationMaxLatency,
        ));
        _currentFixationId = null;
        _currentFixationStart = null;
        _currentFixationMaxLatency = 0;
      }
    } else {
      if (_currentFixationId != fixatedObjectId) {
        // New fixation started
        if (_currentFixationId != null) {
          _fixationPeriods.add(FixationPeriod(
            fixatedObjectId: _currentFixationId!,
            start: _currentFixationStart!,
            end: elapsed,
            ignoredAlertDuration: ignoredAlertDuration,
            detectionLatencySeconds: _currentFixationMaxLatency,
          ));
        }
        _currentFixationId = fixatedObjectId;
        _currentFixationStart = elapsed;
        _currentFixationMaxLatency = detectionLatencySeconds;
      } else {
        // Continuing fixation — update max latency
        _currentFixationMaxLatency =
            math.max(_currentFixationMaxLatency, detectionLatencySeconds);
      }
    }
  }

  /// Generates the final [CognitionAnalyticsReport].
  /// Call when the scenario ends.
  CognitionAnalyticsReport generateReport(Duration finalElapsed) {
    // Close any open fixation
    if (_currentFixationId != null) {
      _fixationPeriods.add(FixationPeriod(
        fixatedObjectId: _currentFixationId!,
        start: _currentFixationStart!,
        end: finalElapsed,
        ignoredAlertDuration: Duration.zero,
        detectionLatencySeconds: _currentFixationMaxLatency,
      ));
    }

    final overloadPeriods = _timeline.overloadPeriods;
    final totalOverload = _timeline.totalOverloadDuration;

    // Saturation duration
    var satDuration = Duration.zero;
    for (final frame in _timeline.frames) {
      // Approximate: count frames where score ≥ 8.0
      if (frame.workloadScore >= 8.0) {
        // Each frame ≈ 1 simulation second (engine ticks at 1Hz default)
        satDuration += const Duration(seconds: 1);
      }
    }

    final bursts = _detectCommandBursts();
    final ignored = _findIgnoredAlerts(finalElapsed);
    final longestIgnored = ignored.isEmpty
        ? null
        : ignored.reduce(
            (a, b) => a.ignoredFor > b.ignoredFor ? a : b,
          );

    final collapse = _analyseCollapse(
      overloadPeriods: overloadPeriods,
      bursts: bursts,
      ignored: ignored,
      fixations: _fixationPeriods,
    );

    final score = _computeCognitionScore(
      totalOverload: totalOverload,
      bursts: bursts,
      ignored: ignored,
      fixations: _fixationPeriods,
    );

    return CognitionAnalyticsReport(
      peakOverloadMoment: _timeline.peakWorkloadFrame,
      totalOverloadDuration: totalOverload,
      totalSaturationDuration: satDuration,
      commandBursts: bursts,
      ignoredCriticalAlerts: ignored,
      longestUnresolvedAlert: longestIgnored,
      fixationPeriods: List.unmodifiable(_fixationPeriods),
      collapseReason: collapse,
      cognitionScore: score,
    );
  }

  /// Resets all accumulated data (call on scenario restart).
  void reset() {
    _timeline.reset();
    _commands.clear();
    _alertLifecycles.clear();
    _fixationPeriods.clear();
    _currentFixationId = null;
    _currentFixationStart = null;
    _currentFixationMaxLatency = 0;
  }

  // ── Private analysis helpers ──────────────────────────────────────────────

  static const int _burstCommandThreshold = 4;
  static const Duration _burstWindow = Duration(seconds: 15);

  List<CommandBurstWindow> _detectCommandBursts() {
    final bursts = <CommandBurstWindow>[];
    if (_commands.length < _burstCommandThreshold) return bursts;

    for (var i = 0; i < _commands.length; i++) {
      final windowStart = _commands[i].elapsed;
      var count = 1;
      for (var j = i + 1; j < _commands.length; j++) {
        if (_commands[j].elapsed - windowStart <= _burstWindow) {
          count++;
        } else {
          break;
        }
      }
      if (count >= _burstCommandThreshold) {
        final windowEnd = _commands[i + count - 1].elapsed;
        // Find peak workload in this window
        double peak = 0;
        for (final frame in _timeline.frames) {
          if (frame.elapsed >= windowStart && frame.elapsed <= windowEnd) {
            peak = math.max(peak, frame.workloadScore);
          }
        }
        bursts.add(CommandBurstWindow(
          start: windowStart,
          end: windowEnd,
          commandCount: count,
          peakWorkloadScore: peak,
        ));
        // Skip past this burst
        i += count - 1;
      }
    }
    return bursts;
  }

  List<IgnoredAlertRecord> _findIgnoredAlerts(Duration finalElapsed) {
    final ignored = <IgnoredAlertRecord>[];
    for (final lc in _alertLifecycles.values) {
      if (lc.priority == AlertPriority.low) continue;
      if (!lc.responded) {
        final end = lc.resolvedAt ?? finalElapsed;
        ignored.add(IgnoredAlertRecord(
          alertId: lc.id,
          alertType: lc.type,
          priority: lc.priority,
          firedAt: lc.firedAt,
          expiredAt: lc.resolvedAt,
          ignoredFor: end - lc.firedAt,
        ));
      }
    }
    return ignored;
  }

  WorkloadCollapseReason? _analyseCollapse({
    required List<({Duration start, Duration end})> overloadPeriods,
    required List<CommandBurstWindow> bursts,
    required List<IgnoredAlertRecord> ignored,
    required List<FixationPeriod> fixations,
  }) {
    if (overloadPeriods.isEmpty) return null;

    final factors = <String>[];
    Duration? collapseAt;

    final longestOverload = overloadPeriods.isEmpty
        ? null
        : overloadPeriods
            .reduce((a, b) => (a.end - a.start) > (b.end - b.start) ? a : b);

    if (longestOverload != null &&
        (longestOverload.end - longestOverload.start).inSeconds >= 20) {
      collapseAt ??= longestOverload.start;
      factors.add(
        'Sustained overload for ${(longestOverload.end - longestOverload.start).inSeconds}s',
      );
    }

    final criticalIgnored =
        ignored.where((i) => i.priority == AlertPriority.critical).toList();
    if (criticalIgnored.isNotEmpty) {
      collapseAt ??= criticalIgnored.first.firedAt;
      factors.add(
        '${criticalIgnored.length} critical alert${criticalIgnored.length > 1 ? 's' : ''} ignored',
      );
    }

    if (bursts.length >= 2) {
      factors.add(
        '${bursts.length} command burst windows (reactive intervention)',
      );
    }

    final longFixation = fixations.isEmpty
        ? null
        : fixations.reduce(
            (a, b) => a.duration > b.duration ? a : b,
          );
    if (longFixation != null && longFixation.duration.inSeconds >= 30) {
      collapseAt ??= longFixation.start;
      factors.add(
        'Tunnel vision on ${longFixation.fixatedObjectId} for ${longFixation.duration.inSeconds}s',
      );
    }

    if (factors.isEmpty) return null;

    final headline = collapseAt != null
        ? 'Workload became unmanageable at ${_fmt(collapseAt)}'
        : 'Workload instability detected';

    return WorkloadCollapseReason(
      headline: headline,
      contributingFactors: factors,
      collapsedAt: collapseAt,
    );
  }

  int _computeCognitionScore({
    required Duration totalOverload,
    required List<CommandBurstWindow> bursts,
    required List<IgnoredAlertRecord> ignored,
    required List<FixationPeriod> fixations,
  }) {
    var score = 100;
    // Penalise overload duration: -2 per 10 s
    score -= (totalOverload.inSeconds ~/ 10) * 2;
    // Penalise each command burst: -5
    score -= bursts.length * 5;
    // Penalise ignored critical alerts: -8 each
    final critIgnored = ignored.where((i) =>
        i.priority == AlertPriority.critical ||
        i.priority == AlertPriority.high);
    score -= critIgnored.length * 8;
    // Penalise long fixations: -3 per fixation >30 s
    for (final f in fixations) {
      if (f.duration.inSeconds >= 30) score -= 3;
    }
    return score.clamp(0, 100);
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _AlertLifecycle {
  final String id;
  final String type;
  final AlertPriority priority;
  final Duration firedAt;
  final List<String> relatedAircraftIds;
  bool responded = false;
  Duration? respondedAt;
  Duration? resolvedAt;

  _AlertLifecycle({
    required this.id,
    required this.type,
    required this.priority,
    required this.firedAt,
    required this.relatedAircraftIds,
  });
}
