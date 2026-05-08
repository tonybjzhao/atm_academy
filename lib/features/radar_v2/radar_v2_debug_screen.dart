import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/simulation_snapshot.dart';
import 'rendering/radar_v2_painter.dart';
import 'scenario/scenario_asset_loader.dart';
import 'scenario/scenario_runtime.dart';

class RadarV2DebugScreen extends StatefulWidget {
  const RadarV2DebugScreen({super.key});

  @override
  State<RadarV2DebugScreen> createState() => _RadarV2DebugScreenState();
}

class _RadarV2DebugScreenState extends State<RadarV2DebugScreen> {
  ScenarioRuntime? _runtime;
  SimulationSnapshot? _snapshot;
  Timer? _timer;
  int _speed = 1;
  bool _paused = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    assert(() {
      _loadScenario();
      return true;
    }());
  }

  Future<void> _loadScenario() async {
    try {
      final definition = await const ScenarioAssetLoader()
          .load('assets/scenarios/v2/melbourne/crossing_arrivals.json');
      if (!mounted) return;
      _runtime = ScenarioRuntime(definition: definition);
      _snapshot = _runtime!.tick();
      _timer =
          Timer.periodic(const Duration(milliseconds: 250), (_) => _onTimer());
      setState(() {});
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
    });
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
                      : CustomPaint(
                          painter: RadarV2Painter(snapshot: snapshot),
                          child: const SizedBox.expand(),
                        ),
            ),
          ),
          if (snapshot != null)
            _DebugControls(
              snapshot: snapshot,
              runtime: _runtime!,
              paused: _paused,
              speed: _speed,
              onPauseChanged: (value) => setState(() => _paused = value),
              onSpeedChanged: (value) => setState(() => _speed = value),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _DebugControls extends StatelessWidget {
  final SimulationSnapshot snapshot;
  final ScenarioRuntime runtime;
  final bool paused;
  final int speed;
  final ValueChanged<bool> onPauseChanged;
  final ValueChanged<int> onSpeedChanged;

  const _DebugControls({
    required this.snapshot,
    required this.runtime,
    required this.paused,
    required this.speed,
    required this.onPauseChanged,
    required this.onSpeedChanged,
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
                IconButton(
                  tooltip: paused ? 'Resume' : 'Pause',
                  onPressed: () => onPauseChanged(!paused),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                ),
                const SizedBox(width: 8),
                Text(
                  'T+${snapshot.elapsed.inSeconds}s  Tick ${snapshot.tick}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${snapshot.aircraft.length} aircraft  $conflicts alerts',
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
          ],
        ),
      ),
    );
  }
}
