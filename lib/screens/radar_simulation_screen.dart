import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/models/aircraft.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/daily_challenge_service.dart';
import '../widgets/radar_painter.dart';

enum _ScenarioState { playing, success, failed }

class RadarSimulationScreen extends StatefulWidget {
  const RadarSimulationScreen({super.key});

  @override
  State<RadarSimulationScreen> createState() => _RadarSimulationScreenState();
}

class _RadarSimulationScreenState extends State<RadarSimulationScreen>
    with SingleTickerProviderStateMixin {
  // ── Sweep ────────────────────────────────────────────────────────────────
  late final AnimationController _sweepCtrl;
  double _sweepAngle = 0;

  // ── Physics ───────────────────────────────────────────────────────────────
  bool _running = true;
  late List<Aircraft> _aircraft;
  Aircraft? _selected;

  // ── Scenario state ────────────────────────────────────────────────────────
  _ScenarioState _state = _ScenarioState.playing;
  int _timeLeft = 60;
  int _score = 100;
  // Counts physics ticks (50ms each) where no conflict exists.
  // 100 ticks = 5 continuous seconds clear → success.
  int _conflictFreeTicks = 0;
  bool _everSelected = false;   // hides the how-to hint after first selection

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _countdownTimer;
  Timer? _penaltyTimer;

  // ── Conflict detection ────────────────────────────────────────────────────
  // Horizontal distance < 70 px AND vertical difference < 10 FLs (≈1000 ft)
  bool get _hasConflict {
    for (int i = 0; i < _aircraft.length; i++) {
      for (int j = i + 1; j < _aircraft.length; j++) {
        final dx = _aircraft[i].x - _aircraft[j].x;
        final dy = _aircraft[i].y - _aircraft[j].y;
        final horiz = sqrt(dx * dx + dy * dy);
        final vert = (_aircraft[i].altitude - _aircraft[j].altitude).abs();
        if (horiz < 70 && vert < 10) return true;
      }
    }
    return false;
  }

  // ── Setup ─────────────────────────────────────────────────────────────────
  void _initAircraft() {
    // QFA123 and UAE406 start 60 px apart at the same altitude → immediate conflict.
    // THA789 and SIA201 are clear of separation.
    _aircraft = [
      Aircraft(callsign: 'QFA123', x: 140, y: 195, heading: 70,  speed: 0.75, altitude: 320),
      Aircraft(callsign: 'UAE406', x: 200, y: 195, heading: 250, speed: 0.65, altitude: 320),
      Aircraft(callsign: 'THA789', x: 70,  y: 80,  heading: 155, speed: 0.50, altitude: 240),
      Aircraft(callsign: 'SIA201', x: 305, y: 315, heading: 335, speed: 0.55, altitude: 290),
    ];
  }

  void _startTimers() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state != _ScenarioState.playing) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _state = _ScenarioState.failed;
          _stopTimers();
        }
      });
    });

    // −5 pts every 5 s of play time
    _penaltyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _state != _ScenarioState.playing) return;
      setState(() => _score = max(0, _score - 5));
    });
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _penaltyTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    _initAircraft();

    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() => setState(() => _sweepAngle += 0.018));
    _sweepCtrl.repeat();

    // Physics: 50 ms per tick
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted || !_running) return false;
      if (_state == _ScenarioState.playing) {
        setState(() {
          for (final a in _aircraft) {
            a.update(const Size(370, 430));
          }
          if (!_hasConflict) {
            _conflictFreeTicks++;
            if (_conflictFreeTicks >= 100) {
              // 5 s conflict-free → success
              _score = min(120, _score + 20); // +20 bonus, cap 120
              _state = _ScenarioState.success;
              _stopTimers();
            }
          } else {
            _conflictFreeTicks = 0;
          }
        });
      }
      return true;
    });

    _startTimers();
  }

  void _resetScenario() {
    _stopTimers();
    _initAircraft();
    setState(() {
      _state = _ScenarioState.playing;
      _timeLeft = 60;
      _score = 100;
      _conflictFreeTicks = 0;
      _selected = null;
      _everSelected = false;
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
  void _issueCommand(String type) {
    final a = _selected;
    if (a == null) return;
    setState(() {
      _score = max(0, _score - 2); // −2 per command
      switch (type) {
        case 'left':    a.heading -= 15;
        case 'right':   a.heading += 15;
        case 'climb':   a.altitude += 10;   // +1000 ft
        case 'descend': a.altitude -= 10;   // −1000 ft
        case 'slow':    a.speed = max(0.2, a.speed - 0.1);
        case 'fast':    a.speed = min(1.5,  a.speed + 0.1);
      }
    });
  }

  // Score colour: green ≥80, amber 40–79, red <40
  Color _scoreColor() {
    if (_score >= 80) return AppTheme.primary;
    if (_score >= 40) return AppTheme.warning;
    return AppTheme.danger;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conflict = _hasConflict;
    final resolving = !conflict && _conflictFreeTicks > 0 && _state == _ScenarioState.playing;
    final resolvePct = (_conflictFreeTicks / 100).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.radarSimTitle),
        actions: [
          // Timer badge
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _timeLeft <= 15
                      ? AppTheme.danger.withValues(alpha: 0.2)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _timeLeft <= 15 ? AppTheme.danger : AppTheme.borderColor,
                  ),
                ),
                child: Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    color: _timeLeft <= 15 ? AppTheme.danger : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          // Score badge with dynamic colour
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '$_score / 120',
                style: TextStyle(
                  color: _scoreColor(),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
              // ── Scenario description bar ────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.adjust, color: AppTheme.secondary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.radarV2ScenarioTitle,
                            style: const TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            l10n.radarV2ScenarioDesc,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Status bar ──────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: conflict
                      ? AppTheme.danger.withValues(alpha: 0.12)
                      : resolving
                          ? AppTheme.warning.withValues(alpha: 0.09)
                          : AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: conflict
                        ? AppTheme.danger
                        : resolving
                            ? AppTheme.warning.withValues(alpha: 0.5)
                            : AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      conflict
                          ? Icons.warning_amber_rounded
                          : resolving
                              ? Icons.hourglass_top
                              : Icons.check_circle_outline,
                      color: conflict
                          ? AppTheme.danger
                          : resolving
                              ? AppTheme.warning
                              : AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conflict
                            ? l10n.radarConflictAlert
                            : resolving
                                ? '${l10n.radarV2Resolving} ${(resolvePct * 100).toInt()}%'
                                : l10n.radarTrafficNormal(_aircraft.length),
                        style: TextStyle(
                          color: conflict
                              ? AppTheme.danger
                              : resolving
                                  ? AppTheme.warning
                                  : AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    // Resolve progress bar
                    if (resolving)
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: resolvePct,
                            minHeight: 4,
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.borderColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── How-to hint (shown until first aircraft selected) ─────────
              if (!_everSelected && _state == _ScenarioState.playing)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined, color: AppTheme.secondary, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.radarV2HowTo,
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Radar display ────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTapDown: (details) {
                    if (_state != _ScenarioState.playing) return;
                    final p = details.localPosition;
                    Aircraft? hit;
                    double minDist = 32;
                    for (final a in _aircraft) {
                      final d = sqrt(pow(p.dx - a.x, 2) + pow(p.dy - a.y, 2));
                      if (d < minDist) { minDist = d; hit = a; }
                    }
                    setState(() { _selected = hit; if (hit != null) _everSelected = true; });
                  },
                  child: CustomPaint(
                    painter: RadarPainter(
                      aircraft: _aircraft,
                      sweepAngle: _sweepAngle,
                      selected: _selected,
                      conflict: conflict,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // ── Selected aircraft info ────────────────────────────────────
              if (_selected != null && _state == _ScenarioState.playing)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flight, color: Colors.yellowAccent, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '${_selected!.callsign}  '
                        'FL${_selected!.altitude}  '
                        'HDG ${_selected!.heading.toInt()}°  '
                        'SPD ${_selected!.speed.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Command buttons ───────────────────────────────────────────
              if (_state == _ScenarioState.playing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _cmdBtn(l10n.cmdTurnLeft,  _selected != null ? () => _issueCommand('left')    : null),
                      _cmdBtn(l10n.cmdTurnRight, _selected != null ? () => _issueCommand('right')   : null),
                      _cmdBtn(l10n.cmdClimb,     _selected != null ? () => _issueCommand('climb')   : null),
                      _cmdBtn(l10n.cmdDescend,   _selected != null ? () => _issueCommand('descend') : null),
                      _cmdBtn(l10n.cmdSlow,      _selected != null ? () => _issueCommand('slow')    : null),
                      _cmdBtn(l10n.cmdFast,      _selected != null ? () => _issueCommand('fast')    : null),
                    ],
                  ),
                ),
            ],
          ),

          // ── Result overlay ────────────────────────────────────────────────
          if (_state != _ScenarioState.playing)
            _ResultOverlay(
              success: _state == _ScenarioState.success,
              score: _score,
              onReset: _resetScenario,
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

// ── Result overlay ─────────────────────────────────────────────────────────

class _ResultOverlay extends StatelessWidget {
  final bool success;
  final int score;
  final VoidCallback onReset;

  const _ResultOverlay({
    required this.success,
    required this.score,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppTheme.background.withValues(alpha: 0.93),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success ? Icons.verified : Icons.cancel_outlined,
                size: 80,
                color: success ? AppTheme.primary : AppTheme.danger,
              ),
              const SizedBox(height: 20),
              Text(
                success ? l10n.radarV2ScenarioSuccess : l10n.radarV2ScenarioFailed,
                style: TextStyle(
                  color: success ? AppTheme.primary : AppTheme.danger,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (success) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.radarV2SuccessHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${l10n.radarV2FinalScore}: $score / 120',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 36),
              if (success) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flag_rounded, size: 16),
                    label: Text(l10n.radarCompleteScenario),
                    onPressed: () async {
                      final msg = l10n.radarScenarioSnackbar;
                      await DailyChallengeService.instance.markRadarDone();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.radarV2TryAgain),
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
