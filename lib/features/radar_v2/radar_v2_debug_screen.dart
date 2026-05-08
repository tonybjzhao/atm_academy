import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'commands/controller_command.dart';
import 'models/aircraft_state.dart';
import 'models/simulation_event.dart';
import 'models/simulation_snapshot.dart';
import 'rendering/radar_v2_painter.dart';
import 'scenario/scenario_asset_loader.dart';
import 'scenario/scenario_runtime.dart';
import 'scoring/radar_v2_score.dart';

class RadarV2DebugScreen extends StatefulWidget {
  const RadarV2DebugScreen({super.key});

  @override
  State<RadarV2DebugScreen> createState() => _RadarV2DebugScreenState();
}

class _RadarV2DebugScreenState extends State<RadarV2DebugScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _scenarioAssets = {
    'Crossing Arrivals': 'assets/scenarios/v2/melbourne/crossing_arrivals.json',
    'Overtaking Traffic':
        'assets/scenarios/v2/melbourne/overtaking_traffic.json',
  };

  ScenarioRuntime? _runtime;
  SimulationSnapshot? _previousSnapshot;
  SimulationSnapshot? _snapshot;
  final List<SimulationSnapshot> _replayHistory = <SimulationSnapshot>[];
  RadarV2ScoreTracker _scoreTracker = RadarV2ScoreTracker();
  Ticker? _ticker;
  Duration? _lastFrameTime;
  double _simulationAccumulatorSeconds = 0;
  double _renderInterpolation = 0;
  double _sweepAngleRad = 0;
  int _speed = 1;
  bool _paused = false;
  bool _alertPulse = false;
  bool _sweepEnabled = true;
  bool _reviewingReplay = false;
  bool _scenarioStarted = false;
  bool _resultShown = false;
  int _replayCursor = 0;
  String _scenarioName = 'Crossing Arrivals';
  String? _selectedAircraftId;
  String? _commandFilterAircraftId;
  String _commandFilterType = 'all';
  String? _reviewEventLabel;
  String? _recentlyCommandedAircraftId;
  Timer? _commandHighlightTimer;
  DateTime _lastAudioCue = DateTime.fromMillisecondsSinceEpoch(0);
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    assert(() {
      _loadScenario(_scenarioName);
      _ticker = createTicker(_onFrame)..start();
      return true;
    }());
  }

  Future<void> _loadScenario(String scenarioName) async {
    try {
      final assetPath = _scenarioAssets[scenarioName]!;
      final definition = await const ScenarioAssetLoader().load(assetPath);
      if (!mounted) return;
      _runtime = ScenarioRuntime(definition: definition);
      _scoreTracker = RadarV2ScoreTracker();
      _scenarioName = scenarioName;
      _selectedAircraftId = null;
      _commandFilterAircraftId = null;
      _commandFilterType = 'all';
      _reviewEventLabel = null;
      _recentlyCommandedAircraftId = null;
      _previousSnapshot = null;
      _snapshot = _runtime!.snapshot;
      _replayHistory
        ..clear()
        ..add(_snapshot!);
      _replayCursor = 0;
      _reviewingReplay = false;
      _simulationAccumulatorSeconds = 0;
      _renderInterpolation = 0;
      _scenarioStarted = false;
      _paused = true;
      _resultShown = false;
      setState(() => _loadError = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  void _onFrame(Duration frameTime) {
    final runtime = _runtime;
    if (!mounted || runtime == null) return;
    final lastFrameTime = _lastFrameTime;
    _lastFrameTime = frameTime;
    if (!_scenarioStarted || _paused) {
      setState(() {
        _sweepAngleRad = (_sweepAngleRad + 0.012) % (math.pi * 2);
        _alertPulse = !_alertPulse;
      });
      return;
    }

    final deltaSeconds = lastFrameTime == null
        ? 0.0
        : (frameTime - lastFrameTime).inMicroseconds /
            Duration.microsecondsPerSecond;
    _simulationAccumulatorSeconds += deltaSeconds * _speed;

    var advanced = false;
    while (_simulationAccumulatorSeconds >= 1) {
      _advanceSimulationStep();
      _simulationAccumulatorSeconds -= 1;
      advanced = true;
    }

    setState(() {
      _renderInterpolation = _simulationAccumulatorSeconds.clamp(0, 1);
      _sweepAngleRad = (_sweepAngleRad + deltaSeconds * 1.35) % (math.pi * 2);
      if (advanced) _alertPulse = !_alertPulse;
    });
  }

  void _restartScenario() {
    _loadScenario(_scenarioName);
  }

  void _startScenario() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _scenarioStarted = true;
      _paused = false;
      _previousSnapshot = runtime.snapshot;
      _snapshot = runtime.tick();
      _replayHistory
        ..clear()
        ..add(_previousSnapshot!)
        ..add(_snapshot!);
      _replayCursor = _replayHistory.length - 1;
      _scoreTracker.observe(_snapshot!);
      _simulationAccumulatorSeconds = 0;
      _renderInterpolation = 0;
    });
  }

  void _stepScenario() {
    if (!_scenarioStarted) {
      _startScenario();
      setState(() => _paused = true);
      return;
    }
    _advanceSimulationStep();
    setState(() {
      _paused = true;
      _renderInterpolation = 1;
    });
  }

  void _advanceSimulationStep() {
    final runtime = _runtime;
    final snapshot = _snapshot;
    if (runtime == null || snapshot == null) return;
    _previousSnapshot = snapshot;
    _snapshot = runtime.tick();
    _reviewingReplay = false;
    _recordReplaySnapshot(_snapshot!);
    _scoreTracker.observe(_snapshot!);
    _playConflictCue(_snapshot!);
    final scenarioState = runtime.evaluate();
    if (scenarioState.complete && !_resultShown) {
      _paused = true;
      _resultShown = true;
    }
  }

  void _selectAircraft(TapUpDetails details, Size size) {
    final snapshot = _snapshot;
    final runtime = _runtime;
    if (snapshot == null || runtime == null) return;
    final selected = _nearestAircraft(
      snapshot,
      details.localPosition,
      size,
      runtime.definition.radarRangeNm,
    );
    setState(() => _selectedAircraftId = selected?.id);
  }

  AircraftState? _nearestAircraft(
    SimulationSnapshot snapshot,
    Offset tap,
    Size size,
    double rangeNm,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;
    final scale = radius / rangeNm;
    AircraftState? closest;
    var closestDistance = 18.0;
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      final position =
          center.translate(aircraft.xNm * scale, -aircraft.yNm * scale);
      final distance = (position - tap).distance;
      if (distance < closestDistance) {
        closest = aircraft;
        closestDistance = distance;
      }
    }
    return closest;
  }

  void _issueCommand(ControllerCommand command, String feedback) {
    final runtime = _runtime;
    final snapshot = _snapshot;
    if (runtime == null || snapshot == null) return;
    runtime.engine.applyCommand(command);
    _scoreTracker.recordCommand(command, snapshot);
    _commandHighlightTimer?.cancel();
    setState(() {
      _snapshot = runtime.snapshot;
      _previousSnapshot = snapshot;
      _renderInterpolation = 1;
      _recentlyCommandedAircraftId = command.aircraftId;
    });
    _commandHighlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _recentlyCommandedAircraftId = null);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(feedback),
          duration: const Duration(milliseconds: 1300),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _commandHeading(AircraftState aircraft, int deltaDeg) {
    final heading = _normalizeHeading(aircraft.headingDeg + deltaDeg);
    final turn = deltaDeg < 0 ? 'LEFT' : 'RIGHT';
    _issueCommand(
      AssignHeading(
        aircraftId: aircraft.id,
        issuedAt: _snapshot?.elapsed ?? Duration.zero,
        headingDeg: heading,
      ),
      '${aircraft.callsign} TURN $turn HEADING ${heading.round().toString().padLeft(3, '0')}',
    );
  }

  void _commandAltitude(AircraftState aircraft, int deltaFt) {
    final altitude = (aircraft.altitudeFt + deltaFt).clamp(2000, 45000);
    final verb = deltaFt > 0 ? 'CLIMB' : 'DESCEND';
    _issueCommand(
      AssignAltitude(
        aircraftId: aircraft.id,
        issuedAt: _snapshot?.elapsed ?? Duration.zero,
        altitudeFt: altitude,
      ),
      '${aircraft.callsign} $verb ${altitude ~/ 100}',
    );
  }

  void _commandSpeed(AircraftState aircraft, int deltaKt) {
    final speed = (aircraft.groundSpeedKt + deltaKt).clamp(120, 480).toDouble();
    final verb = deltaKt > 0 ? 'INCREASE SPEED' : 'REDUCE SPEED';
    _issueCommand(
      AssignSpeed(
        aircraftId: aircraft.id,
        issuedAt: _snapshot?.elapsed ?? Duration.zero,
        speedKt: speed,
      ),
      '${aircraft.callsign} $verb ${speed.round()}',
    );
  }

  void _commandHold(AircraftState aircraft) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.holdPatterns.isEmpty) return;
    final hold = snapshot.holdPatterns.first;
    if (aircraft.intent.hold) {
      _issueCommand(
        ExitHold(
          aircraftId: aircraft.id,
          issuedAt: snapshot.elapsed,
        ),
        '${aircraft.callsign} EXIT HOLD',
      );
      return;
    }
    _issueCommand(
      EnterHold(
        aircraftId: aircraft.id,
        issuedAt: snapshot.elapsed,
        holdPatternId: hold.id,
      ),
      '${aircraft.callsign} HOLD AT ${hold.fixWaypointId}',
    );
  }

  void _recordReplaySnapshot(SimulationSnapshot snapshot) {
    _replayHistory.add(snapshot);
    if (_replayHistory.length > 180) {
      _replayHistory.removeAt(0);
    }
    _replayCursor = _replayHistory.length - 1;
  }

  void _jumpToEvent(SimulationEvent event) {
    if (_replayHistory.isEmpty) return;
    var index = _replayHistory.indexWhere(
      (snapshot) => snapshot.elapsed >= event.elapsed,
    );
    if (index == -1) index = _replayHistory.length - 1;
    setState(() {
      _paused = true;
      _reviewingReplay = true;
      _replayCursor = index;
      _previousSnapshot = index > 0 ? _replayHistory[index - 1] : null;
      _snapshot = _replayHistory[index];
      _reviewEventLabel = '${event.elapsed.inSeconds}s ${event.label}';
      _selectedAircraftId = event.aircraftId ?? _selectedAircraftId;
      _renderInterpolation = 1;
    });
  }

  void _returnToLive() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _reviewingReplay = false;
      _previousSnapshot = _snapshot;
      _snapshot = runtime.snapshot;
      _replayCursor = _replayHistory.length - 1;
      _reviewEventLabel = null;
      _renderInterpolation = 1;
    });
  }

  void _scrubReplay(double value) {
    if (_replayHistory.isEmpty) return;
    final index = value.round().clamp(0, _replayHistory.length - 1);
    setState(() {
      _paused = true;
      _reviewingReplay = true;
      _replayCursor = index;
      _previousSnapshot = index > 0 ? _replayHistory[index - 1] : null;
      _snapshot = _replayHistory[index];
      _reviewEventLabel =
          'Replay ${_snapshot!.elapsed.inSeconds}s tick ${_snapshot!.tick}';
      _renderInterpolation = 1;
    });
  }

  void _stepReplayEvent(int direction) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.events.isEmpty) return;
    final elapsed = snapshot.elapsed;
    if (direction > 0) {
      for (final event in snapshot.events) {
        if (event.elapsed > elapsed) {
          _jumpToEvent(event);
          return;
        }
      }
      return;
    }
    for (final event in snapshot.events.reversed) {
      if (event.elapsed < elapsed) {
        _jumpToEvent(event);
        return;
      }
    }
  }

  void _setCommandFilterAircraftId(String? aircraftId) {
    setState(() => _commandFilterAircraftId = aircraftId);
  }

  void _setCommandFilterType(String type) {
    setState(() => _commandFilterType = type);
  }

  void _jumpToPairedCommandEvent(SimulationEvent event) {
    final pair = _pairedCommandEvent(event);
    if (pair == null) return;
    _jumpToEvent(pair);
  }

  SimulationEvent? _pairedCommandEvent(SimulationEvent event) {
    if (event.type != 'commandIssued' && event.type != 'commandAcknowledged') {
      return null;
    }
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    final token = _commandTypeToken(event.label);
    final fromIssued = event.type == 'commandIssued';
    final matches = snapshot.events.where((candidate) {
      if (candidate.aircraftId != event.aircraftId) return false;
      if (fromIssued && candidate.type != 'commandAcknowledged') return false;
      if (!fromIssued && candidate.type != 'commandIssued') return false;
      final delta = candidate.elapsed - event.elapsed;
      final inWindow = fromIssued
          ? delta >= Duration.zero && delta <= const Duration(seconds: 12)
          : delta <= Duration.zero && delta >= const Duration(seconds: -12);
      if (!inWindow) return false;
      return _commandTypeToken(candidate.label) == token;
    });
    if (matches.isEmpty) return null;
    return fromIssued ? matches.first : matches.last;
  }

  String _commandTypeToken(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('heading')) return 'heading';
    if (normalized.contains('altitude')) return 'altitude';
    if (normalized.contains('speed')) return 'speed';
    if (normalized.contains('direct')) return 'direct';
    if (normalized.contains('exit hold') || normalized.contains(' hold')) {
      return 'hold';
    }
    return 'other';
  }

  double _normalizeHeading(double headingDeg) {
    final normalized = headingDeg % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  void _playConflictCue(SimulationSnapshot snapshot) {
    var level = 0;
    for (final result in snapshot.separation) {
      if (result.isLossOfSeparation) {
        level = 3;
        break;
      }
      if (result.isPredictedConflict &&
          (result.timeToConflict?.inSeconds ?? 999) <= 60) {
        level = math.max(level, 2);
      } else if (result.isPredictedConflict) {
        level = math.max(level, 1);
      }
    }
    if (level == 0) return;
    final now = DateTime.now();
    final cooldownMs = switch (level) {
      3 => 450,
      2 => 800,
      _ => 2200,
    };
    if (now.difference(_lastAudioCue).inMilliseconds < cooldownMs) return;
    _lastAudioCue = now;
    SystemSound.play(
        level == 1 ? SystemSoundType.click : SystemSoundType.alert);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final runtime = _runtime;
    final snapshot = _snapshot;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Radar V2 Debug'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            tooltip: 'Restart scenario',
            icon: const Icon(Icons.restart_alt),
            onPressed: _restartScenario,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF020A10),
              child: _loadError != null
                  ? Center(
                      child: Text(
                        'Scenario failed to load:\n$_loadError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.danger),
                      ),
                    )
                  : snapshot == null || runtime == null
                      ? const Center(child: CircularProgressIndicator())
                      : !_scenarioStarted
                          ? _BriefingView(
                              scenarioName: _scenarioName,
                              runtime: runtime,
                              scenarioNames:
                                  _scenarioAssets.keys.toList(growable: false),
                              onScenarioChanged: (value) {
                                if (value != null) _loadScenario(value);
                              },
                              onStart: _startScenario,
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.biggest;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) =>
                                      _selectAircraft(details, size),
                                  child: CustomPaint(
                                    painter: RadarV2Painter(
                                      snapshot: snapshot,
                                      previousSnapshot: _previousSnapshot,
                                      interpolation: _renderInterpolation,
                                      rangeNm:
                                          _runtime!.definition.radarRangeNm,
                                      selectedAircraftId: _selectedAircraftId,
                                      recentlyCommandedAircraftId:
                                          _recentlyCommandedAircraftId,
                                      alertPulse: _alertPulse,
                                      sweepEnabled: _sweepEnabled,
                                      sweepAngleRad: _sweepAngleRad,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                );
                              },
                            ),
            ),
          ),
          if (snapshot != null)
            _DebugControls(
              snapshot: snapshot,
              replayLength: _replayHistory.length,
              replayCursor: _replayCursor,
              runtime: _runtime!,
              score: _scoreTracker.snapshot,
              paused: _paused,
              speed: _speed,
              sweepEnabled: _sweepEnabled,
              scenarioStarted: _scenarioStarted,
              resultShown: _resultShown,
              reviewingReplay: _reviewingReplay,
              selectedAircraft: _selectedAircraftId == null
                  ? null
                  : snapshot.aircraftById(_selectedAircraftId!),
              scenarioName: _scenarioName,
              scenarioNames: _scenarioAssets.keys.toList(growable: false),
              onPauseChanged: (value) => setState(() => _paused = value),
              onSpeedChanged: (value) => setState(() => _speed = value),
              onSweepChanged: (value) => setState(() => _sweepEnabled = value),
              onStep: _stepScenario,
              onScenarioChanged: (value) {
                if (value != null) _loadScenario(value);
              },
              onRestart: _restartScenario,
              onReturnToLive: _returnToLive,
              onEventSelected: _jumpToEvent,
              commandFilterAircraftId: _commandFilterAircraftId,
              commandFilterType: _commandFilterType,
              onCommandFilterAircraftChanged: _setCommandFilterAircraftId,
              onCommandFilterTypeChanged: _setCommandFilterType,
              onJumpToCommandPair: _jumpToPairedCommandEvent,
              onReplayScrub: _scrubReplay,
              onStepReplayEvent: _stepReplayEvent,
              onHeading: _commandHeading,
              onAltitude: _commandAltitude,
              onSpeed: _commandSpeed,
              onHold: _commandHold,
              reviewEventLabel: _reviewEventLabel,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _commandHighlightTimer?.cancel();
    super.dispose();
  }
}

class _DebugControls extends StatelessWidget {
  final SimulationSnapshot snapshot;
  final int replayLength;
  final int replayCursor;
  final ScenarioRuntime runtime;
  final RadarV2ScoreSnapshot score;
  final bool paused;
  final int speed;
  final bool sweepEnabled;
  final bool scenarioStarted;
  final bool resultShown;
  final bool reviewingReplay;
  final AircraftState? selectedAircraft;
  final String scenarioName;
  final List<String> scenarioNames;
  final ValueChanged<bool> onPauseChanged;
  final ValueChanged<int> onSpeedChanged;
  final ValueChanged<bool> onSweepChanged;
  final VoidCallback onStep;
  final ValueChanged<String?> onScenarioChanged;
  final VoidCallback onRestart;
  final VoidCallback onReturnToLive;
  final ValueChanged<SimulationEvent> onEventSelected;
  final String? commandFilterAircraftId;
  final String commandFilterType;
  final ValueChanged<String?> onCommandFilterAircraftChanged;
  final ValueChanged<String> onCommandFilterTypeChanged;
  final ValueChanged<SimulationEvent> onJumpToCommandPair;
  final ValueChanged<double> onReplayScrub;
  final ValueChanged<int> onStepReplayEvent;
  final void Function(AircraftState aircraft, int deltaDeg) onHeading;
  final void Function(AircraftState aircraft, int deltaFt) onAltitude;
  final void Function(AircraftState aircraft, int deltaKt) onSpeed;
  final void Function(AircraftState aircraft) onHold;
  final String? reviewEventLabel;

  const _DebugControls({
    required this.snapshot,
    required this.replayLength,
    required this.replayCursor,
    required this.runtime,
    required this.score,
    required this.paused,
    required this.speed,
    required this.sweepEnabled,
    required this.scenarioStarted,
    required this.resultShown,
    required this.reviewingReplay,
    required this.selectedAircraft,
    required this.scenarioName,
    required this.scenarioNames,
    required this.onPauseChanged,
    required this.onSpeedChanged,
    required this.onSweepChanged,
    required this.onStep,
    required this.onScenarioChanged,
    required this.onRestart,
    required this.onReturnToLive,
    required this.onEventSelected,
    required this.commandFilterAircraftId,
    required this.commandFilterType,
    required this.onCommandFilterAircraftChanged,
    required this.onCommandFilterTypeChanged,
    required this.onJumpToCommandPair,
    required this.onReplayScrub,
    required this.onStepReplayEvent,
    required this.onHeading,
    required this.onAltitude,
    required this.onSpeed,
    required this.onHold,
    required this.reviewEventLabel,
  });

  @override
  Widget build(BuildContext context) {
    final conflicts = snapshot.separation
        .where((item) => item.isPredictedConflict || item.isLossOfSeparation)
        .length;
    final scenarioState = runtime.evaluate();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: scenarioName,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 12),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final name in scenarioNames)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: onScenarioChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Restart',
                  onPressed: onRestart,
                  icon: const Icon(Icons.restart_alt),
                ),
                if (reviewingReplay)
                  IconButton(
                    tooltip: 'Return to live',
                    onPressed: onReturnToLive,
                    icon: const Icon(Icons.sensors),
                  ),
                IconButton(
                  tooltip: paused ? 'Resume' : 'Pause',
                  onPressed:
                      scenarioStarted ? () => onPauseChanged(!paused) : null,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                ),
                IconButton(
                  tooltip: 'Step one tick',
                  onPressed: onStep,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'T+${snapshot.elapsed.inSeconds}s  Tick ${snapshot.tick}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${snapshot.aircraft.where((item) => item.active).length} aircraft  '
                  '$conflicts alerts  Score ${score.score}  '
                  'Pressure ${snapshot.sectorPressureIndex.toStringAsFixed(1)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final option in const [1, 2, 4])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${option}x'),
                      selected: speed == option,
                      onSelected: (_) => onSpeedChanged(option),
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sweep',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    Switch(
                      value: sweepEnabled,
                      onChanged: onSweepChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                Text(
                  scenarioState.complete
                      ? (scenarioState.failed ? 'Failed' : 'Complete')
                      : 'Running',
                  style: TextStyle(
                    color: scenarioState.failed
                        ? AppTheme.danger
                        : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (resultShown || scenarioState.complete) ...[
              const SizedBox(height: 10),
              _ScenarioResultPanel(
                score: score,
                failed: scenarioState.failed,
                reasons: scenarioState.reasons,
              ),
            ],
            if (snapshot.events.isNotEmpty) ...[
              const SizedBox(height: 10),
              _TimelineStrip(
                snapshot: snapshot,
                replayLength: replayLength,
                replayCursor: replayCursor,
                onEventSelected: onEventSelected,
                onReplayScrub: onReplayScrub,
                onStepReplayEvent: onStepReplayEvent,
                reviewEventLabel: reviewEventLabel,
              ),
            ],
            if (snapshot.events.any((event) =>
                event.type == 'commandIssued' ||
                event.type == 'commandAcknowledged')) ...[
              const SizedBox(height: 10),
              _CommandReviewPanel(
                snapshot: snapshot,
                selectedAircraftId: commandFilterAircraftId,
                selectedType: commandFilterType,
                onAircraftChanged: onCommandFilterAircraftChanged,
                onTypeChanged: onCommandFilterTypeChanged,
                onJumpToEvent: onEventSelected,
                onJumpToPair: onJumpToCommandPair,
              ),
            ],
            if (snapshot.arrivalFlows.isNotEmpty) ...[
              const SizedBox(height: 10),
              _OperationalTrendPanel(snapshot: snapshot),
            ],
            if (snapshot.arrivalFlows.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ArrivalFlowPanel(snapshot: snapshot),
            ],
            if (selectedAircraft != null) ...[
              const SizedBox(height: 10),
              _SelectedAircraftPanel(
                aircraft: selectedAircraft!,
                onHeading: onHeading,
                onAltitude: onAltitude,
                onSpeed: onSpeed,
                onHold: onHold,
              ),
            ],
            if (score.penalties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    '${score.lastReason ?? 'Score'} ${score.lastDelta}',
                    key: ValueKey(
                        '${score.lastReason}${score.lastDelta}${score.penalties.length}'),
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineStrip extends StatelessWidget {
  final SimulationSnapshot snapshot;
  final int replayLength;
  final int replayCursor;
  final ValueChanged<SimulationEvent> onEventSelected;
  final ValueChanged<double> onReplayScrub;
  final ValueChanged<int> onStepReplayEvent;
  final String? reviewEventLabel;

  const _TimelineStrip({
    required this.snapshot,
    required this.replayLength,
    required this.replayCursor,
    required this.onEventSelected,
    required this.onReplayScrub,
    required this.onStepReplayEvent,
    required this.reviewEventLabel,
  });

  @override
  Widget build(BuildContext context) {
    final commandEvents = snapshot.events.where((event) {
      return event.type == 'commandIssued' ||
          event.type == 'commandAcknowledged';
    }).toList(growable: false);
    final recentEvents = snapshot.events.length > 8
        ? snapshot.events.sublist(snapshot.events.length - 8)
        : snapshot.events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 18),
              onPressed: () => onStepReplayEvent(-1),
              tooltip: 'Previous event',
            ),
            Expanded(
              child: Text(
                'Replay $replayCursor / ${replayLength - 1}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 18),
              onPressed: () => onStepReplayEvent(1),
              tooltip: 'Next event',
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          child: Slider(
            value: replayCursor.clamp(0, replayLength - 1).toDouble(),
            min: 0,
            max: (replayLength - 1).clamp(1, 9999).toDouble(),
            onChanged: onReplayScrub,
          ),
        ),
        if (commandEvents.isNotEmpty) ...[
          const SizedBox(height: 6),
          _PairedCommandLane(
            events: commandEvents.length > 16
                ? commandEvents.sublist(commandEvents.length - 16)
                : commandEvents,
            onEventSelected: onEventSelected,
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final event in recentEvents)
              Tooltip(
                message: event.label,
                child: InkWell(
                  onTap: () => onEventSelected(event),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _eventColor(event.type),
                      border: Border.all(color: AppTheme.borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${event.elapsed.inSeconds}s ${_eventShortLabel(event.type)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (reviewEventLabel != null) ...[
          const SizedBox(height: 5),
          Text(
            'Review: $reviewEventLabel',
            style: const TextStyle(color: AppTheme.primary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Color _eventColor(String type) {
    if (type == 'separationLoss') return const Color(0x33FF4D4D);
    if (type == 'commandAcknowledged') return const Color(0x2236D399);
    if (type == 'aircraftExited') return const Color(0x2255D6BE);
    return const Color(0x2246A3FF);
  }

  String _eventShortLabel(String type) {
    if (type == 'commandAcknowledged') return 'ACK';
    if (type == 'separationLoss') return 'LOSS';
    if (type == 'aircraftExited') return 'EXIT';
    return 'CMD';
  }
}

class _CommandReviewPanel extends StatelessWidget {
  final SimulationSnapshot snapshot;
  final String? selectedAircraftId;
  final String selectedType;
  final ValueChanged<String?> onAircraftChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<SimulationEvent> onJumpToEvent;
  final ValueChanged<SimulationEvent> onJumpToPair;

  const _CommandReviewPanel({
    required this.snapshot,
    required this.selectedAircraftId,
    required this.selectedType,
    required this.onAircraftChanged,
    required this.onTypeChanged,
    required this.onJumpToEvent,
    required this.onJumpToPair,
  });

  @override
  Widget build(BuildContext context) {
    final commandEvents = snapshot.events.where((event) {
      return event.type == 'commandIssued' ||
          event.type == 'commandAcknowledged';
    }).toList(growable: false);
    final callsignsById = <String, String>{
      for (final aircraft in snapshot.aircraft) aircraft.id: aircraft.callsign,
    };
    final aircraftIds = commandEvents
        .map((event) => event.aircraftId)
        .whereType<String>()
        .toSet()
        .toList(growable: false)
      ..sort();

    final filtered = commandEvents.where((event) {
      if (selectedAircraftId != null && event.aircraftId != selectedAircraftId) {
        return false;
      }
      if (selectedType == 'all') return true;
      return _commandTypeToken(event.label) == selectedType;
    }).toList(growable: false);

    final visible = filtered.length > 6
        ? filtered.sublist(filtered.length - 6)
        : filtered;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF07131C),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Command Review',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButton<String?>(
                  value: selectedAircraftId,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Aircraft'),
                    ),
                    for (final id in aircraftIds)
                      DropdownMenuItem<String?>(
                        value: id,
                        child: Text(callsignsById[id] ?? id),
                      ),
                  ],
                  onChanged: onAircraftChanged,
                ),
              ),
              SizedBox(
                width: 128,
                child: DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'heading', child: Text('Heading')),
                    DropdownMenuItem(value: 'speed', child: Text('Speed')),
                    DropdownMenuItem(value: 'altitude', child: Text('Altitude')),
                    DropdownMenuItem(value: 'direct', child: Text('Direct')),
                    DropdownMenuItem(value: 'hold', child: Text('Hold')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) onTypeChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            const Text(
              'No command events for current filter',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          for (final event in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => onJumpToEvent(event),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x1018E3FF),
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${event.elapsed.inSeconds}s '
                          '${_shortEventType(event.type)} '
                          '${_eventCallsign(event, callsignsById)} '
                          '${event.label}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 22,
                          height: 20,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Jump to paired command/ack',
                        onPressed: () => onJumpToPair(event),
                        icon: const Icon(
                          Icons.compare_arrows,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _eventCallsign(SimulationEvent event, Map<String, String> callsigns) {
    final id = event.aircraftId;
    if (id == null) return '';
    return callsigns[id] ?? id;
  }

  String _shortEventType(String type) {
    if (type == 'commandIssued') return 'ISS';
    if (type == 'commandAcknowledged') return 'ACK';
    return type;
  }

  String _commandTypeToken(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('heading')) return 'heading';
    if (normalized.contains('altitude')) return 'altitude';
    if (normalized.contains('speed')) return 'speed';
    if (normalized.contains('direct')) return 'direct';
    if (normalized.contains('exit hold') || normalized.contains(' hold')) {
      return 'hold';
    }
    return 'other';
  }
}

class _PairedCommandLane extends StatelessWidget {
  final List<SimulationEvent> events;
  final ValueChanged<SimulationEvent> onEventSelected;

  const _PairedCommandLane({
    required this.events,
    required this.onEventSelected,
  });

  @override
  Widget build(BuildContext context) {
    final issued = events
        .where((event) => event.type == 'commandIssued')
        .toList(growable: false);
    final acknowledgements = events
        .where((event) => event.type == 'commandAcknowledged')
        .toList(growable: false);
    final pairs = _pairCommands(issued, acknowledgements);
    final minSeconds = events.first.elapsed.inSeconds;
    final maxSeconds = events.last.elapsed.inSeconds;
    final span = (maxSeconds - minSeconds).clamp(1, 3600).toDouble();

    return Container(
      width: double.infinity,
      height: 84,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF081823),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final issuedY = 16.0;
          final ackY = 56.0;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PairConnectorPainter(
                    pairs: pairs,
                    minSeconds: minSeconds,
                    spanSeconds: span,
                    width: width,
                    issuedY: issuedY,
                    ackY: ackY,
                  ),
                ),
              ),
              Positioned(
                left: 2,
                top: 0,
                child: Text(
                  'Issued',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ),
              Positioned(
                left: 2,
                top: 40,
                child: Text(
                  'Ack',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ),
              for (final event in issued)
                _laneMarker(
                  event: event,
                  minSeconds: minSeconds,
                  span: span,
                  y: issuedY,
                  width: width,
                  color: const Color(0xFF46A3FF),
                ),
              for (final event in acknowledgements)
                _laneMarker(
                  event: event,
                  minSeconds: minSeconds,
                  span: span,
                  y: ackY,
                  width: width,
                  color: const Color(0xFF36D399),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _laneMarker({
    required SimulationEvent event,
    required int minSeconds,
    required double span,
    required double y,
    required double width,
    required Color color,
  }) {
    final x = ((event.elapsed.inSeconds - minSeconds) / span)
        .clamp(0, 1)
        .toDouble() *
        (width - 26);
    return Positioned(
      left: x,
      top: y,
      child: Tooltip(
        message: '${event.elapsed.inSeconds}s ${event.label}',
        child: InkWell(
          onTap: () => onEventSelected(event),
          child: Container(
            width: 20,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color.withValues(alpha: 0.8)),
            ),
            child: Text(
              event.type == 'commandIssued' ? 'I' : 'A',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_CommandPair> _pairCommands(
    List<SimulationEvent> issued,
    List<SimulationEvent> acknowledgements,
  ) {
    final usedAckIndexes = <int>{};
    final pairs = <_CommandPair>[];
    for (final issue in issued) {
      final issueToken = _commandTypeToken(issue.label);
      int? bestIndex;
      for (var i = 0; i < acknowledgements.length; i++) {
        if (usedAckIndexes.contains(i)) continue;
        final ack = acknowledgements[i];
        if (ack.aircraftId != issue.aircraftId) continue;
        if (_commandTypeToken(ack.label) != issueToken) continue;
        final delta = ack.elapsed - issue.elapsed;
        if (delta < Duration.zero || delta > const Duration(seconds: 12)) {
          continue;
        }
        bestIndex = i;
        break;
      }
      if (bestIndex == null) continue;
      usedAckIndexes.add(bestIndex);
      pairs.add(_CommandPair(issue: issue, ack: acknowledgements[bestIndex]));
    }
    return pairs;
  }

  String _commandTypeToken(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('heading')) return 'heading';
    if (normalized.contains('altitude')) return 'altitude';
    if (normalized.contains('speed')) return 'speed';
    if (normalized.contains('direct')) return 'direct';
    if (normalized.contains('exit hold') || normalized.contains(' hold')) {
      return 'hold';
    }
    return 'other';
  }
}

class _PairConnectorPainter extends CustomPainter {
  final List<_CommandPair> pairs;
  final int minSeconds;
  final double spanSeconds;
  final double width;
  final double issuedY;
  final double ackY;

  const _PairConnectorPainter({
    required this.pairs,
    required this.minSeconds,
    required this.spanSeconds,
    required this.width,
    required this.issuedY,
    required this.ackY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x557ED8FF);
    final urgentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x88FFD166);

    for (final pair in pairs) {
      final issueX = _toX(pair.issue.elapsed.inSeconds);
      final ackX = _toX(pair.ack.elapsed.inSeconds);
      final deltaSeconds =
          (pair.ack.elapsed - pair.issue.elapsed).inSeconds.abs();
      final isUrgent = deltaSeconds > 6;
      final path = Path()
        ..moveTo(issueX + 10, issuedY + 14)
        ..quadraticBezierTo(
          (issueX + ackX) / 2 + 10,
          (issuedY + ackY) / 2,
          ackX + 10,
          ackY,
        );
      canvas.drawPath(path, isUrgent ? urgentPaint : paint);

      final label = '${deltaSeconds}s';
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isUrgent ? const Color(0xFFFFD166) : AppTheme.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = ((issueX + ackX) / 2 + 10 - labelPainter.width / 2)
          .clamp(0, width - labelPainter.width)
          .toDouble();
      final labelY = (issuedY + ackY) / 2 - labelPainter.height / 2 - 2;
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelX - 2,
          labelY - 1,
          labelPainter.width + 4,
          labelPainter.height + 2,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        labelRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xDD0A1925),
      );
      labelPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  double _toX(int seconds) {
    return ((seconds - minSeconds) / spanSeconds).clamp(0, 1).toDouble() *
        (width - 26);
  }

  @override
  bool shouldRepaint(covariant _PairConnectorPainter oldDelegate) {
    return oldDelegate.pairs != pairs ||
        oldDelegate.minSeconds != minSeconds ||
        oldDelegate.spanSeconds != spanSeconds ||
        oldDelegate.width != width ||
        oldDelegate.issuedY != issuedY ||
        oldDelegate.ackY != ackY;
  }
}

class _CommandPair {
  final SimulationEvent issue;
  final SimulationEvent ack;

  const _CommandPair({
    required this.issue,
    required this.ack,
  });
}

class _ArrivalFlowPanel extends StatelessWidget {
  final SimulationSnapshot snapshot;

  const _ArrivalFlowPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF07131C),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arrival Sequence',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          for (final flow in snapshot.arrivalFlows)
            Text(
              _sequenceText(flow.runwayId, flow.spacingTargetNm),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
        ],
      ),
    );
  }

  String _sequenceText(String runwayId, double spacingTargetNm) {
    final arrivals = snapshot.aircraft
        .where((aircraft) =>
            aircraft.active && aircraft.intent.assignedRunwayId == runwayId)
        .map((aircraft) => aircraft.callsign)
        .join(' -> ');
    return '$runwayId target ${spacingTargetNm.toStringAsFixed(0)}NM: '
        '${arrivals.isEmpty ? 'no active arrivals' : arrivals}';
  }
}

class _OperationalTrendPanel extends StatelessWidget {
  final SimulationSnapshot snapshot;

  const _OperationalTrendPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final active =
        snapshot.aircraft.where((aircraft) => aircraft.active).length;
    final runwayPressure = _runwayPressureText();
    final mergePressure = _mergePressureText();
    final weatherPressure = _weatherPressureText();
    final departurePressure = _departurePressureText();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF07131C),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 5,
        children: [
          _TrendChip(
            label: 'LOAD',
            value: '$active/${snapshot.maxControllerLoad}',
            warning: active > snapshot.maxControllerLoad,
          ),
          _TrendChip(
            label: 'RWY',
            value: runwayPressure.$1,
            warning: runwayPressure.$2,
          ),
          _TrendChip(
            label: 'MERGE',
            value: mergePressure.$1,
            warning: mergePressure.$2,
          ),
          _TrendChip(
            label: 'WX',
            value: weatherPressure.$1,
            warning: weatherPressure.$2,
          ),
          _TrendChip(
            label: 'DEP',
            value: departurePressure.$1,
            warning: departurePressure.$2,
          ),
          _TrendChip(
            label: 'PRESS',
            value: snapshot.sectorPressureIndex.toStringAsFixed(1),
            warning: snapshot.sectorPressureIndex >= 1.0,
          ),
        ],
      ),
    );
  }

  (String, bool) _runwayPressureText() {
    for (final flow in snapshot.arrivalFlows) {
      final state = snapshot.runwayState(flow.runwayId);
      if (state != null && state.isOccupiedAt(snapshot.elapsed)) {
        final remaining =
            state.occupiedUntil.inSeconds - snapshot.elapsed.inSeconds;
        return ('${flow.runwayId} ${remaining}s', true);
      }
    }
    return ('clear', false);
  }

  (String, bool) _mergePressureText() {
    for (final flow in snapshot.arrivalFlows) {
      final merge = snapshot.waypoints[flow.mergeWaypointId];
      if (merge == null) continue;
      final closeCount = snapshot.aircraft.where((aircraft) {
        if (!aircraft.active ||
            aircraft.intent.assignedRunwayId != flow.runwayId) {
          return false;
        }
        final dx = aircraft.xNm - merge.xNm;
        final dy = aircraft.yNm - merge.yNm;
        return dx * dx + dy * dy < 10 * 10;
      }).length;
      if (closeCount >= 3) return ('saturated', true);
    }
    return ('stable', false);
  }

  (String, bool) _weatherPressureText() {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      for (final zone in snapshot.weatherZones) {
        final dx = aircraft.xNm - zone.xNm;
        final dy = aircraft.yNm - zone.yNm;
        final guard = zone.radiusNm + 3;
        if (dx * dx + dy * dy < guard * guard) {
          return ('reroute risk', true);
        }
      }
    }
    return ('nominal', false);
  }

  (String, bool) _departurePressureText() {
    if (snapshot.departureFlows.isEmpty) return ('none', false);
    var occupied = 0;
    for (final flow in snapshot.departureFlows) {
      final state = snapshot.runwayState(flow.runwayId);
      if (state != null && state.isOccupiedAt(snapshot.elapsed)) {
        occupied += 1;
      }
    }
    return occupied == 0
        ? ('flowing', false)
        : ('$occupied blocked', true);
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _TrendChip({
    required this.label,
    required this.value,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: TextStyle(
        color: warning ? AppTheme.warning : AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: warning ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _BriefingView extends StatelessWidget {
  final String scenarioName;
  final ScenarioRuntime runtime;
  final List<String> scenarioNames;
  final ValueChanged<String?> onScenarioChanged;
  final VoidCallback onStart;

  const _BriefingView({
    required this.scenarioName,
    required this.runtime,
    required this.scenarioNames,
    required this.onScenarioChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final definition = runtime.definition;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: scenarioName,
                        isExpanded: true,
                        dropdownColor: AppTheme.surface,
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          for (final name in scenarioNames)
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: onScenarioChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DifficultyPips(value: definition.difficulty),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  definition.trafficDescription,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                _BriefingSection(
                    title: 'Objectives', items: definition.objectives),
                const SizedBox(height: 12),
                _BriefingSection(
                  title: 'Expected Techniques',
                  items: definition.expectedTechniques,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Scenario'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BriefingSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BriefingSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '- $item',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

class _DifficultyPips extends StatelessWidget {
  final int value;

  const _DifficultyPips({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: i <= value ? AppTheme.warning : AppTheme.borderColor,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _ScenarioResultPanel extends StatelessWidget {
  final RadarV2ScoreSnapshot score;
  final bool failed;
  final List<String> reasons;

  const _ScenarioResultPanel({
    required this.score,
    required this.failed,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF101923),
        border: Border.all(
          color: failed ? AppTheme.danger : AppTheme.primary,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failed ? 'Scenario Failed' : 'Scenario Complete',
            style: TextStyle(
              color: failed ? AppTheme.danger : AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grade ${score.grade}  Score ${score.score}  '
            'Losses ${score.separationLossCount}  Commands ${score.commandCount}',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Efficiency ${_efficiencyLabel(score.commandCount)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Spacing ${score.spacingStability.toStringAsFixed(0)}%  '
            'Throughput ${score.throughputEfficiency.toStringAsFixed(0)}%  '
            'Weather ${score.weatherManagement.toStringAsFixed(0)}%  '
            'Commands ${score.commandEfficiency.toStringAsFixed(0)}%',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (score.penalties.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Timeline Summary',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            for (final penalty in score.penalties.take(4))
              Text(
                penalty,
                style: const TextStyle(color: AppTheme.warning, fontSize: 11),
              ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reasons.join(' / '),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _efficiencyLabel(int commands) {
    if (commands <= 4) return 'Excellent';
    if (commands <= 8) return 'Good';
    if (commands <= 12) return 'Busy';
    return 'Over-controlled';
  }
}

class _SelectedAircraftPanel extends StatelessWidget {
  final AircraftState aircraft;
  final void Function(AircraftState aircraft, int deltaDeg) onHeading;
  final void Function(AircraftState aircraft, int deltaFt) onAltitude;
  final void Function(AircraftState aircraft, int deltaKt) onSpeed;
  final void Function(AircraftState aircraft) onHold;

  const _SelectedAircraftPanel({
    required this.aircraft,
    required this.onHeading,
    required this.onAltitude,
    required this.onSpeed,
    required this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1723),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${aircraft.callsign}  '
              'HDG ${aircraft.headingDeg.round().toString().padLeft(3, '0')}  '
              'ALT ${aircraft.altitudeFt ~/ 100}  '
              'SPD ${aircraft.groundSpeedKt.round()}',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CommandButton(
                  icon: Icons.rotate_left,
                  label: 'L',
                  onPressed: () => onHeading(aircraft, -10),
                ),
                _CommandButton(
                  icon: Icons.rotate_right,
                  label: 'R',
                  onPressed: () => onHeading(aircraft, 10),
                ),
                const SizedBox(width: 10),
                _CommandButton(
                  icon: Icons.arrow_upward,
                  label: '+ALT',
                  onPressed: () => onAltitude(aircraft, 1000),
                ),
                _CommandButton(
                  icon: Icons.arrow_downward,
                  label: '-ALT',
                  onPressed: () => onAltitude(aircraft, -1000),
                ),
                const SizedBox(width: 10),
                _CommandButton(
                  icon: Icons.add,
                  label: '+SPD',
                  onPressed: () => onSpeed(aircraft, 20),
                ),
                _CommandButton(
                  icon: Icons.remove,
                  label: '-SPD',
                  onPressed: () => onSpeed(aircraft, -20),
                ),
                const SizedBox(width: 10),
                _CommandButton(
                  icon: aircraft.intent.hold ? Icons.play_arrow : Icons.loop,
                  label: aircraft.intent.hold ? 'EXIT HOLD' : 'HOLD',
                  onPressed: () => onHold(aircraft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CommandButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: 42,
          height: 36,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}
