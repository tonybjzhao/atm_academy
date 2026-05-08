import '../alerts/operational_alert.dart';
import '../cognitive_load/cognitive_load_level.dart';

/// A single time-stamped snapshot of workload state captured during a scenario.
/// Frames are collected every tick and stored in [ReplayWorkloadTimeline].
class ReplayWorkloadFrame {
  const ReplayWorkloadFrame({
    required this.elapsed,
    required this.workloadScore,
    required this.loadLevel,
    required this.activeAlerts,
    required this.activeStressors,
  });

  final Duration elapsed;
  final double workloadScore;
  final CognitiveLoadLevel loadLevel;
  final List<OperationalAlert> activeAlerts;
  final List<String> activeStressors;

  bool get wasOverloaded =>
      loadLevel == CognitiveLoadLevel.overloaded ||
      loadLevel == CognitiveLoadLevel.saturated;
}

/// Ordered sequence of [ReplayWorkloadFrame] for a completed (or in-progress)
/// scenario run.  Query methods let the replay system surface peak-stress
/// moments and overload periods.
class ReplayWorkloadTimeline {
  ReplayWorkloadTimeline() : _frames = [];

  final List<ReplayWorkloadFrame> _frames;

  List<ReplayWorkloadFrame> get frames => List.unmodifiable(_frames);
  int get length => _frames.length;
  bool get isEmpty => _frames.isEmpty;

  /// Appends a frame. Frames must be added in monotonically increasing
  /// [elapsed] order — typically once per simulation tick.
  void addFrame(ReplayWorkloadFrame frame) {
    _frames.add(frame);
  }

  /// Clears all frames (e.g. on scenario restart).
  void reset() => _frames.clear();

  /// The frame with the highest [workloadScore], or `null` if empty.
  ReplayWorkloadFrame? get peakWorkloadFrame {
    if (_frames.isEmpty) return null;
    return _frames.reduce(
      (a, b) => a.workloadScore >= b.workloadScore ? a : b,
    );
  }

  /// Returns contiguous overload periods as `(start, end)` Duration pairs.
  List<({Duration start, Duration end})> get overloadPeriods {
    final periods = <({Duration start, Duration end})>[];
    Duration? start;
    for (final frame in _frames) {
      if (frame.wasOverloaded) {
        start ??= frame.elapsed;
      } else if (start != null) {
        periods.add((start: start, end: frame.elapsed));
        start = null;
      }
    }
    if (start != null && _frames.isNotEmpty) {
      periods.add((start: start, end: _frames.last.elapsed));
    }
    return periods;
  }

  /// Total time spent in an overloaded or saturated state.
  Duration get totalOverloadDuration {
    return overloadPeriods.fold(
      Duration.zero,
      (sum, p) => sum + (p.end - p.start),
    );
  }

  /// Average workload score across all frames, or 0.0 if empty.
  double get averageWorkloadScore {
    if (_frames.isEmpty) return 0;
    return _frames.fold(0.0, (sum, f) => sum + f.workloadScore) / _frames.length;
  }
}
