import 'dart:math' as math;

/// Tracks controller focus patterns to detect tunnel-vision fixation.
///
/// When a controller repeatedly interacts with the same aircraft, runway,
/// or conflict cluster, detection latency for unrelated events increases.
///
/// This engine is stateful — call [recordInteraction] when the controller
/// issues a command, and [tick] each simulation step.
class TunnelVisionEngine {
  static const int _fixationThreshold = 4; // interactions to enter fixation
  static const Duration _fixationWindow = Duration(seconds: 45);
  static const Duration _fixationDecayTime = Duration(seconds: 20);

  final Map<String, _FocusRecord> _aircraftFocus = {};
  final Map<String, _FocusRecord> _runwayFocus = {};
  final Map<String, _FocusRecord> _clusterFocus = {};

  TunnelVisionState _lastState = TunnelVisionState.none;

  TunnelVisionState get lastState => _lastState;

  /// Records a controller interaction. Call when a command is issued.
  ///
  /// [aircraftId] — the aircraft targeted.
  /// [runwayId]   — optional runway associated with the command.
  /// [clusterId]  — optional cluster (e.g. conflict pair key like "AAA/BBB").
  /// [elapsed]    — current simulation time.
  void recordInteraction({
    required String aircraftId,
    String? runwayId,
    String? clusterId,
    required Duration elapsed,
  }) {
    _record(_aircraftFocus, aircraftId, elapsed);
    if (runwayId != null) _record(_runwayFocus, runwayId, elapsed);
    if (clusterId != null) _record(_clusterFocus, clusterId, elapsed);
  }

  /// Advances time — decays stale focus records and recomputes state.
  TunnelVisionState tick(Duration elapsed) {
    _decay(_aircraftFocus, elapsed);
    _decay(_runwayFocus, elapsed);
    _decay(_clusterFocus, elapsed);
    _lastState = _computeState(elapsed);
    return _lastState;
  }

  /// Resets all focus tracking (call on scenario restart).
  void reset() {
    _aircraftFocus.clear();
    _runwayFocus.clear();
    _clusterFocus.clear();
    _lastState = TunnelVisionState.none;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  void _record(
    Map<String, _FocusRecord> map,
    String key,
    Duration elapsed,
  ) {
    final existing = map[key];
    if (existing == null) {
      map[key] = _FocusRecord(
        firstAt: elapsed,
        lastAt: elapsed,
        count: 1,
      );
    } else {
      map[key] = _FocusRecord(
        firstAt: existing.firstAt,
        lastAt: elapsed,
        count: existing.count + 1,
      );
    }
  }

  void _decay(Map<String, _FocusRecord> map, Duration elapsed) {
    map.removeWhere((_, r) {
      final age = elapsed - r.lastAt;
      return age >= _fixationDecayTime;
    });
  }

  TunnelVisionState _computeState(Duration elapsed) {
    final aircraft = _strongestFocus(_aircraftFocus, elapsed);
    final runway = _strongestFocus(_runwayFocus, elapsed);
    final cluster = _strongestFocus(_clusterFocus, elapsed);

    String? fixatedOn;
    Duration? duration;
    double? detectionLatency;

    if (aircraft != null && aircraft.count >= _fixationThreshold) {
      fixatedOn = aircraft.key;
      duration = elapsed - aircraft.firstAt;
    } else if (runway != null && runway.count >= _fixationThreshold) {
      fixatedOn = runway.key;
      duration = elapsed - runway.firstAt;
    } else if (cluster != null && cluster.count >= _fixationThreshold) {
      fixatedOn = cluster.key;
      duration = elapsed - cluster.firstAt;
    }

    if (fixatedOn == null) return TunnelVisionState.none;

    // Detection latency increases with fixation depth and duration
    final durationSec = duration!.inSeconds.toDouble();
    // Up to 6 s added latency at deep fixation (asymptotic)
    detectionLatency = 6.0 * (1.0 - math.exp(-durationSec / 30.0));

    // Ignored-alert duration: alerts outside fixation scope that persisted
    final ignoredAlertDuration = Duration(
      seconds: math.min(durationSec.toInt(), 90),
    );

    return TunnelVisionState(
      isActive: true,
      fixatedObjectId: fixatedOn,
      fixationDuration: duration,
      detectionLatencySeconds: detectionLatency,
      ignoredAlertDuration: ignoredAlertDuration,
    );
  }

  ({String key, int count, Duration firstAt})? _strongestFocus(
    Map<String, _FocusRecord> map,
    Duration elapsed,
  ) {
    if (map.isEmpty) return null;
    _FocusRecord? best;
    String? bestKey;
    for (final entry in map.entries) {
      final r = entry.value;
      if (elapsed - r.lastAt < _fixationWindow) {
        if (best == null || r.count > best.count) {
          best = r;
          bestKey = entry.key;
        }
      }
    }
    if (bestKey == null) return null;
    return (key: bestKey, count: best!.count, firstAt: best.firstAt);
  }
}

/// Immutable snapshot of current tunnel-vision state.
class TunnelVisionState {
  final bool isActive;

  /// ID of the aircraft / runway / cluster being fixated on, or null.
  final String? fixatedObjectId;

  /// How long the fixation has been active (null if not fixated).
  final Duration? fixationDuration;

  /// Additional detection latency (seconds) for non-fixated events.
  final double detectionLatencySeconds;

  /// Total duration of likely-ignored alerts outside the fixation scope.
  final Duration ignoredAlertDuration;

  const TunnelVisionState({
    required this.isActive,
    this.fixatedObjectId,
    this.fixationDuration,
    this.detectionLatencySeconds = 0,
    this.ignoredAlertDuration = Duration.zero,
  });

  static const TunnelVisionState none = TunnelVisionState(isActive: false);
}

class _FocusRecord {
  final Duration firstAt;
  final Duration lastAt;
  final int count;

  const _FocusRecord({
    required this.firstAt,
    required this.lastAt,
    required this.count,
  });
}
