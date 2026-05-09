import '../models/simulation_event.dart';
import '../models/simulation_snapshot.dart';
import '../scoring/radar_v2_score.dart';

enum EnvironmentalPressureSource {
  arrivalWave,
  departureCompression,
  runwayTransition,
  weatherReroute,
  handoffBurst,
  spacingInstability,
  attentionTrap,
  latentConflict,
  recoveryDestabilization,
  synchronizedStressors,
}

enum SectorTempoPhase {
  calm,
  deceptiveCalm,
  compression,
  overload,
  unstableRecovery,
}

class EnvironmentalPressureWindow {
  final EnvironmentalPressureSource source;
  final SectorTempoPhase phase;
  final Duration start;
  final Duration end;
  final double intensity;
  final String label;
  final String explanation;

  const EnvironmentalPressureWindow({
    required this.source,
    required this.phase,
    required this.start,
    required this.end,
    required this.intensity,
    required this.label,
    required this.explanation,
  });
}

class EnvironmentalPressureEcology {
  final SectorTempoPhase currentTempo;
  final List<EnvironmentalPressureWindow> windows;
  final List<String> reportLines;
  final double synchronizedRisk;

  const EnvironmentalPressureEcology({
    required this.currentTempo,
    required this.windows,
    required this.reportLines,
    required this.synchronizedRisk,
  });

  static const empty = EnvironmentalPressureEcology(
    currentTempo: SectorTempoPhase.calm,
    windows: [],
    reportLines: [],
    synchronizedRisk: 0,
  );
}

class EnvironmentalPressureEcologyBuilder {
  const EnvironmentalPressureEcologyBuilder();

  EnvironmentalPressureEcology build({
    required SimulationSnapshot snapshot,
    required RadarV2ScoreSnapshot score,
  }) {
    final duration = _durationFor(snapshot);
    final windows = <EnvironmentalPressureWindow>[
      ..._trafficRhythmWindows(snapshot, duration),
      ..._attentionTrapWindows(snapshot, duration),
      ..._latentConflictWindows(snapshot, duration),
      ..._recoveryDestabilizationWindows(snapshot, duration),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final synchronized = _synchronizedRisk(windows);
    if (synchronized >= 0.48) {
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.synchronizedStressors,
        phase: synchronized >= 0.74
            ? SectorTempoPhase.overload
            : SectorTempoPhase.compression,
        start: _syncStart(windows, duration),
        end: duration,
        intensity: synchronized,
        label: 'Synchronized pressure window',
        explanation:
            'Multiple weak operational stressors aligned into a high-risk window.',
      ));
    }

    final tempo = _tempoFor(snapshot, score, windows, synchronized);
    return EnvironmentalPressureEcology(
      currentTempo: tempo,
      windows: List.unmodifiable(windows),
      reportLines: List.unmodifiable(
        _reportLines(windows, tempo, synchronized),
      ),
      synchronizedRisk: synchronized,
    );
  }

  List<EnvironmentalPressureWindow> _trafficRhythmWindows(
    SimulationSnapshot snapshot,
    Duration duration,
  ) {
    final windows = <EnvironmentalPressureWindow>[];
    final arrivals = snapshot.events
        .where((event) => event.type == 'sectorEntry')
        .toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    final departures = snapshot.events
        .where((event) =>
            event.type == 'departureQueued' ||
            event.type == 'departureReleased')
        .toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    if (arrivals.length >= 3 || snapshot.arrivalFlows.isNotEmpty) {
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.arrivalWave,
        phase: SectorTempoPhase.compression,
        start: arrivals.isEmpty ? Duration.zero : arrivals.first.elapsed,
        end: arrivals.length >= 2
            ? arrivals.last.elapsed + const Duration(seconds: 35)
            : duration,
        intensity: (arrivals.length / 5 + snapshot.arrivalFlows.length * 0.12)
            .clamp(0.42, 1)
            .toDouble(),
        label: 'Arrival wave',
        explanation:
            'Arrival traffic arrived in a wave, increasing sequencing and spacing pressure.',
      ));
    }
    if (departures.length >= 2 || snapshot.departureFlows.isNotEmpty) {
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.departureCompression,
        phase: SectorTempoPhase.compression,
        start: departures.isEmpty ? Duration.zero : departures.first.elapsed,
        end: departures.length >= 2
            ? departures.last.elapsed + const Duration(seconds: 30)
            : duration,
        intensity:
            (departures.length / 4 + snapshot.departureFlows.length * 0.15)
                .clamp(0.36, 1)
                .toDouble(),
        label: 'Departure compression',
        explanation:
            'Departure releases or queues compressed radio and runway workload.',
      ));
    }
    if (snapshot.runwayStates
        .any((state) => state.isOccupiedAt(snapshot.elapsed))) {
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.runwayTransition,
        phase: SectorTempoPhase.compression,
        start: _nearEnd(duration, 45),
        end: duration,
        intensity: 0.62,
        label: 'Runway backlog formation',
        explanation:
            'Runway occupancy reduced available spacing margin and increased sequencing pressure.',
      ));
    }
    if (snapshot.weatherZones.isNotEmpty) {
      final severity = snapshot.weatherZones
          .fold<int>(0, (sum, zone) => sum + zone.severity);
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.weatherReroute,
        phase: severity >= 3
            ? SectorTempoPhase.compression
            : SectorTempoPhase.deceptiveCalm,
        start: Duration.zero,
        end: duration,
        intensity: (severity / 5).clamp(0.34, 1).toDouble(),
        label: 'Weather reroute pressure',
        explanation:
            'Weather constraints narrowed available vectors and made stable spacing less reliable.',
      ));
    }
    if (_handoffEvents(snapshot).length >= 2) {
      final handoffs = _handoffEvents(snapshot);
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.handoffBurst,
        phase: SectorTempoPhase.compression,
        start: handoffs.first.elapsed,
        end: handoffs.last.elapsed + const Duration(seconds: 25),
        intensity: (handoffs.length / 4).clamp(0.4, 1).toDouble(),
        label: 'Sector handoff burst',
        explanation:
            'Sector entries and exits clustered, increasing coordination and scan load.',
      ));
    }
    if (snapshot.separation.any((result) => result.isPredictedConflict) ||
        snapshot.events
            .any((event) => _containsAny(event, ['spacing', 'merge']))) {
      windows.add(EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.spacingInstability,
        phase: SectorTempoPhase.compression,
        start: _firstEventTime(snapshot, ['spacing', 'merge', 'conflict']) ??
            _nearEnd(duration, 55),
        end: duration,
        intensity: 0.68,
        label: 'Spacing instability',
        explanation:
            'Merge or spacing cues indicated the arrival flow was becoming less stable.',
      ));
    }
    return windows;
  }

  List<EnvironmentalPressureWindow> _attentionTrapWindows(
    SimulationSnapshot snapshot,
    Duration duration,
  ) {
    final focus = snapshot.attentionFocus;
    if (focus.fixationWindowCount == 0 &&
        focus.currentFocusTarget == null &&
        focus.ignoredAlerts.isEmpty) {
      return const [];
    }
    return [
      EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.attentionTrap,
        phase: SectorTempoPhase.deceptiveCalm,
        start: _nearEnd(duration, 65),
        end: duration,
        intensity: (focus.ignoredAlerts.length * 0.18 +
                focus.fixationWindowCount * 0.24 +
                (1 - focus.scanCoverageQuality))
            .clamp(0.42, 1)
            .toDouble(),
        label: 'Attention trap',
        explanation:
            'One problem was salient enough to pull focus while surrounding traffic could destabilize quietly.',
      ),
    ];
  }

  List<EnvironmentalPressureWindow> _latentConflictWindows(
    SimulationSnapshot snapshot,
    Duration duration,
  ) {
    final conflictEvents = snapshot.events.where((event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('conflict') ||
          lower.contains('separation') ||
          lower.contains('mismatch') ||
          lower.contains('abnormal');
    }).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    final subtle = snapshot.predictiveMentalModelState.activeMismatches.length +
        snapshot.predictiveMentalModelState.lateRecognitionCount +
        snapshot.predictiveMentalModelState.surpriseOverloadMoments;
    if (conflictEvents.isEmpty && subtle == 0) return const [];
    final first = conflictEvents.isEmpty
        ? _nearEnd(duration, 50)
        : conflictEvents.first.elapsed - const Duration(seconds: 18);
    return [
      EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.latentConflict,
        phase: SectorTempoPhase.deceptiveCalm,
        start: first < Duration.zero ? Duration.zero : first,
        end: conflictEvents.isEmpty
            ? duration
            : conflictEvents.last.elapsed + const Duration(seconds: 25),
        intensity:
            ((conflictEvents.length + subtle) / 5).clamp(0.4, 1).toDouble(),
        label: 'Latent conflict ecology',
        explanation:
            'Low-salience or ambiguous conflict cues developed before they became obvious alerts.',
      ),
    ];
  }

  List<EnvironmentalPressureWindow> _recoveryDestabilizationWindows(
    SimulationSnapshot snapshot,
    Duration duration,
  ) {
    final recoveryEvents = snapshot.events.where((event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('recovery') ||
          lower.contains('stabil') ||
          lower.contains('command');
    }).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    if (recoveryEvents.isEmpty &&
        snapshot.metaCognitionState.successfulSelfRecoveryCount == 0 &&
        snapshot.workingMemoryState.pendingIntentions.isEmpty) {
      return const [];
    }
    final start = recoveryEvents.isEmpty
        ? _nearEnd(duration, 38)
        : recoveryEvents.first.elapsed;
    return [
      EnvironmentalPressureWindow(
        source: EnvironmentalPressureSource.recoveryDestabilization,
        phase: SectorTempoPhase.unstableRecovery,
        start: start,
        end: duration,
        intensity: (snapshot.workingMemoryState.pendingIntentions.length *
                    0.12 +
                snapshot.workingMemoryState.interruptedWorkflowCount * 0.18 +
                0.42)
            .clamp(0.36, 1)
            .toDouble(),
        label: 'Recovery destabilization',
        explanation:
            'Recovery actions likely increased vector complexity, radio load, or pending memory tasks elsewhere.',
      ),
    ];
  }

  List<String> _reportLines(
    List<EnvironmentalPressureWindow> windows,
    SectorTempoPhase tempo,
    double synchronizedRisk,
  ) {
    if (windows.isEmpty) {
      return const ['Operational pressure stayed low and evenly distributed.'];
    }
    final top = [...windows]
      ..sort((a, b) => b.intensity.compareTo(a.intensity));
    final lines = <String>[];
    final topSources = top.take(3).map((window) => window.label).join(', ');
    lines.add(
      'Operational tempo: ${_tempoLabel(tempo)}; strongest pressure sources: $topSources.',
    );
    if (synchronizedRisk >= 0.48) {
      lines.add(
        'Multiple weak stressors synchronized into a higher-risk pressure window.',
      );
    }
    final weatherAndRunway = windows.any(
          (w) => w.source == EnvironmentalPressureSource.weatherReroute,
        ) &&
        windows.any(
          (w) => w.source == EnvironmentalPressureSource.runwayTransition,
        );
    final arrivalsAndWeather = windows.any(
          (w) => w.source == EnvironmentalPressureSource.arrivalWave,
        ) &&
        windows.any(
          (w) => w.source == EnvironmentalPressureSource.weatherReroute,
        );
    if (arrivalsAndWeather || weatherAndRunway) {
      lines.add(
        'Arrival compression and weather deviations aligned during runway or merge pressure formation.',
      );
    }
    final attentionTrap = windows.any(
      (w) => w.source == EnvironmentalPressureSource.attentionTrap,
    );
    if (attentionTrap) {
      lines.add(
        'A salient aircraft/problem created an attention trap while lower-salience threats developed nearby.',
      );
    }
    return lines.take(4).toList(growable: false);
  }

  SectorTempoPhase _tempoFor(
    SimulationSnapshot snapshot,
    RadarV2ScoreSnapshot score,
    List<EnvironmentalPressureWindow> windows,
    double synchronizedRisk,
  ) {
    if (score.totalOverloadDuration > Duration.zero ||
        snapshot.cognitiveLoad.totalLoadScore >= 7.5 ||
        synchronizedRisk >= 0.74) {
      return SectorTempoPhase.overload;
    }
    if (windows.any((w) => w.phase == SectorTempoPhase.unstableRecovery)) {
      return SectorTempoPhase.unstableRecovery;
    }
    if (windows.any((w) => w.phase == SectorTempoPhase.compression)) {
      return SectorTempoPhase.compression;
    }
    if (windows.any((w) => w.phase == SectorTempoPhase.deceptiveCalm)) {
      return SectorTempoPhase.deceptiveCalm;
    }
    return SectorTempoPhase.calm;
  }

  double _synchronizedRisk(List<EnvironmentalPressureWindow> windows) {
    if (windows.length < 2) return 0;
    var strongest = 0.0;
    for (var i = 0; i < windows.length; i++) {
      var combined = windows[i].intensity;
      for (var j = 0; j < windows.length; j++) {
        if (i == j) continue;
        if (_overlaps(windows[i], windows[j])) {
          combined += windows[j].intensity * 0.42;
        }
      }
      if (combined > strongest) strongest = combined;
    }
    return (strongest / 2.2).clamp(0, 1).toDouble();
  }

  bool _overlaps(
    EnvironmentalPressureWindow a,
    EnvironmentalPressureWindow b,
  ) {
    return a.start < b.end && b.start < a.end;
  }

  Duration _syncStart(
    List<EnvironmentalPressureWindow> windows,
    Duration fallback,
  ) {
    if (windows.isEmpty) return fallback;
    final sorted = [...windows]
      ..sort((a, b) => b.intensity.compareTo(a.intensity));
    return sorted.first.start;
  }

  Duration _durationFor(SimulationSnapshot snapshot) {
    final seconds = <int>[
      snapshot.elapsed.inSeconds,
      for (final event in snapshot.events) event.elapsed.inSeconds,
    ];
    final maxSeconds = seconds.isEmpty
        ? 120
        : seconds.reduce((a, b) => a > b ? a : b).clamp(90, 1200);
    return Duration(seconds: maxSeconds);
  }

  Duration _nearEnd(Duration duration, int secondsBeforeEnd) {
    final value = duration - Duration(seconds: secondsBeforeEnd);
    return value < Duration.zero ? Duration.zero : value;
  }

  List<SimulationEvent> _handoffEvents(SimulationSnapshot snapshot) {
    return snapshot.events.where((event) {
      final lower = '${event.type} ${event.label}'.toLowerCase();
      return lower.contains('handoff') ||
          lower.contains('sector') ||
          lower.contains('exit');
    }).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
  }

  Duration? _firstEventTime(
    SimulationSnapshot snapshot,
    List<String> needles,
  ) {
    final events = snapshot.events.where((event) {
      return needles.any((needle) => _containsAny(event, [needle]));
    }).toList()
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    return events.isEmpty ? null : events.first.elapsed;
  }

  bool _containsAny(SimulationEvent event, List<String> needles) {
    final lower = '${event.type} ${event.label}'.toLowerCase();
    return needles.any(lower.contains);
  }

  String _tempoLabel(SectorTempoPhase phase) {
    return switch (phase) {
      SectorTempoPhase.calm => 'calm',
      SectorTempoPhase.deceptiveCalm => 'deceptive calm',
      SectorTempoPhase.compression => 'compression',
      SectorTempoPhase.overload => 'overload',
      SectorTempoPhase.unstableRecovery => 'unstable recovery',
    };
  }
}
