import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/pilot_radio_audio_service.dart';
import '../../services/workload_audio_controller.dart';
import 'commands/controller_command.dart';
import 'core/alerts/operational_alert.dart';
import 'core/cognitive_load/cognitive_load_level.dart';
import 'models/aircraft_state.dart';
import 'models/simulation_event.dart';
import 'models/simulation_snapshot.dart';
import 'rendering/radar_v2_painter.dart';
import 'rendering/radar_view_transform.dart';
import 'scenario/scenario_asset_loader.dart';
import 'scenario/scenario_runtime.dart';
import 'scoring/radar_v2_score.dart';
import 'training/radar_training_result.dart';
import 'training/radar_training_result_screen.dart';
import 'training/radar_training_progress_store.dart';
import 'training/radar_training_text_localizer.dart';
import 'workflow/command_workflow_tracker.dart';

class RadarV2DebugScreen extends StatefulWidget {
  final bool betaMode;
  final bool showDebugOverlays;
  final String? initialScenarioName;
  final Map<String, String>? scenarioAssets;
  final String? trainingScenarioTitle;
  final String? trainingScenarioId;

  const RadarV2DebugScreen({
    super.key,
    this.betaMode = false,
    this.showDebugOverlays = false,
    this.initialScenarioName,
    this.scenarioAssets,
    this.trainingScenarioTitle,
    this.trainingScenarioId,
  });

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

  Map<String, String> get _availableScenarioAssets =>
      widget.scenarioAssets ?? _scenarioAssets;

  ScenarioRuntime? _runtime;
  SimulationSnapshot? _previousSnapshot;
  SimulationSnapshot? _snapshot;
  final List<SimulationSnapshot> _replayHistory = <SimulationSnapshot>[];
  RadarV2ScoreTracker _scoreTracker = RadarV2ScoreTracker();
    final CommandWorkflowTracker _commandWorkflow = CommandWorkflowTracker();
  final WorkloadAudioController _audioController = WorkloadAudioController();
  final PilotRadioAudioService _radioAudio = PilotRadioAudioService.instance;
  late final AudioPlayer _cuePlayer = AudioPlayer(playerId: 'radar_cues');
  late final AudioPlayer _cuePlayerAlt =
      AudioPlayer(playerId: 'radar_cues_alt');
  Future<void> _cuePlaybackChain = Future<void>.value();
  bool _useAltCuePlayer = false;
  Ticker? _ticker;
  Duration? _lastFrameTime;
  Duration _lastIdlePaint = Duration.zero;
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
  late String _scenarioName =
      widget.initialScenarioName ?? _availableScenarioAssets.keys.first;
  String? _selectedAircraftId;
  String? _commandFilterAircraftId;
  String _commandFilterType = 'all';
  String? _reviewEventLabel;
  String? _recentlyCommandedAircraftId;
  String? _recentlyAcknowledgedAircraftId;
  DateTime? _commandFlashUntil;
  DateTime? _ackFlashUntil;
  Timer? _commandHighlightTimer;
  Timer? _ackHighlightTimer;
  DateTime _lastAudioCue = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSweepCue = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, DateTime> _commandCooldownUntil = {};
  double? _radarVisibleRangeNm;
  Offset _radarViewCenterNm = Offset.zero;
  double _scaleStartRangeNm = 40;
  Offset _scaleStartCenterNm = Offset.zero;
  Offset _scaleStartFocalNm = Offset.zero;
  Offset _scaleStartFocalCanvas = Offset.zero;
  bool _radarGestureMoved = false;
  bool _muted = false;
  Object? _loadError;
  int _audioProbeCount = 0;
  String _audioProbeStatus = '';

  bool get _showAudioSelfTestControls => kDebugMode && !widget.betaMode;

  @override
  void initState() {
    super.initState();
    developer.log(
      'AUDIO_PROBE init betaMode=${widget.betaMode}',
      name: 'RadarV2DebugScreen',
    );
    _initializeAudio();
    _radioAudio.initialize();
    _loadScenario(_scenarioName);
    _ticker = createTicker(_onFrame)..start();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioController.initialize();
      await _configureCuePlayer(_cuePlayer);
      await _configureCuePlayer(_cuePlayerAlt);
    } catch (e) {
      assert(() {
        debugPrint('RadarV2DebugScreen: Failed to initialize audio: $e');
        return true;
      }());
    }
  }

  Future<void> _configureCuePlayer(AudioPlayer player) async {
    await player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {},
        ),
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
          isSpeakerphoneOn: true,
        ),
      ),
    );
    await player.setVolume(1.0);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlayerMode(PlayerMode.lowLatency);
  }

  Future<void> _loadScenario(String scenarioName) async {
    try {
      final assetPath = _availableScenarioAssets[scenarioName]!;
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
      _resetRadarView(definition.radarRangeNm);
      _commandWorkflow.clear();
      _scenarioStarted = widget.betaMode;
      _paused = !widget.betaMode;
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
      if (frameTime - _lastIdlePaint < const Duration(milliseconds: 33)) {
        _playSweepCue();
        return;
      }
      _lastIdlePaint = frameTime;
      setState(() {
        _sweepAngleRad = (_sweepAngleRad + 0.024) % (math.pi * 2);
        _alertPulse = !_alertPulse;
      });
      _playSweepCue();
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
    _playSweepCue();
  }

  void _restartScenario() {
    _loadScenario(_scenarioName);
  }

  Future<void> _openTrainingResult() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final result = RadarTrainingResultBuilder.build(
      scenarioTitle: widget.trainingScenarioTitle ?? _scenarioName,
      scenarioId: widget.trainingScenarioId ?? _scenarioName,
      score: _scoreTracker.snapshot,
      snapshot: snapshot,
    );
    await const RadarTrainingProgressStore().saveResult(
      scenarioId: result.scenarioId,
      score: result.score.score,
      grade: result.score.grade,
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadarTrainingResultScreen(
          result: result,
          onRestart: () {
            Navigator.of(context).pop();
            _restartScenario();
          },
        ),
      ),
    );
  }

  void _startScenario() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() {
      _commandWorkflow.clear();
      _scenarioStarted = true;
      _paused = false;
      _previousSnapshot = runtime.snapshot;
      runtime.updateAttentionFocus(selectedAircraftId: _selectedAircraftId);
      _snapshot = runtime.tick();
      _replayHistory
        ..clear()
        ..add(_previousSnapshot!)
        ..add(_snapshot!);
      _replayCursor = _replayHistory.length - 1;
      _scoreTracker.observe(_snapshot!);
      _scoreTracker.observeWorkload(_snapshot!);
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
    runtime.updateAttentionFocus(selectedAircraftId: _selectedAircraftId);
    _previousSnapshot = snapshot;
    _snapshot = runtime.tick();
    _commandWorkflow.onSnapshotTransition(
      previous: snapshot,
      current: _snapshot!,
    );
    _reviewingReplay = false;
    _recordReplaySnapshot(_snapshot!);
    _scoreTracker.observe(_snapshot!);
    _scoreTracker.observeWorkload(_snapshot!);
    _audioController.tick(_snapshot!.cognitiveLoad.currentLevel);
    _captureAckFeedback(snapshot, _snapshot!);
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
    if (_radarGestureMoved) {
      _radarGestureMoved = false;
      return;
    }
    final selected = _nearestAircraft(
      snapshot,
      details.localPosition,
      size,
      runtime.definition.radarRangeNm,
    );
    runtime.updateAttentionFocus(selectedAircraftId: selected?.id);
    setState(() => _selectedAircraftId = selected?.id);
  }

  Future<void> _openQuickCommandRadial(
    LongPressStartDetails details,
    Size size,
  ) async {
    final snapshot = _snapshot;
    final runtime = _runtime;
    if (snapshot == null || runtime == null) return;
    final selected = _nearestAircraft(
      snapshot,
      details.localPosition,
      size,
      runtime.definition.radarRangeNm,
    );
    if (selected == null) return;

    runtime.updateAttentionFocus(selectedAircraftId: selected.id);
    if (mounted) {
      setState(() => _selectedAircraftId = selected.id);
    }
    final waypointIds = snapshot.waypoints.keys.take(6).toList(growable: false);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF081722),
      builder: (context) {
        return _QuickCommandRadialMenu(
          aircraft: selected,
          waypointIds: waypointIds,
          onHeadingDelta: (delta) => _commandHeading(selected, delta),
          onSpeedDelta: (delta) => _commandSpeed(selected, delta),
          onAltitudeDelta: (delta) => _commandAltitude(selected, delta),
          onDirect: (waypointId) => _commandDirect(selected, waypointId),
          onHold: () => _commandHold(selected),
          onVectorAndAltitude: () {
            final commands = <ControllerCommand>[
              AssignHeading(
                aircraftId: selected.id,
                issuedAt: _snapshot?.elapsed ?? Duration.zero,
                headingDeg: _normalizeHeading(selected.headingDeg + 20),
              ),
              AssignAltitude(
                aircraftId: selected.id,
                issuedAt: _snapshot?.elapsed ?? Duration.zero,
                altitudeFt: (selected.altitudeFt - 1000).clamp(2000, 45000),
              ),
            ];
            _issueCommandChain(
              selected,
              commands,
              '${selected.callsign} VECTOR+ALT',
            );
          },
          onHeadingAndSpeed: () {
            final commands = <ControllerCommand>[
              AssignHeading(
                aircraftId: selected.id,
                issuedAt: _snapshot?.elapsed ?? Duration.zero,
                headingDeg: _normalizeHeading(selected.headingDeg + 20),
              ),
              AssignSpeed(
                aircraftId: selected.id,
                issuedAt: _snapshot?.elapsed ?? Duration.zero,
                speedKt: (selected.groundSpeedKt - 20).clamp(120, 480).toDouble(),
              ),
            ];
            _issueCommandChain(
              selected,
              commands,
              '${selected.callsign} HDG+SPD',
            );
          },
          onDescendAndDirect: (waypointId) {
            final commands = <ControllerCommand>[
              AssignAltitude(
                aircraftId: selected.id,
                issuedAt: _snapshot?.elapsed ?? Duration.zero,
                altitudeFt: (selected.altitudeFt - 1000).clamp(2000, 45000),
              ),
              DirectToWaypoint(
                aircraftId: selected.id,
                issuedAt: _snapshot?.elapsed ?? Duration.zero,
                waypointId: waypointId,
              ),
            ];
            _issueCommandChain(
              selected,
              commands,
              '${selected.callsign} DES+DIRECT $waypointId',
            );
          },
        );
      },
    );
  }

  AircraftState? _nearestAircraft(
    SimulationSnapshot snapshot,
    Offset tap,
    Size size,
    double rangeNm,
  ) {
    final transform = _radarTransform(size, rangeNm);
    AircraftState? closest;
    var closestDistance = 18.0;
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      final position = transform.nmToCanvas(aircraft.xNm, aircraft.yNm);
      final distance = (position - tap).distance;
      if (distance < closestDistance) {
        closest = aircraft;
        closestDistance = distance;
      }
    }
    return closest;
  }

  RadarViewTransform _radarTransform(Size size, double sectorRangeNm) {
    final visibleRange = (_radarVisibleRangeNm ?? sectorRangeNm)
        .clamp(RadarViewTransform.minTacticalRangeNm, sectorRangeNm)
        .toDouble();
    return RadarViewTransform(
      size: size,
      sectorRangeNm: sectorRangeNm,
      visibleRangeNm: visibleRange,
      viewCenterNm: _radarViewCenterNm,
    ).withView();
  }

  void _resetRadarView(double sectorRangeNm) {
    _radarVisibleRangeNm = sectorRangeNm;
    _radarViewCenterNm = Offset.zero;
    _scaleStartRangeNm = sectorRangeNm;
    _scaleStartCenterNm = Offset.zero;
    _scaleStartFocalNm = Offset.zero;
  }

  void _onRadarScaleStart(ScaleStartDetails details, Size size) {
    final runtime = _runtime;
    if (runtime == null) return;
    final transform = _radarTransform(size, runtime.definition.radarRangeNm);
    _scaleStartRangeNm = transform.visibleRangeNm;
    _scaleStartCenterNm = transform.viewCenterNm;
    _scaleStartFocalNm = transform.canvasToNm(details.localFocalPoint);
    _scaleStartFocalCanvas = details.localFocalPoint;
    _radarGestureMoved = false;
  }

  void _onRadarScaleUpdate(ScaleUpdateDetails details, Size size) {
    final runtime = _runtime;
    if (runtime == null) return;
    final sectorRange = runtime.definition.radarRangeNm;
    final base = RadarViewTransform(
      size: size,
      sectorRangeNm: sectorRange,
      visibleRangeNm: _scaleStartRangeNm,
      viewCenterNm: _scaleStartCenterNm,
    ).withView();
    final targetRange = (_scaleStartRangeNm / details.scale)
        .clamp(
          RadarViewTransform.minTacticalRangeNm,
          sectorRange,
        )
        .toDouble();
    final nextScale = base.radiusPx / targetRange;
    final nextCenter = Offset(
      _scaleStartFocalNm.dx -
          (details.localFocalPoint.dx - base.canvasCenter.dx) / nextScale,
      _scaleStartFocalNm.dy +
          (details.localFocalPoint.dy - base.canvasCenter.dy) / nextScale,
    );
    final next = base.withView(
      visibleRangeNm: targetRange,
      viewCenterNm: nextCenter,
    );
    final focalMoved =
        (details.localFocalPoint - _scaleStartFocalCanvas).distance > 6;
    final scaleMoved = (details.scale - 1).abs() > 0.02;
    _radarGestureMoved = _radarGestureMoved || focalMoved || scaleMoved;
    setState(() {
      _radarVisibleRangeNm = next.visibleRangeNm;
      _radarViewCenterNm = next.viewCenterNm;
    });
  }

  void _zoomRadar(double factor) {
    final runtime = _runtime;
    if (runtime == null) return;
    final sectorRange = runtime.definition.radarRangeNm;
    final current = _radarVisibleRangeNm ?? sectorRange;
    final next = RadarViewTransform(
      size: const Size(1, 1),
      sectorRangeNm: sectorRange,
      visibleRangeNm: current / factor,
      viewCenterNm: _radarViewCenterNm,
    ).withView();
    setState(() {
      _radarVisibleRangeNm = next.visibleRangeNm;
      _radarViewCenterNm = next.viewCenterNm;
    });
  }

  void _resetRadarZoom() {
    final runtime = _runtime;
    if (runtime == null) return;
    setState(() => _resetRadarView(runtime.definition.radarRangeNm));
  }

  void _issueCommand(
    ControllerCommand command,
    String feedback, {
    String? chainId,
  }) {
    final runtime = _runtime;
    final snapshot = _snapshot;
    final l10n = AppLocalizations.of(context)!;
    if (runtime == null || snapshot == null) return;
    final cooldownKey = '${command.aircraftId}:${command.runtimeType}';
    final now = DateTime.now();
    final blockedUntil = _commandCooldownUntil[cooldownKey];
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.radarTrainingCommandChannelBusy),
            duration: Duration(milliseconds: 700),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    _commandCooldownUntil[cooldownKey] =
        now.add(const Duration(milliseconds: 450));
    final stamped = _stampCommandIssuedAt(command, snapshot.elapsed);
    runtime.engine.applyCommand(stamped);
    _commandWorkflow.onCommandSent(
      command: stamped,
      aircraft: _aircraftForId(snapshot, stamped.aircraftId) ??
          AircraftState(
            id: stamped.aircraftId,
            callsign: stamped.aircraftId,
            xNm: 0,
            yNm: 0,
            altitudeFt: 0,
            headingDeg: 0,
            groundSpeedKt: 0,
          ),
      label: feedback,
      chainId: chainId,
    );
    _playButtonCue();
    if (!_muted) {
      _enqueuePilotAck(command, snapshot);
    }
    runtime.recordCommandTimestamp(snapshot.elapsed,
      aircraftId: stamped.aircraftId);
    _scoreTracker.recordCommand(stamped, snapshot);
    _commandHighlightTimer?.cancel();
    setState(() {
      _snapshot = runtime.snapshot;
      _previousSnapshot = snapshot;
      _renderInterpolation = 1;
      _recentlyCommandedAircraftId = stamped.aircraftId;
      _commandFlashUntil = now.add(const Duration(milliseconds: 900));
    });
    _commandHighlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _recentlyCommandedAircraftId = null);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.radarTrainingCommandSent(feedback)),
          duration: const Duration(milliseconds: 1300),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  ControllerCommand _stampCommandIssuedAt(
    ControllerCommand command,
    Duration issuedAt,
  ) {
    if (command is AssignHeading) {
      return AssignHeading(
        aircraftId: command.aircraftId,
        issuedAt: issuedAt,
        headingDeg: command.headingDeg,
      );
    }
    if (command is AssignAltitude) {
      return AssignAltitude(
        aircraftId: command.aircraftId,
        issuedAt: issuedAt,
        altitudeFt: command.altitudeFt,
      );
    }
    if (command is AssignSpeed) {
      return AssignSpeed(
        aircraftId: command.aircraftId,
        issuedAt: issuedAt,
        speedKt: command.speedKt,
      );
    }
    if (command is DirectToWaypoint) {
      return DirectToWaypoint(
        aircraftId: command.aircraftId,
        issuedAt: issuedAt,
        waypointId: command.waypointId,
      );
    }
    if (command is EnterHold) {
      return EnterHold(
        aircraftId: command.aircraftId,
        issuedAt: issuedAt,
        holdPatternId: command.holdPatternId,
      );
    }
    if (command is ExitHold) {
      return ExitHold(
        aircraftId: command.aircraftId,
        issuedAt: issuedAt,
      );
    }
    return command;
  }

  void _issueCommandChain(
    AircraftState aircraft,
    List<ControllerCommand> commands,
    String summary,
  ) {
    final baseChainId =
        '${aircraft.id}:${_snapshot?.elapsed.inMilliseconds ?? 0}:${commands.length}';
    for (final command in commands) {
      _issueCommand(command, summary, chainId: baseChainId);
    }
  }

  void _enqueuePilotAck(
      ControllerCommand command, SimulationSnapshot snapshot) {
    final aircraft = _aircraftForId(snapshot, command.aircraftId);
    if (aircraft == null) return;
    final text = _pilotAckText(command, aircraft);
    _radioAudio.enqueuePilotAck(
      callsign: aircraft.callsign,
      spokenText: text,
      respectSettings: !widget.betaMode,
    );
  }

  AircraftState? _aircraftForId(SimulationSnapshot snapshot, String id) {
    for (final aircraft in snapshot.aircraft) {
      if (aircraft.id == id) return aircraft;
    }
    return null;
  }

  String _pilotAckText(ControllerCommand command, AircraftState aircraft) {
    final callsign = aircraft.callsign;
    switch (command) {
      case AssignHeading(:final headingDeg):
        final heading =
            _normalizeHeading(headingDeg).round().toString().padLeft(3, '0');
        return '$callsign, turning heading $heading.';
      case AssignAltitude(:final altitudeFt):
        final level = altitudeFt ~/ 100;
        final verb =
            altitudeFt >= aircraft.altitudeFt ? 'climbing' : 'descending';
        return '$callsign, $verb flight level $level.';
      case AssignSpeed(:final speedKt):
        final verb =
            speedKt >= aircraft.groundSpeedKt ? 'increasing' : 'reducing';
        return '$callsign, $verb speed ${speedKt.round()} knots.';
      case DirectToWaypoint(:final waypointId):
        return '$callsign, direct $waypointId.';
      case EnterHold():
        return '$callsign, entering hold.';
      case ExitHold():
        return '$callsign, exiting hold.';
    }
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

  void _commandDirect(AircraftState aircraft, String waypointId) {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.waypoints.containsKey(waypointId)) {
      return;
    }
    _issueCommand(
      DirectToWaypoint(
        aircraftId: aircraft.id,
        issuedAt: snapshot.elapsed,
        waypointId: waypointId,
      ),
      '${aircraft.callsign} DIRECT $waypointId',
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

  void _captureAckFeedback(
    SimulationSnapshot previous,
    SimulationSnapshot current,
  ) {
    if (current.events.length <= previous.events.length) return;
    final newEvents = current.events.skip(previous.events.length);
    String? acknowledgedAircraftId;
    String? acknowledgementLabel;
    for (final event in newEvents) {
      if (event.type == 'commandAcknowledged' && event.aircraftId != null) {
        acknowledgedAircraftId = event.aircraftId;
        acknowledgementLabel = event.label;
      }
    }
    if (acknowledgedAircraftId == null) return;
    _ackHighlightTimer?.cancel();
    setState(() {
      _recentlyAcknowledgedAircraftId = acknowledgedAircraftId;
      _ackFlashUntil = DateTime.now().add(const Duration(milliseconds: 1100));
    });
    _ackHighlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _recentlyAcknowledgedAircraftId = null);
    });
    if (acknowledgementLabel != null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.radarTrainingCommandAcknowledged(acknowledgementLabel),
            ),
            duration: const Duration(milliseconds: 950),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    if (_muted) return;
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
      3 => 900,
      2 => 900,
      _ => 2600,
    };
    if (now.difference(_lastAudioCue).inMilliseconds < cooldownMs) return;
    _lastAudioCue = now;
    if (level == 3) {
      _playRadioCue(RadioWarningType.conflict);
      return;
    }
    if (level == 2) {
      _playRadioCue(RadioWarningType.runwayPressure);
      return;
    }
    _playRadioCue(RadioWarningType.conflict);
  }

  void _playSweepCue() {
    if (_muted || !_sweepEnabled || !widget.betaMode) return;
    final now = DateTime.now();
    if (now.difference(_lastSweepCue).inMilliseconds < 3600) return;
    if (now.difference(_lastAudioCue).inMilliseconds < 1600) return;
    _lastSweepCue = now;
    developer.log(
      'AUDIO_PROBE sweepCue asset=radar_sweep_tick',
      name: 'RadarV2DebugScreen',
    );
    unawaited(_enqueueCue('audio/radio/radar_sweep_tick.wav'));
  }

  void _playButtonCue() {
    if (_muted) return;
    _lastAudioCue = DateTime.now();
    unawaited(_radioAudio.playImmediateCue(
      RadioWarningType.runwayPressure,
      respectSettings: !widget.betaMode,
    ));
    developer.log(
      'AUDIO_PROBE commandCue asset=runwayPressure',
      name: 'RadarV2DebugScreen',
    );
    _audioProbeCount++;
    _audioProbeStatus = 'command cue: asset requested (#$_audioProbeCount)';
  }

  void _playRadioCue(RadioWarningType type) {
    if (_muted) return;
    unawaited(_radioAudio.playImmediateCue(
      type,
      respectSettings: !widget.betaMode,
    ));
  }

  void _toggleMute() {
    final next = !_muted;
    setState(() => _muted = next);
    if (next) {
      unawaited(_radioAudio.clearQueue(stopCurrent: true));
      unawaited(_cuePlayer.stop());
      unawaited(_cuePlayerAlt.stop());
    }
  }

  Future<void> _runAudioSelfTest(AppLocalizations l10n) async {
    if (_muted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radarTrainingAudioSelfTestMuted)),
      );
      return;
    }
    final fallbackOk = _playSystemFallbackCue();
    final assetOk =
        await _enqueueCue('audio/radio/runway_pressure_warning.wav');
    final ok = fallbackOk || assetOk;
    developer.log(
      'AUDIO_PROBE selfTest system=$fallbackOk asset=$assetOk overall=$ok',
      name: 'RadarV2DebugScreen',
    );
    if (mounted) {
      setState(() {
        _audioProbeCount++;
        _audioProbeStatus =
            'self-test #$_audioProbeCount: system=${fallbackOk ? "ok" : "fail"}, asset=${assetOk ? "ok" : "fail"}';
      });
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.radarTrainingAudioSelfTestStarted
              : l10n.radarTrainingAudioSelfTestFailed,
        ),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<bool> _enqueueCue(String assetPath) {
    final completer = Completer<bool>();
    _cuePlaybackChain = _cuePlaybackChain.then((_) async {
      if (!mounted) {
        completer.complete(false);
        return;
      }
      final ok = await _playCueInternal(assetPath);
      developer.log(
        'AUDIO_PROBE localCue asset=$assetPath ok=$ok',
        name: 'RadarV2DebugScreen',
      );
      completer.complete(ok);
    });
    return completer.future;
  }

  Future<bool> _playCueInternal(String assetPath) async {
    final primary = _useAltCuePlayer ? _cuePlayerAlt : _cuePlayer;
    final secondary = _useAltCuePlayer ? _cuePlayer : _cuePlayerAlt;
    _useAltCuePlayer = !_useAltCuePlayer;

    try {
      // Android can miss repeated cues unless the previous state is fully reset.
      await primary.stop();
      await primary.play(AssetSource(assetPath), volume: 1.0);
      return true;
    } catch (e) {
      try {
        await secondary.stop();
        await secondary.play(AssetSource(assetPath), volume: 1.0);
        return true;
      } catch (_) {
        assert(() {
          debugPrint('RadarV2DebugScreen: Failed to play $assetPath: $e');
          return true;
        }());
        return _playSystemFallbackCue();
      }
    }
  }

  bool _playSystemFallbackCue() {
    try {
      SystemSound.play(SystemSoundType.alert);
      developer.log('AUDIO_PROBE systemBeep ok', name: 'RadarV2DebugScreen');
      return true;
    } catch (_) {
      developer.log(
        'AUDIO_PROBE systemBeep failed',
        name: 'RadarV2DebugScreen',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !widget.betaMode) {
      return const SizedBox.shrink();
    }

    final runtime = _runtime;
    final snapshot = _snapshot;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
            widget.betaMode ? l10n.radarTrainingBetaTitle : 'Radar V2 Debug'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            tooltip: _muted
                ? l10n.radarTrainingUnmuteAudioCues
                : l10n.radarTrainingMuteAudioCues,
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
          if (_showAudioSelfTestControls)
            IconButton(
              tooltip: l10n.radarTrainingAudioSelfTestTooltip,
              icon: const Icon(Icons.hearing),
              onPressed: () => _runAudioSelfTest(l10n),
            ),
          IconButton(
            tooltip: l10n.radarTrainingRestartScenario,
            icon: const Icon(Icons.restart_alt),
            onPressed: _restartScenario,
          ),
        ],
      ),
      bottomNavigationBar: _showAudioSelfTestControls
          ? SafeArea(
              top: false,
              child: Container(
                color: const Color(0xCC0A1A28),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _audioProbeStatus.isEmpty
                            ? 'Audio probe ready'
                            : _audioProbeStatus,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _runAudioSelfTest(l10n),
                      icon: const Icon(Icons.hearing, size: 16),
                      label: Text(l10n.radarTrainingAudioSelfTestTooltip),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: _showAudioSelfTestControls
          ? FloatingActionButton.extended(
              heroTag: 'radar-audio-self-test',
              onPressed: () => _runAudioSelfTest(l10n),
              icon: const Icon(Icons.hearing),
              label: Text(l10n.radarTrainingAudioSelfTestTooltip),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF020A10),
              child: _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              color: AppTheme.warning,
                              size: 34,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.radarTrainingScenarioLoadFailed,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${l10n.radarTrainingScenarioLoadFailedHelp}\n$_loadError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _loadScenario(_scenarioName),
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.scenarioRetry),
                            ),
                          ],
                        ),
                      ),
                    )
                  : snapshot == null || runtime == null
                      ? const Center(child: CircularProgressIndicator())
                      : !_scenarioStarted
                          ? _BriefingView(
                              scenarioName: _scenarioName,
                              runtime: runtime,
                              scenarioNames: _availableScenarioAssets.keys
                                  .toList(growable: false),
                              onScenarioChanged: (value) {
                                if (value != null) _loadScenario(value);
                              },
                              onStart: _startScenario,
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.biggest;
                                return Stack(
                                  children: [
                                    RepaintBoundary(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onScaleStart: (details) =>
                                            _onRadarScaleStart(details, size),
                                        onScaleUpdate: (details) =>
                                            _onRadarScaleUpdate(details, size),
                                        onTapUp: (details) =>
                                            _selectAircraft(details, size),
                                        onLongPressStart: (details) =>
                                          _openQuickCommandRadial(
                                            details, size),
                                        child: CustomPaint(
                                          painter: RadarV2Painter(
                                            snapshot: snapshot,
                                            previousSnapshot: _previousSnapshot,
                                            interpolation: _renderInterpolation,
                                            rangeNm: _radarTransform(
                                              size,
                                              _runtime!.definition.radarRangeNm,
                                            ).visibleRangeNm,
                                            sectorRangeNm:
                                                _runtime!.definition.radarRangeNm,
                                            viewCenterNm: _radarViewCenterNm,
                                            selectedAircraftId:
                                                _selectedAircraftId,
                                            recentlyCommandedAircraftId:
                                                _recentlyCommandedAircraftId,
                                            recentlyAcknowledgedAircraftId:
                                                _recentlyAcknowledgedAircraftId,
                                            replayMode: _reviewingReplay,
                                            alertPulse: _alertPulse,
                                            sweepEnabled: _sweepEnabled,
                                            sweepAngleRad: _sweepAngleRad,
                                          ),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: _RadarRangeControls(
                                        rangeNm: _radarTransform(
                                          size,
                                          runtime.definition.radarRangeNm,
                                        ).visibleRangeNm,
                                        canZoomIn: (_radarVisibleRangeNm ??
                                                runtime
                                                    .definition.radarRangeNm) >
                                            RadarViewTransform
                                                .minTacticalRangeNm,
                                        canZoomOut: (_radarVisibleRangeNm ??
                                                runtime
                                                    .definition.radarRangeNm) <
                                            runtime.definition.radarRangeNm,
                                        onZoomIn: () => _zoomRadar(1.25),
                                        onZoomOut: () => _zoomRadar(0.8),
                                        onReset: _resetRadarZoom,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 196,
                                      right: 212,
                                      child: _OperationalAtmosphereStrip(
                                        snapshot: snapshot,
                                        sectorId: runtime.definition.sectorId,
                                        weatherMode:
                                            runtime.definition.weatherMode,
                                      ),
                                    ),
                                    if (_showAudioSelfTestControls)
                                      Positioned(
                                        right: 10,
                                        bottom: 10,
                                        child: Container(
                                          width: 210,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xCC0A1A28),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0x6646F5A7),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              FilledButton.icon(
                                                onPressed: () =>
                                                    _runAudioSelfTest(l10n),
                                                icon: const Icon(Icons.hearing,
                                                    size: 16),
                                                label: Text(
                                                  l10n.radarTrainingAudioSelfTestTooltip,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (_audioProbeStatus.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6),
                                                  child: Text(
                                                    _audioProbeStatus,
                                                    style: const TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_commandFlashUntil != null &&
                                        DateTime.now()
                                            .isBefore(_commandFlashUntil!))
                                      Positioned(
                                        top: 74,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: _TransientStatusChip(
                                            label:
                                                l10n.radarTrainingCommandIssued,
                                            color: Color(0xFF62D2FF),
                                          ),
                                        ),
                                      ),
                                    if (_ackFlashUntil != null &&
                                        DateTime.now()
                                            .isBefore(_ackFlashUntil!))
                                      Positioned(
                                        top: 104,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: _TransientStatusChip(
                                            label:
                                                l10n.radarTrainingAcknowledged,
                                            color: Color(0xFF46F5A7),
                                          ),
                                        ),
                                      ),
                                    if (!widget.betaMode ||
                                        widget.showDebugOverlays)
                                      _OverloadPulseEffect(
                                        snapshot: snapshot,
                                        alertPulse: _alertPulse,
                                      ),
                                    // Alert stack panel (left side)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      bottom: 8,
                                      width: 180,
                                      child: _AlertStackPanel(
                                        snapshot: snapshot,
                                        onAcknowledge: (id) {
                                          _runtime?.updateAttentionFocus(
                                            selectedAircraftId:
                                                _selectedAircraftId,
                                            selectedAlertId: id,
                                          );
                                          _runtime?.alertManager
                                              .acknowledge(id);
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    if (!widget.betaMode ||
                                        widget.showDebugOverlays) ...[
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: _WorkloadOverlay(
                                            snapshot: snapshot),
                                      ),
                                      Positioned(
                                        top: 112,
                                        right: 8,
                                        child: _AttentionOverlay(
                                            snapshot: snapshot),
                                      ),
                                      Positioned(
                                        top: 218,
                                        right: 8,
                                        child: _PsychologyOverlay(
                                            snapshot: snapshot),
                                      ),
                                    ],
                                  ],
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
              scenarioDisplayTitle:
                  widget.trainingScenarioTitle ?? _scenarioName,
              scenarioNames:
                  _availableScenarioAssets.keys.toList(growable: false),
              betaMode: widget.betaMode,
              onPauseChanged: (value) => setState(() => _paused = value),
              onSpeedChanged: (value) => setState(() => _speed = value),
              onSweepChanged: (value) => setState(() => _sweepEnabled = value),
              onStep: _stepScenario,
              onScenarioChanged: (value) {
                if (value != null) _loadScenario(value);
              },
              onRestart: _restartScenario,
              onViewResult:
                  widget.betaMode ? () => _openTrainingResult() : null,
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
                onDirect: _commandDirect,
              onHold: _commandHold,
                onIssueChain: _issueCommandChain,
                waypointIds: snapshot.waypoints.keys.toList(growable: false),
                commandWorkflowEntries: _selectedAircraftId == null
                  ? const []
                  : _commandWorkflow.entriesForAircraft(_selectedAircraftId!),
                activeWorkflowEntries: _selectedAircraftId == null
                  ? const []
                  : _commandWorkflow
                    .activeRestrictionsForAircraft(_selectedAircraftId!),
                replayCommandInsights:
                  _commandWorkflow.replayInsights(snapshot.events),
              reviewEventLabel: _reviewEventLabel,
              recentlyAcknowledgedAircraftId: _recentlyAcknowledgedAircraftId,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _commandHighlightTimer?.cancel();
    _ackHighlightTimer?.cancel();
    _audioController.dispose();
    _cuePlayer.dispose();
    _cuePlayerAlt.dispose();
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
  final String scenarioDisplayTitle;
  final List<String> scenarioNames;
  final bool betaMode;
  final ValueChanged<bool> onPauseChanged;
  final ValueChanged<int> onSpeedChanged;
  final ValueChanged<bool> onSweepChanged;
  final VoidCallback onStep;
  final ValueChanged<String?> onScenarioChanged;
  final VoidCallback onRestart;
  final VoidCallback onReturnToLive;
  final ValueChanged<SimulationEvent> onEventSelected;
  final VoidCallback? onViewResult;
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
  final void Function(AircraftState aircraft, String waypointId) onDirect;
  final void Function(AircraftState aircraft) onHold;
  final void Function(
    AircraftState aircraft,
    List<ControllerCommand> commands,
    String summary,
  ) onIssueChain;
  final List<String> waypointIds;
  final List<CommandWorkflowEntry> commandWorkflowEntries;
  final List<CommandWorkflowEntry> activeWorkflowEntries;
  final List<ReplayCommandInsight> replayCommandInsights;
  final String? reviewEventLabel;
  final String? recentlyAcknowledgedAircraftId;

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
    required this.scenarioDisplayTitle,
    required this.scenarioNames,
    required this.betaMode,
    required this.onPauseChanged,
    required this.onSpeedChanged,
    required this.onSweepChanged,
    required this.onStep,
    required this.onScenarioChanged,
    required this.onRestart,
    required this.onReturnToLive,
    required this.onEventSelected,
    required this.onViewResult,
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
    required this.onDirect,
    required this.onHold,
    required this.onIssueChain,
    required this.waypointIds,
    required this.commandWorkflowEntries,
    required this.activeWorkflowEntries,
    required this.replayCommandInsights,
    required this.reviewEventLabel,
    required this.recentlyAcknowledgedAircraftId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeHeavy = snapshot.aircraft.where((item) {
      return item.active && item.performanceType.name == 'heavy';
    }).length;
    final scenarioHeavy = runtime.definition.aircraft.where((spawn) {
      return spawn.initialState.performanceType.name == 'heavy';
    }).length;
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
                  child: betaMode
                      ? Text(
                          scenarioDisplayTitle,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : DropdownButton<String>(
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
                  tooltip: l10n.radarTrainingRestartScenario,
                  onPressed: onRestart,
                  icon: const Icon(Icons.restart_alt),
                ),
                if (reviewingReplay)
                  IconButton(
                    tooltip: l10n.radarTrainingReturnToLive,
                    onPressed: onReturnToLive,
                    icon: const Icon(Icons.sensors),
                  ),
                IconButton(
                  tooltip: paused
                      ? l10n.radarTrainingResume
                      : l10n.radarTrainingPause,
                  onPressed:
                      scenarioStarted ? () => onPauseChanged(!paused) : null,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                ),
                if (!betaMode)
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
                  'Pressure ${snapshot.sectorPressureIndex.toStringAsFixed(1)}  '
                  'Heavy $activeHeavy/$scenarioHeavy',
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
                if (!betaMode)
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
                      ? (scenarioState.failed
                          ? l10n.radarTrainingStatusFailed
                          : l10n.radarTrainingStatusComplete)
                      : l10n.radarTrainingStatusRunning,
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
              if (onViewResult != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onViewResult,
                    icon: const Icon(Icons.assessment),
                    label: Text(l10n.radarTrainingViewResults),
                  ),
                ),
              ],
            ],
            if (!betaMode && snapshot.events.isNotEmpty) ...[
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
            if (!betaMode && replayCommandInsights.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ReplayCommandInsightPanel(
                insights: replayCommandInsights,
                events: snapshot.events,
                realismAnnotation: _pilotRealismAnnotation(runtime),
              ),
            ],
            if (!betaMode &&
                snapshot.events.any((event) =>
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
            if (!betaMode && snapshot.arrivalFlows.isNotEmpty) ...[
              const SizedBox(height: 10),
              _OperationalTrendPanel(snapshot: snapshot),
            ],
            if (!betaMode && snapshot.arrivalFlows.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ArrivalFlowPanel(snapshot: snapshot),
            ],
            if (selectedAircraft != null) ...[
              const SizedBox(height: 10),
              _SelectedAircraftPanel(
                aircraft: selectedAircraft!,
                waypointIds: waypointIds,
                onHeading: onHeading,
                onAltitude: onAltitude,
                onSpeed: onSpeed,
                onDirect: onDirect,
                onHold: onHold,
                onIssueChain: onIssueChain,
                workflowEntries: commandWorkflowEntries,
                activeRestrictions: activeWorkflowEntries,
                recentlyAcknowledged:
                    recentlyAcknowledgedAircraftId == selectedAircraft!.id,
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
            '${AppLocalizations.of(context)!.radarTrainingReviewLabel}: $reviewEventLabel',
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
    final l10n = AppLocalizations.of(context)!;
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
      if (selectedAircraftId != null &&
          event.aircraftId != selectedAircraftId) {
        return false;
      }
      if (selectedType == 'all') return true;
      return _commandTypeToken(event.label) == selectedType;
    }).toList(growable: false);

    final visible =
        filtered.length > 6 ? filtered.sublist(filtered.length - 6) : filtered;

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
          Text(
            l10n.radarTrainingCommandReview,
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
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.radarTrainingAllAircraft),
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
                  items: [
                    DropdownMenuItem(
                        value: 'all', child: Text(l10n.radarTrainingAllTypes)),
                    DropdownMenuItem(
                        value: 'heading', child: Text(l10n.radarTechHeading)),
                    DropdownMenuItem(
                        value: 'speed', child: Text(l10n.radarTechSpeed)),
                    DropdownMenuItem(
                        value: 'altitude', child: Text(l10n.radarTechAltitude)),
                    DropdownMenuItem(
                        value: 'direct',
                        child: Text(l10n.radarTrainingCommandTypeDirect)),
                    DropdownMenuItem(
                        value: 'hold',
                        child: Text(l10n.radarTrainingCommandTypeHold)),
                    DropdownMenuItem(
                        value: 'other',
                        child: Text(l10n.radarTrainingCommandTypeOther)),
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
            Text(
              l10n.radarTrainingNoCommandEventsForFilter,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                        tooltip: l10n.radarTrainingJumpPairedCommand,
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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.radarTrainingIssuedShort,
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
                  l10n.radarTrainingAckShort,
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
    final x =
        ((event.elapsed.inSeconds - minSeconds) / span).clamp(0, 1).toDouble() *
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
    return occupied == 0 ? ('flowing', false) : ('$occupied blocked', true);
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
    final l10n = AppLocalizations.of(context)!;
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
                    title: l10n.radarTrainingObjective,
                    items: definition.objectives),
                const SizedBox(height: 12),
                _BriefingSection(
                  title: l10n.radarTrainingExpectedTechnique,
                  items: definition.expectedTechniques,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.radarTrainingStartScenario),
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

class _RadarRangeControls extends StatelessWidget {
  final double rangeNm;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _RadarRangeControls({
    required this.rangeNm,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD904111B),
        border: Border.all(color: const Color(0x5546F5A7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Range ${rangeNm.round()} NM',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            _RangeButton(
              icon: Icons.remove,
              onPressed: canZoomOut ? onZoomOut : null,
            ),
            _RangeButton(
              icon: Icons.add,
              onPressed: canZoomIn ? onZoomIn : null,
            ),
            _RangeButton(
              icon: Icons.center_focus_strong,
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _RangeButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: 17,
        color: AppTheme.primary,
        disabledColor: AppTheme.textSecondary.withValues(alpha: 0.35),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
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
    final l10n = AppLocalizations.of(context)!;
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
            failed
                ? l10n.radarTrainingCompletionScenarioFailed
                : l10n.radarTrainingCompletionScenarioComplete,
            style: TextStyle(
              color: failed ? AppTheme.danger : AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.radarTrainingCompletionGrade(
              score.grade,
              score.score,
              score.separationLossCount,
              score.commandCount,
            ),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.radarTrainingCompletionEfficiency(
              _efficiencyLabel(l10n, score),
            ),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.radarTrainingCompletionSubscores(
              score.spacingStability.toStringAsFixed(0),
              score.throughputEfficiency.toStringAsFixed(0),
              score.weatherManagement.toStringAsFixed(0),
              score.commandEfficiency.toStringAsFixed(0),
            ),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (score.penalties.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.radarTrainingTimelineSummary,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            for (final penalty in score.penalties.take(4))
              Text(
                _localizePenalty(l10n, penalty),
                style: const TextStyle(color: AppTheme.warning, fontSize: 11),
              ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reasons.map((r) => _localizeReason(l10n, r)).join(' / '),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _efficiencyLabel(AppLocalizations l10n, RadarV2ScoreSnapshot score) {
    if (score.isEfficiencyExcellent) return l10n.radarTrainingEfficiencyExcellent;
    if (score.isEfficiencyGood) return l10n.radarTrainingEfficiencyGood;
    if (score.isEfficiencyBusy) return l10n.radarTrainingEfficiencyBusy;
    return l10n.radarTrainingEfficiencyOverControlled;
  }

  String _localizePenalty(AppLocalizations l10n, String penalty) {
    final match = RegExp(r'^([+-]\d+)\s+(.+)$').firstMatch(penalty.trim());
    if (match == null) return penalty;
    final prefix = match.group(1)!;
    final reason = match.group(2)!;
    return '$prefix ${RadarTrainingTextLocalizer.line(l10n, reason)}';
  }

  String _localizeReason(AppLocalizations l10n, String reason) {
    return switch (reason) {
      'All aircraft spawned' => l10n.radarTrainingWinReasonAllSpawned,
      'Scenario duration reached' => l10n.radarTrainingWinReasonDurationReached,
      'No excessive separation losses' =>
        l10n.radarTrainingWinReasonNoExcessiveLosses,
      'All aircraft exited safely' => l10n.radarTrainingWinReasonAllExitedSafely,
      'Separation loss detected' => l10n.radarTrainingFailReasonSeparationLoss,
      'Scenario timed out before all traffic spawned' =>
        l10n.radarTrainingFailReasonTimeout,
      _ => RadarTrainingTextLocalizer.line(l10n, reason),
    };
  }
}

class _SelectedAircraftPanel extends StatelessWidget {
  final AircraftState aircraft;
  final List<String> waypointIds;
  final void Function(AircraftState aircraft, int deltaDeg) onHeading;
  final void Function(AircraftState aircraft, int deltaFt) onAltitude;
  final void Function(AircraftState aircraft, int deltaKt) onSpeed;
  final void Function(AircraftState aircraft, String waypointId) onDirect;
  final void Function(AircraftState aircraft) onHold;
  final void Function(
    AircraftState aircraft,
    List<ControllerCommand> commands,
    String summary,
  ) onIssueChain;
  final List<CommandWorkflowEntry> workflowEntries;
  final List<CommandWorkflowEntry> activeRestrictions;
  final bool recentlyAcknowledged;

  const _SelectedAircraftPanel({
    required this.aircraft,
    required this.waypointIds,
    required this.onHeading,
    required this.onAltitude,
    required this.onSpeed,
    required this.onDirect,
    required this.onHold,
    required this.onIssueChain,
    required this.workflowEntries,
    required this.activeRestrictions,
    required this.recentlyAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1723),
        border: Border.all(color: const Color(0x6646F5A7)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x2200B0FF), blurRadius: 16),
        ],
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
          if (recentlyAcknowledged) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x3346F5A7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xAA46F5A7)),
                ),
                child: const Text(
                  'ACK RECEIVED',
                  style: TextStyle(
                    color: Color(0xFF46F5A7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _pendingIntentText(aircraft),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in const [-30, -20, -10, 10, 20, 30])
                _PresetPill(
                  label: preset > 0 ? 'HDG +$preset' : 'HDG $preset',
                  onTap: () => onHeading(aircraft, preset),
                ),
              for (final preset in const [-40, -20, 20, 40])
                _PresetPill(
                  label: preset > 0 ? 'SPD +$preset' : 'SPD $preset',
                  onTap: () => onSpeed(aircraft, preset),
                ),
              for (final preset in const [-2000, -1000, 1000, 2000])
                _PresetPill(
                  label: preset > 0 ? 'ALT +${preset ~/ 100}' : 'ALT ${preset ~/ 100}',
                  onTap: () => onAltitude(aircraft, preset),
                ),
              for (final target in const [90, 180, 270, 360])
                _PresetPill(
                  label: 'VECTOR ${target.toString().padLeft(3, '0')}',
                  onTap: () => onHeading(
                    aircraft,
                    _deltaToHeading(aircraft.headingDeg, target.toDouble()),
                  ),
                ),
              if (waypointIds.isNotEmpty)
                _PresetPill(
                  label: 'DIRECT ${waypointIds.first}',
                  onTap: () => onDirect(aircraft, waypointIds.first),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CommandGroup(
                  label: 'HDG',
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
                  ],
                ),
                _CommandGroup(
                  label: 'ALT',
                  children: [
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
                  ],
                ),
                _CommandGroup(
                  label: 'SPD',
                  children: [
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
                  ],
                ),
                _CommandGroup(
                  label: 'FLOW',
                  children: [
                    _CommandButton(
                      icon:
                          aircraft.intent.hold ? Icons.play_arrow : Icons.loop,
                      label: aircraft.intent.hold ? 'EXIT HOLD' : 'HOLD',
                      onPressed: () => onHold(aircraft),
                    ),
                    if (waypointIds.isNotEmpty)
                      _CommandButton(
                        icon: Icons.call_split,
                        label: 'DIRECT',
                        onPressed: () => onDirect(aircraft, waypointIds.first),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChainButton(
                label: 'HDG+SPD',
                onPressed: () {
                  onIssueChain(
                    aircraft,
                    [
                      AssignHeading(
                        aircraftId: aircraft.id,
                        issuedAt: Duration.zero,
                        headingDeg: aircraft.headingDeg + 20,
                      ),
                      AssignSpeed(
                        aircraftId: aircraft.id,
                        issuedAt: Duration.zero,
                        speedKt: aircraft.groundSpeedKt - 20,
                      ),
                    ],
                    '${aircraft.callsign} HDG+SPD',
                  );
                },
              ),
              _ChainButton(
                label: 'VECTOR+ALT',
                onPressed: () {
                  onIssueChain(
                    aircraft,
                    [
                      AssignHeading(
                        aircraftId: aircraft.id,
                        issuedAt: Duration.zero,
                        headingDeg: aircraft.headingDeg + 20,
                      ),
                      AssignAltitude(
                        aircraftId: aircraft.id,
                        issuedAt: Duration.zero,
                        altitudeFt: aircraft.altitudeFt - 1000,
                      ),
                    ],
                    '${aircraft.callsign} VECTOR+ALT',
                  );
                },
              ),
              if (waypointIds.isNotEmpty)
                _ChainButton(
                  label: 'DES+DIRECT',
                  onPressed: () {
                    onIssueChain(
                      aircraft,
                      [
                        AssignAltitude(
                          aircraftId: aircraft.id,
                          issuedAt: Duration.zero,
                          altitudeFt: aircraft.altitudeFt - 1000,
                        ),
                        DirectToWaypoint(
                          aircraftId: aircraft.id,
                          issuedAt: Duration.zero,
                          waypointId: waypointIds.first,
                        ),
                      ],
                      '${aircraft.callsign} DES+DIRECT ${waypointIds.first}',
                    );
                  },
                ),
            ],
          ),
          if (activeRestrictions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACTIVE RESTRICTIONS',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in activeRestrictions.take(4))
                  _WorkflowChip(entry: entry),
              ],
            ),
          ],
          if (workflowEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RECENT COMMANDS',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final entry in workflowEntries.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.commandType.toUpperCase()} ${entry.label}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _WorkflowChip(entry: entry),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  int _deltaToHeading(double current, double target) {
    final normalizedCurrent = current % 360;
    final raw = (target - normalizedCurrent + 540) % 360 - 180;
    return raw.round();
  }

  String _pendingIntentText(AircraftState aircraft) {
    final parts = <String>[];
    final intent = aircraft.intent;
    if (intent.assignedHeadingDeg != null) {
      parts.add('HDG ${intent.assignedHeadingDeg!.round().toString().padLeft(3, '0')}');
    }
    if (intent.assignedAltitudeFt != null) {
      parts.add('ALT ${intent.assignedAltitudeFt! ~/ 100}');
    }
    if (intent.assignedSpeedKt != null) {
      parts.add('SPD ${intent.assignedSpeedKt!.round()}');
    }
    if (intent.directToWaypointId != null) {
      parts.add('DIRECT ${intent.directToWaypointId}');
    }
    if (intent.hold) {
      parts.add('HOLD ${intent.holdPatternId ?? ''}'.trim());
    }
    if (parts.isEmpty) {
      return 'Pending Intentions: none';
    }
    return 'Pending Intentions: ${parts.join(' | ')}';
  }
}

class _PresetPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x2026B6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x5555D6BE)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChainButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ChainButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.link, size: 14),
      label: Text(label),
    );
  }
}

class _WorkflowChip extends StatelessWidget {
  final CommandWorkflowEntry entry;

  const _WorkflowChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entry.status) {
      CommandWorkflowStatus.sent => ('SENT', const Color(0xFF62D2FF)),
      CommandWorkflowStatus.awaitingAcknowledgement =>
        ('AWAIT', const Color(0xFFFFD166)),
      CommandWorkflowStatus.acknowledged =>
        ('ACK', const Color(0xFF46F5A7)),
      CommandWorkflowStatus.completed =>
        ('DONE', const Color(0xFF8BC34A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReplayCommandInsightPanel extends StatelessWidget {
  final List<ReplayCommandInsight> insights;
  final List<SimulationEvent> events;
  final String realismAnnotation;

  const _ReplayCommandInsightPanel({
    required this.insights,
    required this.events,
    required this.realismAnnotation,
  });

  @override
  Widget build(BuildContext context) {
    final visible = insights.length > 5
        ? insights.sublist(insights.length - 5)
        : insights;
    final wakeEvents = events.where((event) {
      return event.type == 'wakeSpacingCompression' ||
          event.type == 'wakeTurnStabilizationDelay' ||
          event.type == 'wakeSpeedInstability' ||
          event.type == 'wakeTurbulenceWobble' ||
          event.type == 'wakeSequencingPressure';
    }).toList(growable: false);
    final wakeCompressionCount =
        wakeEvents.where((event) => event.type == 'wakeSpacingCompression').length;
    final wakeTurnDelayCount = wakeEvents
        .where((event) => event.type == 'wakeTurnStabilizationDelay')
        .length;
    final wakeSpeedInstabilityCount =
        wakeEvents.where((event) => event.type == 'wakeSpeedInstability').length;
    final wakeWobbleCount =
        wakeEvents.where((event) => event.type == 'wakeTurbulenceWobble').length;
    final wakeSequencingCount =
        wakeEvents.where((event) => event.type == 'wakeSequencingPressure').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF07131C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Replay Command Timing',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            realismAnnotation,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
            ),
          ),
          if (wakeEvents.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Wake Ecology ${wakeEvents.length} events  '
              'C$wakeCompressionCount T$wakeTurnDelayCount '
              'S$wakeSpeedInstabilityCount W$wakeWobbleCount '
              'P$wakeSequencingCount  '
              'Peak ${_topWakeWindowsLabel(wakeEvents)}',
              style: const TextStyle(
                color: AppTheme.warning,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          for (final insight in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${insight.aircraftId} ${insight.commandType.toUpperCase()} '
                    'delay ${insight.acknowledgementDelay.inSeconds}s '
                    '${insight.delayed ? 'DELAYED' : 'ON-TIME'} '
                    '${insight.interrupted ? 'INTERRUPTED' : 'CLEAR'}',
                    style: TextStyle(
                      color: insight.interrupted
                          ? AppTheme.warning
                          : AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  if (insight.causes.isNotEmpty)
                    Text(
                      'Cause: ${insight.causes.join(', ')}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  if (insight.spacingImpact != null)
                    Text(
                      insight.spacingImpact!,
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _topWakeWindowsLabel(List<SimulationEvent> wakeEvents) {
    const windowSeconds = 20;
    final buckets = <int, int>{};
    for (final event in wakeEvents) {
      final bucket = event.elapsed.inSeconds ~/ windowSeconds;
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    final ranked = buckets.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    final top = ranked.take(2);
    return top.map((entry) {
      final start = entry.key * windowSeconds;
      final end = start + windowSeconds - 1;
      return '${start}s-${end}s (${entry.value})';
    }).join(', ');
  }
}

extension on _DebugControls {
  String _pilotRealismAnnotation(ScenarioRuntime runtime) {
    final profile = runtime.engine.pilotRealismProfile;
    final definition = runtime.definition;
    final weatherTag = definition.weatherMode == 'low_visibility' ||
            definition.weatherZones.length >= 2
        ? 'weather-heavy'
        : 'weather-light';
    final trafficTag = definition.densityScale >= 1.2 ||
            definition.workloadPressureMultiplier >= 1.15
        ? 'traffic-dense'
        : 'traffic-normal';
    return 'Active Pilot Realism: D${definition.difficulty} '
        '$weatherTag/$trafficTag '
        'ACK x${profile.acknowledgementDelayScale.toStringAsFixed(2)} '
        'EXEC x${profile.executionDelayScale.toStringAsFixed(2)} '
        'VAR x${profile.variabilityChanceScale.toStringAsFixed(2)} '
        'WX x${profile.weatherImpactScale.toStringAsFixed(2)} '
        'WL x${profile.workloadImpactScale.toStringAsFixed(2)}';
  }
}

class _QuickCommandRadialMenu extends StatefulWidget {
  final AircraftState aircraft;
  final List<String> waypointIds;
  final ValueChanged<int> onHeadingDelta;
  final ValueChanged<int> onSpeedDelta;
  final ValueChanged<int> onAltitudeDelta;
  final ValueChanged<String> onDirect;
  final VoidCallback onHold;
  final VoidCallback onHeadingAndSpeed;
  final ValueChanged<String> onDescendAndDirect;
  final VoidCallback onVectorAndAltitude;

  const _QuickCommandRadialMenu({
    required this.aircraft,
    required this.waypointIds,
    required this.onHeadingDelta,
    required this.onSpeedDelta,
    required this.onAltitudeDelta,
    required this.onDirect,
    required this.onHold,
    required this.onHeadingAndSpeed,
    required this.onDescendAndDirect,
    required this.onVectorAndAltitude,
  });

  @override
  State<_QuickCommandRadialMenu> createState() =>
      _QuickCommandRadialMenuState();
}

class _QuickCommandRadialMenuState extends State<_QuickCommandRadialMenu> {
  int? _hoveredIndex;
  bool _dragging = false;

  static const double _wheelSize = 284;
  static const double _innerRadius = 44;
  static const double _outerRadius = 132;
  static const double _arcStart = -math.pi * 0.2;
  static const double _arcSweep = math.pi * 1.4;

  List<_RadialCommandEntry> _entries() {
    final phase = _phaseFor(widget.aircraft);
    final entries = <_RadialCommandEntry>[
      _RadialCommandEntry(
        key: 'left20',
        icon: Icons.rotate_left,
        label: 'L20',
        onSelected: () => widget.onHeadingDelta(-20),
      ),
      _RadialCommandEntry(
        key: 'right20',
        icon: Icons.rotate_right,
        label: 'R20',
        onSelected: () => widget.onHeadingDelta(20),
      ),
      _RadialCommandEntry(
        key: 'desc10',
        icon: Icons.arrow_downward,
        label: 'DESC 10',
        onSelected: () => widget.onAltitudeDelta(-1000),
      ),
      _RadialCommandEntry(
        key: 'clb10',
        icon: Icons.arrow_upward,
        label: 'CLB 10',
        onSelected: () => widget.onAltitudeDelta(1000),
      ),
      _RadialCommandEntry(
        key: 'spdDown20',
        icon: Icons.remove,
        label: 'SPD -20',
        onSelected: () => widget.onSpeedDelta(-20),
      ),
      _RadialCommandEntry(
        key: 'spdUp20',
        icon: Icons.add,
        label: 'SPD +20',
        onSelected: () => widget.onSpeedDelta(20),
      ),
      _RadialCommandEntry(
        key: 'hdgSpd',
        icon: Icons.link,
        label: 'HDG+SPD',
        onSelected: widget.onHeadingAndSpeed,
      ),
      _RadialCommandEntry(
        key: 'vectorAlt',
        icon: Icons.alt_route,
        label: 'VECTOR+ALT',
        onSelected: widget.onVectorAndAltitude,
      ),
      _RadialCommandEntry(
        key: 'hold',
        icon: widget.aircraft.intent.hold ? Icons.play_arrow : Icons.loop,
        label: widget.aircraft.intent.hold ? 'EXIT HOLD' : 'HOLD',
        onSelected: widget.onHold,
      ),
    ];

    if (widget.waypointIds.isNotEmpty) {
      entries.add(
        _RadialCommandEntry(
          key: 'direct',
          icon: Icons.call_made,
          label: 'DIRECT ${widget.waypointIds.first}',
          onSelected: () => widget.onDirect(widget.waypointIds.first),
        ),
      );
      entries.add(
        _RadialCommandEntry(
          key: 'desDirect',
          icon: Icons.trending_down,
          label: 'DES+DIRECT',
          onSelected: () => widget.onDescendAndDirect(widget.waypointIds.first),
        ),
      );
    }

    entries.sort((a, b) {
      final pa = _weightFor(a.key, phase);
      final pb = _weightFor(b.key, phase);
      final compare = pb.compareTo(pa);
      if (compare != 0) return compare;
      return a.label.compareTo(b.label);
    });

    return entries;
  }

  _OperationalPhase _phaseFor(AircraftState aircraft) {
    if (aircraft.intent.hold) return _OperationalPhase.hold;
    if (aircraft.intent.isDeparture) return _OperationalPhase.departure;
    if (aircraft.intent.assignedRunwayId != null || aircraft.altitudeFt < 14000) {
      return _OperationalPhase.arrival;
    }
    return _OperationalPhase.enroute;
  }

  double _weightFor(String key, _OperationalPhase phase) {
    switch (phase) {
      case _OperationalPhase.arrival:
        return switch (key) {
          'desDirect' => 1.8,
          'direct' => 1.6,
          'desc10' => 1.6,
          'spdDown20' => 1.45,
          'vectorAlt' => 1.35,
          'left20' || 'right20' => 1.1,
          'hold' => 1.0,
          'hdgSpd' => 0.95,
          'clb10' => 0.75,
          'spdUp20' => 0.8,
          _ => 1.0,
        };
      case _OperationalPhase.departure:
        return switch (key) {
          'clb10' => 1.7,
          'spdUp20' => 1.6,
          'left20' || 'right20' => 1.45,
          'hdgSpd' => 1.4,
          'vectorAlt' => 1.2,
          'hold' => 0.9,
          'direct' => 0.85,
          'desDirect' => 0.65,
          'desc10' => 0.7,
          'spdDown20' => 0.8,
          _ => 1.0,
        };
      case _OperationalPhase.hold:
        return switch (key) {
          'hold' => 2.0,
          'spdDown20' => 1.3,
          'left20' || 'right20' => 1.2,
          'desc10' => 1.15,
          'vectorAlt' => 1.0,
          'direct' || 'desDirect' => 0.7,
          _ => 0.9,
        };
      case _OperationalPhase.enroute:
        return switch (key) {
          'hdgSpd' => 1.35,
          'vectorAlt' => 1.3,
          'left20' || 'right20' => 1.25,
          'spdDown20' || 'spdUp20' => 1.1,
          'direct' => 1.1,
          'desc10' || 'clb10' => 0.95,
          _ => 0.95,
        };
    }
  }

  List<_RadialSlice> _slicesFor(List<_RadialCommandEntry> entries) {
    final phase = _phaseFor(widget.aircraft);
    final weights = [
      for (final entry in entries) _weightFor(entry.key, phase),
    ];
    final total = weights.fold<double>(0, (sum, weight) => sum + weight);
    final slices = <_RadialSlice>[];
    var cursor = _arcStart;
    for (var i = 0; i < entries.length; i++) {
      final sweep = _arcSweep * (weights[i] / total);
      slices.add(_RadialSlice(index: i, start: cursor, sweep: sweep));
      cursor += sweep;
    }
    return slices;
  }

  int? _indexFromLocal(Offset local, List<_RadialSlice> slices) {
    final center = const Offset(_wheelSize / 2, _wheelSize / 2);
    final delta = local - center;
    final distance = delta.distance;
    if (distance < _innerRadius || distance > _outerRadius) {
      return null;
    }
    final angle = _normalizeAngle(math.atan2(delta.dy, delta.dx));
    final relative = _normalizeAngle(angle - _arcStart);
    if (relative > _arcSweep) return null;
    for (final slice in slices) {
      final start = _normalizeAngle(slice.start - _arcStart);
      final end = start + slice.sweep;
      if (relative >= start && relative <= end) {
        return slice.index;
      }
    }
    return null;
  }

  double _normalizeAngle(double angle) {
    final full = math.pi * 2;
    final value = angle % full;
    return value < 0 ? value + full : value;
  }

  void _applySelected(List<_RadialCommandEntry> entries) {
    final index = _hoveredIndex;
    if (index == null || index < 0 || index >= entries.length) {
      Navigator.of(context).pop();
      return;
    }
    entries[index].onSelected();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final slices = _slicesFor(entries);
    final phase = _phaseFor(widget.aircraft);
    final selectedLabel = _hoveredIndex == null
        ? 'Drag on wheel, release to issue command'
        : 'Selected: ${entries[_hoveredIndex!].label}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.aircraft.callsign} RADIAL COMMAND',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Phase priority: ${phase.name.toUpperCase()}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              selectedLabel,
              style: TextStyle(
                color: _hoveredIndex == null
                    ? AppTheme.textSecondary
                    : AppTheme.primary,
                fontSize: 11,
                fontWeight: _hoveredIndex == null ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    _dragging = true;
                    _hoveredIndex = _indexFromLocal(details.localPosition, slices);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _hoveredIndex = _indexFromLocal(details.localPosition, slices);
                  });
                },
                onPanEnd: (_) {
                  _applySelected(entries);
                },
                onPanCancel: () {
                  setState(() {
                    _dragging = false;
                    _hoveredIndex = null;
                  });
                },
                child: SizedBox(
                  width: _wheelSize,
                  height: _wheelSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(_wheelSize, _wheelSize),
                        painter: _RadialCommandWheelPainter(
                          slices: slices,
                          highlightedIndex: _hoveredIndex,
                          arcStart: _arcStart,
                          arcSweep: _arcSweep,
                        ),
                      ),
                      for (var i = 0; i < entries.length; i++)
                        _RadialActionBadge(
                          slice: slices[i],
                          radius: 96,
                          icon: entries[i].icon,
                          label: entries[i].label,
                          highlighted: _hoveredIndex == i,
                        ),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: const Color(0xCC041018),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x7755D6BE)),
                        ),
                        child: Center(
                          child: Text(
                            _dragging ? 'RELEASE' : 'HOLD',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialCommandEntry {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  const _RadialCommandEntry({
    required this.key,
    required this.icon,
    required this.label,
    required this.onSelected,
  });
}

class _RadialCommandWheelPainter extends CustomPainter {
  final List<_RadialSlice> slices;
  final int? highlightedIndex;
  final double arcStart;
  final double arcSweep;

  const _RadialCommandWheelPainter({
    required this.slices,
    required this.highlightedIndex,
    required this.arcStart,
    required this.arcSweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const inner = 44.0;
    const outer = 132.0;

    final guardPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: outer + 1), arcStart, arcSweep);
    canvas.drawPath(
      guardPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x3362D2FF),
    );

    for (final slice in slices) {
      final i = slice.index;
      final start = slice.start;
      final sweep = slice.sweep;
      final path = Path()
        ..moveTo(
          center.dx + inner * math.cos(start),
          center.dy + inner * math.sin(start),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: outer),
          start,
          sweep,
          false,
        )
        ..lineTo(
          center.dx + inner * math.cos(start + sweep),
          center.dy + inner * math.sin(start + sweep),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: inner),
          start + sweep,
          -sweep,
          false,
        )
        ..close();

      final highlighted = highlightedIndex == i;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = highlighted
              ? const Color(0x4446F5A7)
              : const Color(0x1A62D2FF),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlighted ? 1.6 : 1.0
          ..color = highlighted
              ? const Color(0xFF46F5A7)
              : const Color(0x6655D6BE),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialCommandWheelPainter oldDelegate) {
    if (oldDelegate.slices.length != slices.length ||
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.arcStart != arcStart ||
        oldDelegate.arcSweep != arcSweep) {
      return true;
    }
    for (var i = 0; i < slices.length; i++) {
      final previous = oldDelegate.slices[i];
      final current = slices[i];
      if (previous.index != current.index ||
          previous.start != current.start ||
          previous.sweep != current.sweep) {
        return true;
      }
    }
    return false;
  }
}

class _RadialActionBadge extends StatelessWidget {
  final _RadialSlice slice;
  final double radius;
  final IconData icon;
  final String label;
  final bool highlighted;

  const _RadialActionBadge({
    required this.slice,
    required this.radius,
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final angle = slice.start + (slice.sweep / 2);
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xAA0A2333)
              : const Color(0xAA07131C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF46F5A7)
                : const Color(0x8855D6BE),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: highlighted ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    highlighted ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialSlice {
  final int index;
  final double start;
  final double sweep;

  const _RadialSlice({
    required this.index,
    required this.start,
    required this.sweep,
  });
}

enum _OperationalPhase {
  arrival,
  departure,
  hold,
  enroute,
}

class _CommandGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _CommandGroup({
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(6, 4, 3, 4),
      decoration: BoxDecoration(
        color: const Color(0x1800B0FF),
        border: Border.all(color: const Color(0x3355D6BE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Row(children: children),
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
          height: 48,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppTheme.primary,
              backgroundColor: const Color(0xFF07131C),
              side: const BorderSide(color: Color(0x6655D6BE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }
}

// ── Decision Pressure Engine V1 — Workload Overlay ─────────────────────────

/// Debug overlay that shows the current cognitive load state and top alerts.
/// Visible only in [kDebugMode]; zero overhead in production.
class _WorkloadOverlay extends StatelessWidget {
  const _WorkloadOverlay({required this.snapshot});

  final SimulationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final load = snapshot.cognitiveLoad;
    final alerts = snapshot.operationalAlerts.take(3).toList();

    final levelColor = switch (load.currentLevel) {
      CognitiveLoadLevel.calm => const Color(0xFF4CAF50),
      CognitiveLoadLevel.busy => const Color(0xFFFFEB3B),
      CognitiveLoadLevel.overloaded => const Color(0xFFFF9800),
      CognitiveLoadLevel.saturated => const Color(0xFFF44336),
    };
    final levelLabel = switch (load.currentLevel) {
      CognitiveLoadLevel.calm => 'CALM',
      CognitiveLoadLevel.busy => 'BUSY',
      CognitiveLoadLevel.overloaded => 'OVERLOADED',
      CognitiveLoadLevel.saturated => 'SATURATED',
    };

    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: levelColor.withOpacity(0.6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Level badge + score
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: levelColor),
                  ),
                  child: Text(
                    levelLabel,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  load.totalLoadScore.toStringAsFixed(1),
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '/10',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0x33FFFFFF)),
              const SizedBox(height: 4),
              // Alert count summary
              Text(
                '${snapshot.operationalAlerts.length} alert${snapshot.operationalAlerts.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              for (final alert in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _priorityColor(alert.priority.name),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          alert.type.replaceAll('_', ' ').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _priorityColor(String priorityName) => switch (priorityName) {
        'critical' => const Color(0xFFF44336),
        'high' => const Color(0xFFFF9800),
        'medium' => const Color(0xFFFFEB3B),
        _ => const Color(0xFF9E9E9E),
      };
}

class _OperationalAtmosphereStrip extends StatelessWidget {
  final SimulationSnapshot snapshot;
  final String sectorId;
  final String weatherMode;

  const _OperationalAtmosphereStrip({
    required this.snapshot,
    required this.sectorId,
    required this.weatherMode,
  });

  @override
  Widget build(BuildContext context) {
    final utc = DateTime.now().toUtc();
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    final activeWeather = snapshot.weatherZones
        .where((zone) => zone.severity >= 2)
        .map((zone) => zone.id)
        .toList();
    final weatherSummary = activeWeather.isEmpty
        ? weatherMode.toUpperCase()
        : '${weatherMode.toUpperCase()} ${activeWeather.join('/')}';

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xD00A141D),
          border: Border.all(color: const Color(0x5546F5A7)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 13, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              sectorId.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$hh:$mm:${ss}Z',
              style: const TextStyle(
                color: Color(0xFF62D2FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                weatherSummary,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransientStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TransientStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE0091620),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

class _AttentionOverlay extends StatelessWidget {
  const _AttentionOverlay({required this.snapshot});

  final SimulationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final attention = snapshot.attentionFocus;
    final topIgnored = attention.topIgnoredAlert;
    final borderColor = _riskColor(attention.riskLabel);
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor.withOpacity(0.65)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'ATTENTION',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  attention.riskLabel.toUpperCase(),
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Focus ${_shortFocus(attention.currentFocusTarget)} '
              '${attention.focusDuration.inSeconds}s',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              'Ignored ${attention.ignoredAlerts.length}  '
              'Compete ${attention.competingHighPriorityAlertCount}  '
              'Overload ${attention.overloadDuration.inSeconds}s',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 9,
              ),
            ),
            if (topIgnored != null) ...[
              const SizedBox(height: 4),
              Text(
                'Top ignored ${topIgnored.alertType.replaceAll('_', ' ')} '
                '${topIgnored.ignoredFor.inSeconds}s',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: topIgnored.isCritical
                      ? const Color(0xFFFF4D4D)
                      : const Color(0xFFFFD166),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _riskColor(String riskLabel) {
    if (riskLabel == 'critical fixation') return const Color(0xFFFF4D4D);
    if (riskLabel == 'tunnel vision') return const Color(0xFFFF9800);
    if (riskLabel == 'fixation risk') return const Color(0xFFFFD166);
    return const Color(0xFF46F5A7);
  }

  String _shortFocus(String? target) {
    if (target == null) return 'none';
    return target.replaceFirst(':', ' ');
  }
}

class _PsychologyOverlay extends StatelessWidget {
  const _PsychologyOverlay({required this.snapshot});

  final SimulationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final state = snapshot.psychologyState;
    final expectation = snapshot.expectationState;
    final color = _phaseColor(state.phaseLabel);
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'PSYCHOLOGY',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  state.phaseLabel.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              state.audioLayer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              'Density ${state.eventDensityFactor.toStringAsFixed(1)}  '
              'Alerts ${state.alertTimingFactor.toStringAsFixed(1)}  '
              'Spacing ${(state.spacingInstabilityProbability * 100).round()}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 9,
              ),
            ),
            if (state.deceptiveCalmActive ||
                state.escalationChainActive ||
                state.attentionTrapActive) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (state.deceptiveCalmActive) 'false stability',
                  if (state.escalationChainActive) 'chain',
                  if (state.attentionTrapActive) 'attention trap',
                ].join(' / '),
                style: TextStyle(
                  color: state.deceptiveCalmActive
                      ? const Color(0xFF62D2FF)
                      : const Color(0xFFFFD166),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 5),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  expectation.driftLabel.toUpperCase(),
                  style: TextStyle(
                    color: _driftColor(expectation.driftScore),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'SENS ${expectation.threatSensitivity.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (expectation.confirmationBiasActive ||
                expectation.falseRecoveryActive ||
                expectation.attentionAnchored) ...[
              const SizedBox(height: 3),
              Text(
                [
                  if (expectation.confirmationBiasActive) 'bias',
                  if (expectation.falseRecoveryActive) 'false recovery',
                  if (expectation.attentionAnchored) 'anchored',
                ].join(' / '),
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _phaseColor(String phase) {
    return switch (phase) {
      'calm' => const Color(0xFF46F5A7),
      'building' => const Color(0xFF62D2FF),
      'busy' => const Color(0xFFFFD166),
      'unstable' => const Color(0xFFFF9800),
      'overload' => const Color(0xFFFF4D4D),
      _ => const Color(0xFF9B8CFF),
    };
  }

  Color _driftColor(double driftScore) {
    if (driftScore >= 0.42) return const Color(0xFFFF4D4D);
    if (driftScore >= 0.24) return const Color(0xFFFFD166);
    return const Color(0xFF46F5A7);
  }
}

// ── Overload Response System UI ───────────────────────────────────────────────

/// Animated border pulse that intensifies with workload level.
/// Renders a coloured border overlay on the radar view — no layout disruption.
class _OverloadPulseEffect extends StatefulWidget {
  const _OverloadPulseEffect({
    required this.snapshot,
    required this.alertPulse,
  });

  final SimulationSnapshot snapshot;
  final bool alertPulse;

  @override
  State<_OverloadPulseEffect> createState() => _OverloadPulseEffectState();
}

class _OverloadPulseEffectState extends State<_OverloadPulseEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.snapshot.cognitiveLoad.currentLevel;
    if (level == CognitiveLoadLevel.calm) return const SizedBox.shrink();

    final (color, maxOpacity, speed) = switch (level) {
      CognitiveLoadLevel.busy => (
          const Color(0xFFFFEB3B),
          0.12,
          900,
        ),
      CognitiveLoadLevel.overloaded => (
          const Color(0xFFFF9800),
          0.22,
          600,
        ),
      CognitiveLoadLevel.saturated => (
          const Color(0xFFF44336),
          0.38,
          350,
        ),
      _ => (const Color(0xFFFFEB3B), 0.0, 900),
    };

    if (_controller.duration?.inMilliseconds != speed) {
      _controller.duration = Duration(milliseconds: speed);
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final opacity = maxOpacity * _pulse.value;
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withOpacity(opacity + 0.1),
                width: 3,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Scrollable panel showing all active operational alerts with priority badges
/// and escalation countdown timers. Sits to the left of the radar view.
class _AlertStackPanel extends StatelessWidget {
  const _AlertStackPanel({
    required this.snapshot,
    required this.onAcknowledge,
  });

  final SimulationSnapshot snapshot;
  final ValueChanged<String> onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final alerts = snapshot.attentionFocus.suppressLowPriorityAlerts
        ? snapshot.operationalAlerts
            .where((alert) =>
                alert.priority.name == 'critical' ||
                alert.priority.name == 'high')
            .toList(growable: false)
        : snapshot.operationalAlerts;
    if (alerts.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(
              children: [
                const Text(
                  'ALERTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: alerts.any((a) =>
                            a.priority.name == 'critical' && !a.acknowledged)
                        ? const Color(0xFFF44336).withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Alert list (max 6 visible)
          ...alerts.take(6).map(
                (alert) => _AlertRow(
                  alert: alert,
                  elapsed: snapshot.elapsed,
                  onAcknowledge: () => onAcknowledge(alert.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.alert,
    required this.elapsed,
    required this.onAcknowledge,
  });

  final OperationalAlert alert;
  final Duration elapsed;
  final VoidCallback onAcknowledge;

  static Color _priorityColor(String p) => switch (p) {
        'critical' => const Color(0xFFF44336),
        'high' => const Color(0xFFFF9800),
        'medium' => const Color(0xFFFFEB3B),
        _ => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(alert.priority.name);
    final age = elapsed - alert.createdAt;
    final ageStr =
        age.inSeconds < 60 ? '${age.inSeconds}s' : '${age.inMinutes}m';

    // Escalation countdown: show time to expiry if set
    String? countdownStr;
    if (alert.expiresAt != null) {
      final remaining = alert.expiresAt! - elapsed;
      if (remaining.isNegative) {
        countdownStr = 'EXP';
      } else {
        countdownStr = remaining.inSeconds < 60
            ? '${remaining.inSeconds}s'
            : '${remaining.inMinutes}m';
      }
    }

    return GestureDetector(
      onTap: alert.acknowledged ? null : onAcknowledge,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(alert.acknowledged ? 0.45 : 0.72),
          border: Border(
            left: BorderSide(color: color, width: 3),
            bottom: const BorderSide(color: Color(0x1AFFFFFF)),
            right: const BorderSide(color: Color(0x22FFFFFF)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.type.replaceAll('_', ' ').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: alert.acknowledged
                          ? Colors.white.withOpacity(0.45)
                          : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        alert.priority.label,
                        style: TextStyle(
                          color:
                              color.withOpacity(alert.acknowledged ? 0.4 : 1.0),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '  +$ageStr',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (countdownStr != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  countdownStr,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (!alert.acknowledged) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, color: color.withOpacity(0.6), size: 11),
            ],
          ],
        ),
      ),
    );
  }
}
