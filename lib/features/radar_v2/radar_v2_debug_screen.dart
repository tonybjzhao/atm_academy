import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'commands/controller_command.dart';
import 'models/aircraft_state.dart';
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

class _RadarV2DebugScreenState extends State<RadarV2DebugScreen> {
  static const Map<String, String> _scenarioAssets = {
    'Crossing Arrivals': 'assets/scenarios/v2/melbourne/crossing_arrivals.json',
    'Overtaking Traffic':
        'assets/scenarios/v2/melbourne/overtaking_traffic.json',
  };

  ScenarioRuntime? _runtime;
  SimulationSnapshot? _snapshot;
  RadarV2ScoreTracker _scoreTracker = RadarV2ScoreTracker();
  Timer? _timer;
  int _speed = 1;
  bool _paused = false;
  bool _alertPulse = false;
  String _scenarioName = 'Crossing Arrivals';
  String? _selectedAircraftId;
  String? _recentlyCommandedAircraftId;
  Timer? _commandHighlightTimer;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    assert(() {
      _loadScenario(_scenarioName);
      return true;
    }());
  }

  Future<void> _loadScenario(String scenarioName) async {
    try {
      final assetPath = _scenarioAssets[scenarioName]!;
      final definition = await const ScenarioAssetLoader().load(assetPath);
      if (!mounted) return;
      _timer?.cancel();
      _runtime = ScenarioRuntime(definition: definition);
      _scoreTracker = RadarV2ScoreTracker();
      _scenarioName = scenarioName;
      _selectedAircraftId = null;
      _recentlyCommandedAircraftId = null;
      _snapshot = _runtime!.tick();
      _scoreTracker.observe(_snapshot!);
      _timer =
          Timer.periodic(const Duration(milliseconds: 250), (_) => _onTimer());
      setState(() => _loadError = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  void _onTimer() {
    final runtime = _runtime;
    if (!mounted || runtime == null || _paused) return;
    setState(() {
      _snapshot = runtime.tick(speedMultiplier: _speed);
      _scoreTracker.observe(_snapshot!);
      _alertPulse = !_alertPulse;
    });
  }

  void _restartScenario() {
    _loadScenario(_scenarioName);
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

  double _normalizeHeading(double headingDeg) {
    final normalized = headingDeg % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

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
                  : snapshot == null
                      ? const Center(child: CircularProgressIndicator())
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
                                  rangeNm: _runtime!.definition.radarRangeNm,
                                  selectedAircraftId: _selectedAircraftId,
                                  recentlyCommandedAircraftId:
                                      _recentlyCommandedAircraftId,
                                  alertPulse: _alertPulse,
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
              runtime: _runtime!,
              score: _scoreTracker.snapshot,
              paused: _paused,
              speed: _speed,
              selectedAircraft: _selectedAircraftId == null
                  ? null
                  : snapshot.aircraftById(_selectedAircraftId!),
              scenarioName: _scenarioName,
              scenarioNames: _scenarioAssets.keys.toList(growable: false),
              onPauseChanged: (value) => setState(() => _paused = value),
              onSpeedChanged: (value) => setState(() => _speed = value),
              onScenarioChanged: (value) {
                if (value != null) _loadScenario(value);
              },
              onRestart: _restartScenario,
              onHeading: _commandHeading,
              onAltitude: _commandAltitude,
              onSpeed: _commandSpeed,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commandHighlightTimer?.cancel();
    super.dispose();
  }
}

class _DebugControls extends StatelessWidget {
  final SimulationSnapshot snapshot;
  final ScenarioRuntime runtime;
  final RadarV2ScoreSnapshot score;
  final bool paused;
  final int speed;
  final AircraftState? selectedAircraft;
  final String scenarioName;
  final List<String> scenarioNames;
  final ValueChanged<bool> onPauseChanged;
  final ValueChanged<int> onSpeedChanged;
  final ValueChanged<String?> onScenarioChanged;
  final VoidCallback onRestart;
  final void Function(AircraftState aircraft, int deltaDeg) onHeading;
  final void Function(AircraftState aircraft, int deltaFt) onAltitude;
  final void Function(AircraftState aircraft, int deltaKt) onSpeed;

  const _DebugControls({
    required this.snapshot,
    required this.runtime,
    required this.score,
    required this.paused,
    required this.speed,
    required this.selectedAircraft,
    required this.scenarioName,
    required this.scenarioNames,
    required this.onPauseChanged,
    required this.onSpeedChanged,
    required this.onScenarioChanged,
    required this.onRestart,
    required this.onHeading,
    required this.onAltitude,
    required this.onSpeed,
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
                IconButton(
                  tooltip: paused ? 'Resume' : 'Pause',
                  onPressed: () => onPauseChanged(!paused),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
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
                  '${snapshot.aircraft.where((item) => item.active).length} aircraft  $conflicts alerts  Score ${score.score}',
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
            if (selectedAircraft != null) ...[
              const SizedBox(height: 10),
              _SelectedAircraftPanel(
                aircraft: selectedAircraft!,
                onHeading: onHeading,
                onAltitude: onAltitude,
                onSpeed: onSpeed,
              ),
            ],
            if (score.penalties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  score.penalties.last,
                  style: const TextStyle(color: AppTheme.warning, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedAircraftPanel extends StatelessWidget {
  final AircraftState aircraft;
  final void Function(AircraftState aircraft, int deltaDeg) onHeading;
  final void Function(AircraftState aircraft, int deltaFt) onAltitude;
  final void Function(AircraftState aircraft, int deltaKt) onSpeed;

  const _SelectedAircraftPanel({
    required this.aircraft,
    required this.onHeading,
    required this.onAltitude,
    required this.onSpeed,
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
