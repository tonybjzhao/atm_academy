import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/models/scenario.dart';
import '../core/models/scenario_result.dart';
import '../core/theme/app_theme.dart';
import '../data/scenario_data.dart';
import '../l10n/app_localizations.dart';
import '../models/replay_data.dart';
import '../models/scenario_result.dart' as detailed;
import '../services/pilot_radio_audio_service.dart';
import '../services/progression_service.dart';
import '../services/radio_audio_settings_service.dart';
import '../services/scenario_engine.dart';
import '../services/scoring_engine.dart';
import '../widgets/pressure_bar.dart';
import '../widgets/radar_painter.dart';
import '../widgets/scenario_feedback_panel.dart';

class ScenarioTrainingScreen extends StatefulWidget {
  final int scenarioIndex;

  const ScenarioTrainingScreen({super.key, this.scenarioIndex = 0});

  @override
  State<ScenarioTrainingScreen> createState() => _ScenarioTrainingScreenState();
}

class _ScenarioTrainingScreenState extends State<ScenarioTrainingScreen>
    with SingleTickerProviderStateMixin {
  // ── Sweep ─────────────────────────────────────────────────────────────────
  late final AnimationController _sweepCtrl;
  double _sweepAngle = 0;

  // ── State ─────────────────────────────────────────────────────────────────
  late int _scenarioIndex;
  late ScenarioEngine _engine;
  bool _running = true;
  _ScreenState _screenState = _ScreenState.playing;

  int _timeLeft = 60;
  String? _selectedCallsign;
  bool _everSelected = false;

  // Per-command feedback (shown 2 s)
  String? _cmdFeedback;
  Timer? _feedbackTimer;

  ScenarioResult? _result;
  ScenarioReplayData? _replayData;
  detailed.DetailedScenarioResult? _detailedResult;
  DateTime? _scenarioStartedAt;
  int? _scoreDelta; // positive = improved, negative = regressed, null = first
  final PilotRadioAudioService _radioAudio = PilotRadioAudioService.instance;
  final RadioAudioSettingsService _audioSettings =
      RadioAudioSettingsService.instance;
  final Stopwatch _audioClock = Stopwatch();
  final List<ReplayPilotRadioCall> _pilotRadioEvents = <ReplayPilotRadioCall>[];
  final List<ReplayWarningCue> _warningAudioEvents = <ReplayWarningCue>[];
  bool _playedConflictWarning = false;
  bool _playedRunwayPressureWarning = false;
  bool _playedOverloadWarning = false;

  // Timers
  Timer? _countdownTimer;

  // ── Init ──────────────────────────────────────────────────────────────────
  Scenario get _scenario => allScenarios[_scenarioIndex];

  void _initScenario() {
    _engine = ScenarioEngine(_scenario);
    _timeLeft = _scenario.timeLimitSeconds;
    _selectedCallsign = null;
    _everSelected = false;
    _cmdFeedback = null;
    _result = null;
    _replayData = null;
    _detailedResult = null;
    _scoreDelta = null;
    _scenarioStartedAt = DateTime.now();
    _screenState = _ScreenState.playing;
    _audioClock
      ..reset()
      ..start();
    _pilotRadioEvents.clear();
    _warningAudioEvents.clear();
    _playedConflictWarning = false;
    _playedRunwayPressureWarning = false;
    _playedOverloadWarning = false;
  }

  void _startTimers() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _screenState != _ScreenState.playing) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endScenario(timedOut: true);
      });
    });
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    _scenarioIndex = widget.scenarioIndex;
    _initScenario();
    _audioSettings.ensureLoaded();
    _radioAudio.initialize();

    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() => setState(() => _sweepAngle += 0.018));
    _sweepCtrl.repeat();

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted || !_running) return false;
      if (_screenState == _ScreenState.playing) {
        setState(() {
          _engine.update(const Size(370, 430));
          // Check LOS end condition
          if (_engine.alertLevel == AlertLevel.los) {
            _endScenario(timedOut: false);
          }
          // Check success
          if (_engine.separationMaintained) {
            _endScenario(timedOut: false);
          }
        });
        _tickPlaybackWarnings();
      }
      return true;
    });

    _startTimers();
  }

  Future<void> _endScenario({required bool timedOut}) async {
    if (_screenState != _ScreenState.playing) return;
    _stopTimers();
    final result = _engine.finalize(_timeLeft);

    // Build replay data snapshot for optional 3D replay
    final cmdType = _engine.firstCommandType;
    final cmdCs = _engine.firstCommandCallsign;
    final cmdSummary = cmdCs.isEmpty
        ? 'No command issued'
        : '${_commandLabel(cmdType)} on $cmdCs';

    final replay = ScenarioReplayData(
      scenarioId: _scenario.id,
      scenarioTitle: _scenario.title.en,
      initialAircraft: _scenario.aircraft
          .map((a) => AircraftReplayState(
                callsign: a.callsign,
                x: a.x,
                y: a.y,
                heading: a.heading,
                speed: a.speed,
                altitude: a.altitude,
                wasSelected: false,
                wasConflicting: false,
              ))
          .toList(),
      finalAircraft: _engine.aircraft
          .map((a) => AircraftReplayState(
                callsign: a.callsign,
                x: a.x,
                y: a.y,
                heading: a.heading,
                speed: a.speed,
                altitude: a.altitude,
                wasSelected: _selectedCallsign == a.callsign,
                wasConflicting: result.conflictPair.contains(a.callsign),
              ))
          .toList(),
      conflictPairCallsigns: result.conflictPair,
      closestPointPxX: _engine.closestPairMidX,
      closestPointPxY: _engine.closestPairMidY,
      closestPointTimeSec: result.closestPointTimeSec,
      thresholdHorizontalPx: _scenario.conflictRules.minHorizontalDistancePx,
      thresholdVerticalFt:
          _scenario.conflictRules.minVerticalSeparationFL * 100,
      actionTimeSec: result.reactionTimeSec,
      userCommandSummary: cmdSummary,
      minHorizDist: result.minHorizontalDistancePx,
      hadLOS: result.hadLOS,
      score: result.score,
      ratingKey: result.ratingKey,
      penaltyBreakdown: result.penaltyBreakdown,
      bonusBreakdown: result.bonusBreakdown,
      pilotRadioCalls: List<ReplayPilotRadioCall>.from(_pilotRadioEvents),
      warningCues: List<ReplayWarningCue>.from(_warningAudioEvents),
    );

    // Build rich detailed result for the debrief screen
    final dr = ScoringEngine.fromExistingResult(
      scenario: _scenario,
      result: result,
      replayData: replay,
      startedAt: _scenarioStartedAt ??
          DateTime.now().subtract(
              Duration(seconds: _scenario.timeLimitSeconds - _timeLeft)),
      completedAt: DateTime.now(),
    );

    // Save score and compute improvement delta
    final delta = await ProgressionService.instance
        .saveScenarioScore(_scenario.id, result.score);

    setState(() {
      _result = result;
      _replayData = replay;
      _detailedResult = dr;
      _scoreDelta = delta;
      _screenState = _ScreenState.result;
    });
  }

  void _retryScenario() {
    _stopTimers();
    setState(() => _initScenario());
    _startTimers();
  }

  void _goToNext() {
    if (_scenarioIndex >= allScenarios.length - 1) return;
    _stopTimers();
    setState(() {
      _scenarioIndex++;
      _initScenario();
    });
    _startTimers();
  }

  @override
  void dispose() {
    _running = false;
    _audioClock.stop();
    _radioAudio.clearQueue(stopCurrent: true);
    _sweepCtrl.dispose();
    _stopTimers();
    super.dispose();
  }

  // ── Commands ──────────────────────────────────────────────────────────────
  void _issueCommand(String command) {
    final cs = _selectedCallsign;
    if (cs == null) return;
    final feedback = _engine.issueCommand(cs, command);
    _enqueuePilotAck(cs, command);
    setState(() {});
    _showCommandFeedback(feedback);
  }

  void _enqueuePilotAck(String callsign, String command) {
    final current = _engine.aircraft.firstWhere(
      (a) => a.callsign == callsign,
      orElse: () => _engine.aircraft.first,
    );
    final heading = current.heading.round() % 360;
    final headingText = heading.toString().padLeft(3, '0');
    final speedText = (current.speed * 200).round();
    final altitudeFt = current.altitude * 100;

    final text = switch (command) {
      'left' => '$callsign turning heading $headingText',
      'right' => '$callsign turning heading $headingText',
      'climb' => '$callsign climbing $altitudeFt',
      'descend' => '$callsign descending $altitudeFt',
      'slow' => '$callsign reducing speed $speedText',
      'fast' => '$callsign increasing speed $speedText',
      _ => '$callsign roger',
    };

    _pilotRadioEvents.add(
      ReplayPilotRadioCall(
        timestampSec: _audioClock.elapsedMilliseconds / 1000.0,
        callsign: callsign,
        text: text,
      ),
    );
    _radioAudio.enqueuePilotAck(callsign: callsign, spokenText: text);
  }

  void _tickPlaybackWarnings() {
    if (!_audioSettings.settings.value.warningsEnabled) return;
    final ts = _audioClock.elapsedMilliseconds / 1000.0;

    if (!_playedConflictWarning &&
        _engine.alertLevel.index >= AlertLevel.warning.index) {
      _playedConflictWarning = true;
      _warningAudioEvents.add(
        ReplayWarningCue(timestampSec: ts, type: 'conflict'),
      );
      _radioAudio.enqueueWarning(RadioWarningType.conflict, interrupt: true);
    }

    if (!_playedRunwayPressureWarning && _timeLeft <= 12) {
      _playedRunwayPressureWarning = true;
      _warningAudioEvents.add(
        ReplayWarningCue(timestampSec: ts, type: 'runwayPressure'),
      );
      _radioAudio.enqueueWarning(RadioWarningType.runwayPressure);
    }

    if (!_playedOverloadWarning && _engine.alertLevel == AlertLevel.los) {
      _playedOverloadWarning = true;
      _warningAudioEvents.add(
        ReplayWarningCue(timestampSec: ts, type: 'overloadPeak'),
      );
      _radioAudio.enqueueWarning(RadioWarningType.overloadPeak,
          interrupt: true);
    }
  }

  void _showCommandFeedback(String feedback) {
    _feedbackTimer?.cancel();
    setState(() => _cmdFeedback = feedback);
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _cmdFeedback = null);
    });
  }

  // ── Skill label ───────────────────────────────────────────────────────────
  // Human-readable command name for replay summary
  static String _commandLabel(String cmd) {
    switch (cmd) {
      case 'left':
        return 'Turn left';
      case 'right':
        return 'Turn right';
      case 'climb':
        return 'Climb';
      case 'descend':
        return 'Descend';
      case 'slow':
        return 'Slow';
      case 'fast':
        return 'Fast';
      default:
        return cmd;
    }
  }

  String _skillLabel(AppLocalizations l10n) {
    switch (_scenario.skill) {
      case 'altitude':
        return l10n.skillAltitude;
      case 'speed':
        return l10n.skillSpeed;
      case 'separation':
        return l10n.skillSeparation;
      default:
        return l10n.skillMixed;
    }
  }

  Future<void> _openAudioSettings() async {
    await _audioSettings.ensureLoaded();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ValueListenableBuilder<RadioAudioSettings>(
              valueListenable: _audioSettings.settings,
              builder: (context, s, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilot Radio Playback',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Voice volume ${(s.voiceVolume * 100).round()}%',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    Slider(
                      value: s.voiceVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: (v) => _audioSettings.setVoiceVolume(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Warning audio'),
                      value: s.warningsEnabled,
                      onChanged: (v) => _audioSettings.setWarningsEnabled(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Radio subtitles'),
                      value: s.subtitlesEnabled,
                      onChanged: (v) => _audioSettings.setSubtitlesEnabled(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Replay radio audio'),
                      value: s.replayAudioEnabled,
                      onChanged: (v) => _audioSettings.setReplayAudioEnabled(v),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final conflict = _engine.alertLevel == AlertLevel.los;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_scenario.title.of(locale)),
            Text(
              '${l10n.scenarioLevelLabel(_scenario.level)} · ${_skillLabel(l10n)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        toolbarHeight: 58,
        actions: [
          // Timer
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _timeLeft <= 10
                      ? AppTheme.danger.withValues(alpha: 0.2)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _timeLeft <= 10
                        ? AppTheme.danger
                        : AppTheme.borderColor,
                  ),
                ),
                child: Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    color: _timeLeft <= 10
                        ? AppTheme.danger
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          // Scenario counter
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${_scenarioIndex + 1}/${allScenarios.length}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Radio audio settings',
            onPressed: _openAudioSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Alert pressure bar ────────────────────────────────────────
              PressureBar(
                level: _engine.alertLevel,
                minHorizDist: _engine.minHorizDist == double.infinity
                    ? 999
                    : _engine.minHorizDist,
              ),

              // ── Objective card ────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined,
                        color: AppTheme.secondary, size: 13),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scenario.objective.of(locale),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── How-to hint ───────────────────────────────────────────────
              if (!_everSelected && _screenState == _ScreenState.playing)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined,
                          color: AppTheme.secondary, size: 13),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.radarV2HowTo,
                          style: const TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 10,
                              height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Per-command feedback ──────────────────────────────────────
              if (_cmdFeedback != null)
                _CommandFeedbackBanner(feedback: _cmdFeedback!),

              // ── Radar ─────────────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTapDown: (d) {
                    if (_screenState != _ScreenState.playing) return;
                    final p = d.localPosition;
                    String? hit;
                    double minDist = 32;
                    for (final a in _engine.aircraft) {
                      final dist =
                          sqrt(pow(p.dx - a.x, 2) + pow(p.dy - a.y, 2));
                      if (dist < minDist) {
                        minDist = dist;
                        hit = a.callsign;
                      }
                    }
                    setState(() {
                      _selectedCallsign = hit;
                      if (hit != null) _everSelected = true;
                    });
                  },
                  child: CustomPaint(
                    painter: RadarPainter(
                      aircraft: _engine.aircraft,
                      sweepAngle: _sweepAngle,
                      selected: _selectedCallsign == null
                          ? null
                          : _engine.aircraft.firstWhere(
                              (a) => a.callsign == _selectedCallsign,
                              orElse: () => _engine.aircraft.first),
                      conflict: conflict,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // ── Selected aircraft info ────────────────────────────────────
              if (_selectedCallsign != null &&
                  _screenState == _ScreenState.playing)
                Builder(builder: (ctx) {
                  final sel = _engine.aircraft.firstWhere(
                    (a) => a.callsign == _selectedCallsign,
                    orElse: () => _engine.aircraft.first,
                  );
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.yellowAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight,
                            color: Colors.yellowAccent, size: 13),
                        const SizedBox(width: 8),
                        Text(
                          '${sel.callsign}  FL${sel.altitude}  '
                          'HDG ${sel.heading.toInt()}°  '
                          'SPD ${sel.speed.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // ── Commands ──────────────────────────────────────────────────
              if (_screenState == _ScreenState.playing)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      12, 4, 12, MediaQuery.of(context).padding.bottom + 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _cmdBtn(
                          l10n.cmdTurnLeft,
                          _selectedCallsign != null
                              ? () => _issueCommand('left')
                              : null),
                      _cmdBtn(
                          l10n.cmdTurnRight,
                          _selectedCallsign != null
                              ? () => _issueCommand('right')
                              : null),
                      _cmdBtn(
                          l10n.cmdClimb,
                          _selectedCallsign != null
                              ? () => _issueCommand('climb')
                              : null),
                      _cmdBtn(
                          l10n.cmdDescend,
                          _selectedCallsign != null
                              ? () => _issueCommand('descend')
                              : null),
                      _cmdBtn(
                          l10n.cmdSlow,
                          _selectedCallsign != null
                              ? () => _issueCommand('slow')
                              : null),
                      _cmdBtn(
                          l10n.cmdFast,
                          _selectedCallsign != null
                              ? () => _issueCommand('fast')
                              : null),
                    ],
                  ),
                ),
            ],
          ),

          // ── Result overlay ────────────────────────────────────────────────
          if (_screenState == _ScreenState.result && _result != null)
            ScenarioFeedbackPanel(
              result: _result!,
              scenario: _scenario,
              languageCode: locale,
              replayData: _replayData,
              detailedResult: _detailedResult,
              scoreDelta: _scoreDelta,
              onRetry: _retryScenario,
              onNext:
                  _scenarioIndex < allScenarios.length - 1 ? _goToNext : null,
              onDone: () => Navigator.pop(context),
            ),

          ValueListenableBuilder<String?>(
            valueListenable: _radioAudio.subtitle,
            builder: (context, text, _) {
              if (text == null || text.isEmpty) return const SizedBox.shrink();
              if (!_audioSettings.settings.value.subtitlesEnabled) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 12,
                right: 12,
                bottom: max(
                  76,
                  MediaQuery.of(context).viewPadding.bottom + 48,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cmdBtn(String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? AppTheme.primary : AppTheme.textSecondary,
        side: BorderSide(
            color: enabled ? AppTheme.primary : AppTheme.borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

enum _ScreenState { playing, result }

// ── Per-command feedback banner ────────────────────────────────────────────

class _CommandFeedbackBanner extends StatelessWidget {
  final String feedback; // 'good' | 'neutral' | 'bad'

  const _CommandFeedbackBanner({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Color color;
    final String text;
    final IconData icon;

    switch (feedback) {
      case 'good':
        color = AppTheme.primary;
        text = l10n.feedbackGood;
        icon = Icons.trending_up;
      case 'bad':
        color = AppTheme.danger;
        text = l10n.feedbackBad;
        icon = Icons.trending_down;
      default:
        color = AppTheme.warning;
        text = l10n.feedbackNeutral;
        icon = Icons.trending_flat;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
