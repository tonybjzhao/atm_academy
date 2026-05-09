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
import '../services/progression_service.dart';
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
    final cmdCs   = _engine.firstCommandCallsign;
    final cmdSummary = cmdCs.isEmpty
        ? 'No command issued'
        : '${_commandLabel(cmdType)} on $cmdCs';

    final replay = ScenarioReplayData(
      scenarioId:    _scenario.id,
      scenarioTitle: _scenario.title.en,
      initialAircraft: _scenario.aircraft.map((a) => AircraftReplayState(
        callsign: a.callsign, x: a.x, y: a.y,
        heading: a.heading, speed: a.speed, altitude: a.altitude,
        wasSelected: false, wasConflicting: false,
      )).toList(),
      finalAircraft: _engine.aircraft.map((a) => AircraftReplayState(
        callsign: a.callsign, x: a.x, y: a.y,
        heading: a.heading, speed: a.speed, altitude: a.altitude,
        wasSelected:    _selectedCallsign == a.callsign,
        wasConflicting: result.conflictPair.contains(a.callsign),
      )).toList(),
      conflictPairCallsigns: result.conflictPair,
      closestPointPxX:       _engine.closestPairMidX,
      closestPointPxY:       _engine.closestPairMidY,
      closestPointTimeSec:   result.closestPointTimeSec,
      thresholdHorizontalPx: _scenario.conflictRules.minHorizontalDistancePx,
      thresholdVerticalFt:   _scenario.conflictRules.minVerticalSeparationFL * 100,
      actionTimeSec:         result.reactionTimeSec,
      userCommandSummary:    cmdSummary,
      minHorizDist:          result.minHorizontalDistancePx,
      hadLOS:                result.hadLOS,
      score:                 result.score,
      ratingKey:             result.ratingKey,
      penaltyBreakdown:      result.penaltyBreakdown,
      bonusBreakdown:        result.bonusBreakdown,
    );

    // Build rich detailed result for the debrief screen
    final dr = ScoringEngine.fromExistingResult(
      scenario:    _scenario,
      result:      result,
      replayData:  replay,
      startedAt:   _scenarioStartedAt ?? DateTime.now().subtract(
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
    _sweepCtrl.dispose();
    _stopTimers();
    super.dispose();
  }

  // ── Commands ──────────────────────────────────────────────────────────────
  void _issueCommand(String command) {
    final cs = _selectedCallsign;
    if (cs == null) return;
    final feedback = _engine.issueCommand(cs, command);
    setState(() {});
    _showCommandFeedback(feedback);
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
      case 'left':    return 'Turn left';
      case 'right':   return 'Turn right';
      case 'climb':   return 'Climb';
      case 'descend': return 'Descend';
      case 'slow':    return 'Slow';
      case 'fast':    return 'Fast';
      default:        return cmd;
    }
  }

  String _skillLabel(AppLocalizations l10n) {
    switch (_scenario.skill) {
      case 'altitude':   return l10n.skillAltitude;
      case 'speed':      return l10n.skillSpeed;
      case 'separation': return l10n.skillSeparation;
      default:           return l10n.skillMixed;
    }
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
                    color: _timeLeft <= 10 ? AppTheme.danger : AppTheme.borderColor,
                  ),
                ),
                child: Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    color: _timeLeft <= 10 ? AppTheme.danger : AppTheme.textPrimary,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: AppTheme.secondary, size: 13),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined, color: AppTheme.secondary, size: 13),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.radarV2HowTo,
                          style: const TextStyle(color: AppTheme.secondary, fontSize: 10, height: 1.3),
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
                      final dist = sqrt(pow(p.dx - a.x, 2) + pow(p.dy - a.y, 2));
                      if (dist < minDist) { minDist = dist; hit = a.callsign; }
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
              if (_selectedCallsign != null && _screenState == _ScreenState.playing)
                Builder(builder: (ctx) {
                  final sel = _engine.aircraft.firstWhere(
                    (a) => a.callsign == _selectedCallsign,
                    orElse: () => _engine.aircraft.first,
                  );
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight, color: Colors.yellowAccent, size: 13),
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
                  padding: EdgeInsets.fromLTRB(12, 4, 12, MediaQuery.of(context).padding.bottom + 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _cmdBtn(l10n.cmdTurnLeft,  _selectedCallsign != null ? () => _issueCommand('left')    : null),
                      _cmdBtn(l10n.cmdTurnRight, _selectedCallsign != null ? () => _issueCommand('right')   : null),
                      _cmdBtn(l10n.cmdClimb,     _selectedCallsign != null ? () => _issueCommand('climb')   : null),
                      _cmdBtn(l10n.cmdDescend,   _selectedCallsign != null ? () => _issueCommand('descend') : null),
                      _cmdBtn(l10n.cmdSlow,      _selectedCallsign != null ? () => _issueCommand('slow')    : null),
                      _cmdBtn(l10n.cmdFast,      _selectedCallsign != null ? () => _issueCommand('fast')    : null),
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
              onNext: _scenarioIndex < allScenarios.length - 1 ? _goToNext : null,
              onDone: () => Navigator.pop(context),
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
        side: BorderSide(color: enabled ? AppTheme.primary : AppTheme.borderColor),
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
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
