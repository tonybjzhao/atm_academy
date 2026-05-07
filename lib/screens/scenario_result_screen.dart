import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/scenario_result.dart';
import '../services/scoring_engine.dart';
import '../widgets/radar_replay_view.dart';
import '../widgets/replay_timeline.dart';
import '../widgets/score_explanation_panel.dart';

/// Full-screen debrief shown after a guided scenario.
/// Contains animated radar replay, timeline, score explanation,
/// and navigation buttons.
///
/// Pass [result] from [ScoringEngine.fromExistingResult()] or
/// use [ScenarioResultScreen.mock()] during development.
class ScenarioResultScreen extends StatefulWidget {
  final DetailedScenarioResult result;
  final VoidCallback?           onRetry;
  final VoidCallback?           onNextScenario;

  const ScenarioResultScreen({
    super.key,
    required this.result,
    this.onRetry,
    this.onNextScenario,
  });

  /// Quick constructor for in-editor / mock testing.
  static Widget mock({VoidCallback? onRetry, VoidCallback? onNextScenario}) =>
      ScenarioResultScreen(
        result: ScoringEngine.mock(),
        onRetry: onRetry,
        onNextScenario: onNextScenario,
      );

  @override
  State<ScenarioResultScreen> createState() => _ScenarioResultScreenState();
}

class _ScenarioResultScreenState extends State<ScenarioResultScreen>
    with SingleTickerProviderStateMixin {

  // ── Replay state ───────────────────────────────────────────────────────────
  late final ValueNotifier<double> _progress; // 0→1
  late final AnimationController   _replayCtr;

  bool _playing          = false;
  int  _speedMultiplier  = 1;
  bool _autoStarted      = false;

  // ── Tab ───────────────────────────────────────────────────────────────────
  int  _selectedTab   = 0; // 0 = Replay, 1 = Debrief
  bool _showIdeal     = false; // Actual vs Ideal replay toggle

  @override
  void initState() {
    super.initState();
    _progress = ValueNotifier(0.0);
    _replayCtr = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (widget.result.totalDurationSeconds * 1000 / _speedMultiplier).round(),
      ),
    )..addListener(_onTick)
     ..addStatusListener(_onStatus);

    // Auto-play after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _play();
    });
  }

  void _onTick() {
    _progress.value = _replayCtr.value;
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      setState(() => _playing = false);
    }
  }

  void _play() {
    _replayCtr.duration = Duration(
      milliseconds:
          (widget.result.totalDurationSeconds * 1000 / _speedMultiplier).round(),
    );
    _replayCtr.forward(from: _replayCtr.value);
    setState(() => _playing = true);
  }

  void _pause() {
    _replayCtr.stop();
    setState(() => _playing = false);
  }

  void _togglePlay() => _playing ? _pause() : _play();

  void _cycleSpeed() {
    setState(() {
      _speedMultiplier = _speedMultiplier == 4 ? 1 : _speedMultiplier * 2;
    });
    if (_playing) {
      _replayCtr.stop();
      _play();
    }
  }

  void _restart() {
    _replayCtr.reset();
    _progress.value = 0;
    _play();
  }

  @override
  void dispose() {
    _replayCtr.removeListener(_onTick);
    _replayCtr.removeStatusListener(_onStatus);
    _replayCtr.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final result = widget.result;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.scenarioTitle,
                style: const TextStyle(fontSize: 14)),
            Text('Score: ${result.finalScore} / ${result.maxScore}  ·  ${result.grade.label}',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        toolbarHeight: 58,
        actions: [
          // Replay restart
          IconButton(
            icon: const Icon(Icons.replay, size: 20),
            onPressed: _restart,
            tooltip: 'Restart replay',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            child: Row(
              children: [
                _Tab(label: 'Replay',  index: 0, selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i)),
                _Tab(label: 'Debrief', index: 1, selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i)),
              ],
            ),
          ),

          // ── Replay mode toggle (shown only on Replay tab) ─────────────────
          if (_selectedTab == 0 && result.idealFrames.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppTheme.surface,
              child: Row(
                children: [
                  const Text('View:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(width: 10),
                  _ModeChip(
                    label: 'Actual',
                    active: !_showIdeal,
                    onTap: () { setState(() { _showIdeal = false; }); _restart(); },
                  ),
                  const SizedBox(width: 6),
                  _ModeChip(
                    label: '💡 Ideal',
                    active: _showIdeal,
                    color: AppTheme.primary,
                    onTap: () { setState(() { _showIdeal = true; }); _restart(); },
                  ),
                  const SizedBox(width: 8),
                  const Text('(earlier action)',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 9,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _selectedTab == 0
                ? _ReplayTab(
                    result:          result,
                    progress:        _progress,
                    playing:         _playing,
                    speedMultiplier: _speedMultiplier,
                    showIdeal:       _showIdeal,
                    onPlayPause:     _togglePlay,
                    onCycleSpeed:    _cycleSpeed,
                  )
                : ScoreExplanationPanel(result: result),
          ),

          // ── Bottom action bar ──────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Try Again'),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRetry?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                    ),
                  ),
                  if (widget.onNextScenario != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 15),
                        label: const Text('Next'),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onNextScenario!();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Replay tab ─────────────────────────────────────────────────────────────────

class _ReplayTab extends StatelessWidget {
  final DetailedScenarioResult result;
  final ValueNotifier<double>  progress;
  final bool    playing;
  final bool    showIdeal;
  final int     speedMultiplier;
  final VoidCallback onPlayPause;
  final VoidCallback onCycleSpeed;

  const _ReplayTab({
    required this.result,
    required this.progress,
    required this.playing,
    required this.showIdeal,
    required this.speedMultiplier,
    required this.onPlayPause,
    required this.onCycleSpeed,
  });

  @override
  Widget build(BuildContext context) {
    // Build a "virtual" result with ideal frames when showIdeal is true
    final displayResult = showIdeal && result.idealFrames.isNotEmpty
        ? _withIdealFrames(result)
        : result;

    return Column(
      children: [
        // Radar display
        Expanded(
          child: RadarReplayView(
            result:           displayResult,
            externalProgress: progress,
          ),
        ),
        // Timeline + controls
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: ReplayTimeline(
            result:           result,
            progressNotifier: progress,
            isPlaying:        playing,
            speedMultiplier:  speedMultiplier,
            onPlayPause:      onPlayPause,
            onCycleSpeed:     onCycleSpeed,
          ),
        ),
      ],
    );
  }
}

// ── Ideal-frame helper ─────────────────────────────────────────────────────────

DetailedScenarioResult _withIdealFrames(DetailedScenarioResult r) =>
    DetailedScenarioResult(
      scenarioId:       r.scenarioId,
      scenarioTitle:    r.scenarioTitle,
      finalScore:       r.finalScore,
      maxScore:         r.maxScore,
      grade:            r.grade,
      startedAt:        r.startedAt,
      completedAt:      r.completedAt,
      replayFrames:     r.idealFrames,  // ← swap frames
      idealFrames:      r.idealFrames,
      replayEvents:     r.replayEvents,
      userActions:      r.userActions,
      penalties:        r.penalties,
      bonuses:          r.bonuses,
      projectedOutcomes: r.projectedOutcomes,
      summaryText:      r.summaryText,
      improvementTips:  r.improvementTips,
      hadLOS:           false,          // ideal = no LOS
      minHorizDistPx:   r.minHorizDistPx,
    );

// ── Mode chip (Actual / Ideal) ─────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String   label;
  final bool     active;
  final Color    color;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.active,
    this.color = AppTheme.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.15)
                : AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? color : AppTheme.borderColor,
              width: active ? 1.3 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      );
}

// ── Tab widget ─────────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String   label;
  final int      index;
  final int      selected;
  final void Function(int) onTap;

  const _Tab({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppTheme.primary : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
