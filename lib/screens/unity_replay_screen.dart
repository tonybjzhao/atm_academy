import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
// ─────────────────────────────────────────────────────────────────────────────
// TODO (Phase 2 — Unity 3D Replay):
//   1. Export Unity project for each supported platform
//   2. Add back to pubspec.yaml:  flutter_unity_widget: ^2022.2.1
//   3. Uncomment the import below and the _UnityReplayView class
//   4. Set kUnityEnabled = true
// See unity/SETUP.md for the complete integration guide.
// Until then, the Flutter replay view below is the primary experience.
// ─────────────────────────────────────────────────────────────────────────────
// import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/replay_data.dart';
import '../services/score_localizer.dart';
import '../services/pilot_radio_audio_service.dart';
import '../services/radio_audio_settings_service.dart';

const bool kUnityEnabled = false;

class UnityReplayScreen extends StatelessWidget {
  final ScenarioReplayData replayData;
  const UnityReplayScreen({super.key, required this.replayData});

  @override
  Widget build(BuildContext context) => kUnityEnabled
      ? _UnityReplayView(replayData: replayData)
      : _FlutterReplayView(replayData: replayData);
}

// ── Unity live view (disabled — see TODO above) ────────────────────────────
// class _UnityReplayView extends StatefulWidget { ... }
class _UnityReplayView extends StatelessWidget {
  final ScenarioReplayData replayData;
  const _UnityReplayView({required this.replayData});
  @override
  Widget build(BuildContext context) =>
      _FlutterReplayView(replayData: replayData);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Flutter Replay View — full animated 2-D replay, score explanation,
//  penalty/bonus breakdown.  No Unity dependency.
// ═══════════════════════════════════════════════════════════════════════════

class _FlutterReplayView extends StatefulWidget {
  final ScenarioReplayData replayData;
  const _FlutterReplayView({required this.replayData});

  @override
  State<_FlutterReplayView> createState() => _FlutterReplayViewState();
}

class _FlutterReplayViewState extends State<_FlutterReplayView>
    with TickerProviderStateMixin {
  static const _totalSec = 7.0; // replay playback duration in seconds

  late final AnimationController _replayCtr; // 0→1 over _totalSec
  late final AnimationController _sweepCtr; // continuous radar sweep
  late final AnimationController _pulseCtr; // conflict pulse
  final PilotRadioAudioService _radioAudio = PilotRadioAudioService.instance;
  final RadioAudioSettingsService _audioSettings =
      RadioAudioSettingsService.instance;
  final Set<int> _playedCallIndexes = <int>{};
  final Set<int> _playedWarningIndexes = <int>{};
  double _lastReplaySec = 0;

  @override
  void initState() {
    super.initState();

    _replayCtr = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_totalSec * 1000).toInt()),
    )..addListener(_onReplayTick);

    _sweepCtr = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    // Auto-play
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _replayCtr.forward();
    });

    _audioSettings.ensureLoaded();
    _radioAudio.initialize();
  }

  @override
  void dispose() {
    _radioAudio.clearQueue(stopCurrent: true);
    _replayCtr.dispose();
    _sweepCtr.dispose();
    _pulseCtr.dispose();
    super.dispose();
  }

  void _onReplayTick() {
    setState(() {});
    _tickReplayAudio();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double get _t => _replayCtr.value; // 0→1
  bool get _done => _replayCtr.isCompleted;

  // Normalised time at which the closest approach occurred
  double get _conflictT {
    if (widget.replayData.closestPointTimeSec <= 0) return 0.5;
    return (widget.replayData.closestPointTimeSec / _totalSec).clamp(0.0, 1.0);
  }

  double get _actionT {
    if (widget.replayData.actionTimeSec <= 0) return -1;
    return (widget.replayData.actionTimeSec / _totalSec).clamp(0.0, 1.0);
  }

  void _restart() {
    _playedCallIndexes.clear();
    _playedWarningIndexes.clear();
    _lastReplaySec = 0;
    _radioAudio.clearQueue(stopCurrent: true);
    _replayCtr.reset();
    _replayCtr.forward();
  }

  void _togglePlay() {
    if (_done) {
      _restart();
      return;
    }
    _replayCtr.isAnimating ? _replayCtr.stop() : _replayCtr.forward();
  }

  void _tickReplayAudio() {
    final settings = _audioSettings.settings.value;
    if (!settings.replayAudioEnabled) {
      _lastReplaySec = _t * _totalSec;
      return;
    }

    final currentSec = _t * _totalSec;
    if (currentSec < _lastReplaySec) {
      _playedCallIndexes.clear();
      _playedWarningIndexes.clear();
    }

    final calls = widget.replayData.pilotRadioCalls;
    for (int i = 0; i < calls.length; i++) {
      if (_playedCallIndexes.contains(i)) continue;
      final e = calls[i];
      if (e.timestampSec <= currentSec) {
        _playedCallIndexes.add(i);
        _radioAudio.enqueuePilotAck(
          callsign: e.callsign,
          spokenText: e.text,
          ackDelay: Duration.zero,
        );
      }
    }

    final warnings = widget.replayData.warningCues.isNotEmpty
        ? widget.replayData.warningCues
        : <ReplayWarningCue>[
            ReplayWarningCue(
              timestampSec: max(0, widget.replayData.closestPointTimeSec),
              type: 'conflict',
            ),
          ];

    for (int i = 0; i < warnings.length; i++) {
      if (_playedWarningIndexes.contains(i)) continue;
      final e = warnings[i];
      if (e.timestampSec <= currentSec) {
        _playedWarningIndexes.add(i);
        _radioAudio.enqueueWarning(_warningTypeFrom(e.type));
      }
    }

    _lastReplaySec = currentSec;
  }

  RadioWarningType _warningTypeFrom(String type) {
    switch (type) {
      case 'runwayPressure':
        return RadioWarningType.runwayPressure;
      case 'overloadPeak':
        return RadioWarningType.overloadPeak;
      default:
        return RadioWarningType.conflict;
    }
  }

  Color _ratingColor() {
    switch (widget.replayData.ratingKey) {
      case 'ratingExcellent':
        return AppTheme.primary;
      case 'ratingSafe':
        return Colors.greenAccent;
      case 'ratingNeedsImprovement':
        return AppTheme.warning;
      default:
        return AppTheme.danger;
    }
  }

  String _ratingLabel(AppLocalizations l10n) {
    switch (widget.replayData.ratingKey) {
      case 'ratingExcellent':
        return l10n.ratingExcellent;
      case 'ratingSafe':
        return l10n.ratingSafe;
      case 'ratingNeedsImprovement':
        return l10n.ratingNeedsImprovement;
      default:
        return l10n.ratingUnsafe;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = widget.replayData;
    final rc = _ratingColor();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.unityReplayTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Radar display ─────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _ReplayPainter(
                      data: data,
                      t: _t,
                      sweepAngle: _sweepCtr.value * 2 * pi,
                      conflictT: _conflictT,
                      actionT: _actionT,
                      pulseVal: _pulseCtr.value,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  // "REPLAY COMPLETE" banner
                  if (_done)
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Text(
                            l10n.replayComplete,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Timeline + controls ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  // Play / Pause / Replay
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Icon(
                        _done
                            ? Icons.replay
                            : _replayCtr.isAnimating
                                ? Icons.pause
                                : Icons.play_arrow,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background track
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _t,
                            minHeight: 6,
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.surface,
                          ),
                        ),
                        // Conflict marker on timeline
                        if (_conflictT > 0)
                          FractionallySizedBox(
                            widthFactor: _conflictT,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: data.hadLOS
                                      ? AppTheme.danger
                                      : AppTheme.warning,
                                  border: Border.all(
                                      color: AppTheme.background, width: 1),
                                ),
                              ),
                            ),
                          ),
                        // Action marker on timeline
                        if (_actionT > 0)
                          FractionallySizedBox(
                            widthFactor: _actionT,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.yellowAccent,
                                  border: Border.all(
                                      color: AppTheme.background, width: 1),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(_t * _totalSec).toStringAsFixed(1)}s',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),

            ValueListenableBuilder<RadioAudioSettings>(
              valueListenable: _audioSettings.settings,
              builder: (context, settings, _) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(l10n.replayToggleReplayRadio,
                              style: const TextStyle(fontSize: 11)),
                          value: settings.replayAudioEnabled,
                          onChanged: (v) =>
                              _audioSettings.setReplayAudioEnabled(v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(l10n.replayToggleSubtitles,
                              style: const TextStyle(fontSize: 11)),
                          value: settings.subtitlesEnabled,
                          onChanged: (v) =>
                              _audioSettings.setSubtitlesEnabled(v),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Legend
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  _Dot(color: data.hadLOS ? AppTheme.danger : AppTheme.warning),
                  const SizedBox(width: 4),
                  Text(l10n.replayLegendClosestApproach,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10)),
                  const SizedBox(width: 16),
                  _Dot(color: Colors.yellowAccent),
                  const SizedBox(width: 4),
                  Text(l10n.replayLegendYourAction,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ),

            // ── Score + detail ────────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(14, 4, 14,
                    max(20.0, MediaQuery.of(context).viewPadding.bottom + 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${data.score}',
                            style: TextStyle(
                                color: rc,
                                fontSize: 36,
                                fontWeight: FontWeight.w900),
                          ),
                          const Text(' / 120',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 18)),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_ratingLabel(l10n),
                                  style: TextStyle(
                                      color: rc,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (data.hadLOS
                                          ? AppTheme.danger
                                          : AppTheme.primary)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: (data.hadLOS
                                            ? AppTheme.danger
                                            : AppTheme.primary)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  data.hadLOS
                                      ? l10n.scenarioLOSResult
                                      : l10n.scenarioSafeResult,
                                  style: TextStyle(
                                    color: data.hadLOS
                                        ? AppTheme.danger
                                        : AppTheme.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Key metrics
                    _MetricRow(
                        l10n.scenarioConflictPair,
                        data.conflictPairCallsigns.join(' ↔ '),
                        data.hadLOS ? AppTheme.danger : AppTheme.warning),
                    _MetricRow(
                        l10n.scenarioMinHorizSep,
                        '${data.minHorizDist.toStringAsFixed(0)} px  '
                        '(${l10n.scenarioThresholdPx(data.thresholdHorizontalPx.round())})',
                        data.hadLOS ? AppTheme.danger : AppTheme.textSecondary),
                    _MetricRow(
                        l10n.scenarioMinVertSep,
                        l10n.scenarioThresholdFt(data.thresholdVerticalFt),
                        AppTheme.textSecondary),
                    _MetricRow(
                        l10n.replayActionLabel,
                        data.actionTimeSec > 0
                            ? '${data.userCommandSummary}  (${data.actionTimeSec.toStringAsFixed(1)} s)'
                            : l10n.scenarioNoCommandIssued,
                        data.actionTimeSec > 0
                            ? Colors.yellowAccent
                            : AppTheme.danger),

                    const SizedBox(height: 10),

                    // Why you lost / gained points
                    if (data.penaltyBreakdown.isNotEmpty &&
                        data.penaltyBreakdown.first != 'None')
                      _BreakdownSection(
                        icon: Icons.remove_circle_outline,
                        color: AppTheme.danger,
                        title: l10n.scenarioPenalties,
                        items: data.penaltyBreakdown,
                        emptyItem: l10n.scenarioNoPenalties,
                        itemLocalizer: (value) =>
                            _localizedBreakdownItem(l10n, value),
                      ),
                    const SizedBox(height: 8),
                    if (data.bonusBreakdown.isNotEmpty &&
                        data.bonusBreakdown.first != 'None')
                      _BreakdownSection(
                        icon: Icons.add_circle_outline,
                        color: AppTheme.primary,
                        title: l10n.scenarioBonuses,
                        items: data.bonusBreakdown,
                        emptyItem: l10n.scenarioNoBonuses,
                        itemLocalizer: (value) =>
                            _localizedBreakdownItem(l10n, value),
                      ),

                    const SizedBox(height: 10),

                    // Back button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 15),
                        label: Text(l10n.unityReplayBack),
                        onPressed: () => Navigator.pop(context),
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

            ValueListenableBuilder<String?>(
              valueListenable: _radioAudio.subtitle,
              builder: (context, text, _) {
                if (text == null || text.isEmpty)
                  return const SizedBox.shrink();
                if (!_audioSettings.settings.value.subtitlesEnabled) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Container(
                    width: double.infinity,
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
      ),
    );
  }

  String _localizedBreakdownItem(AppLocalizations l10n, String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    if (text == 'None') return l10n.scenarioNoBonuses;

    final match = RegExp(r'^(.+?):\s*([+−-]\d+)$').firstMatch(text);
    final label = match?.group(1)?.trim() ?? text;
    final points = match?.group(2);
    final localizer = ScoreLocalizer(l10n);
    var localized = localizer.localizeBonusTitle(label);
    if (localized == label) {
      localized = localizer.localizePenaltyTitle(label);
    }
    if (localized == label) {
      localized = _directReplayBreakdownFallback(l10n, label);
    }
    if (localized == label && _looksUnlocalized(text)) {
      developer.log(
        'Missing replay breakdown localization for "$text" locale=${l10n.localeName}',
        name: 'LocalizationAudit',
      );
    }
    return points == null ? localized : '$localized: $points';
  }

  String _directReplayBreakdownFallback(AppLocalizations l10n, String label) {
    switch (label) {
      case 'Safe separation maintained':
        return l10n.scoreBonusSeparationMaintained;
      case 'Correct aircraft selected':
        return l10n.scoreBonusCorrectAircraft;
      case 'Early effective action':
        return l10n.scoreBonusEarlyAction;
      default:
        return label;
    }
  }

  bool _looksUnlocalized(String text) {
    return text.startsWith('radarTraining') ||
        RegExp(r'[A-Za-z]{4,}').hasMatch(text);
  }
}

// ── Radar painter ──────────────────────────────────────────────────────────

class _ReplayPainter extends CustomPainter {
  final ScenarioReplayData data;
  final double t; // replay progress 0→1
  final double sweepAngle; // radians
  final double conflictT; // normalised time of closest approach
  final double actionT; // normalised time of user action
  final double pulseVal; // 0→1 for conflict pulse

  const _ReplayPainter({
    required this.data,
    required this.t,
    required this.sweepAngle,
    required this.conflictT,
    required this.actionT,
    required this.pulseVal,
  });

  static const _srcW = 370.0;
  static const _srcH = 430.0;

  // Map scenario coords → canvas coords
  Offset _map(double x, double y, Size canvas) => Offset(
        x / _srcW * canvas.width,
        y / _srcH * canvas.height,
      );

  Offset _lerp(
      AircraftReplayState a, AircraftReplayState b, double frac, Size sz) {
    final ease = Curves.easeInOut.transform(frac.clamp(0.0, 1.0));
    return _map(a.x + (b.x - a.x) * ease, a.y + (b.y - a.y) * ease, sz);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawSweep(canvas, size);
    _drawConflictZone(canvas, size);
    _drawActionMarker(canvas, size);
    _drawTrails(canvas, size);
    _drawBlips(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) * 0.46;

    // Dark fill
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF050F0A));

    // Range rings
    final ringPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final r in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, radius * r, ringPaint);
    }
    // Cross lines
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), ringPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), ringPaint);
  }

  void _drawSweep(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) * 0.46;

    // Glow layer
    canvas.drawLine(
      center,
      Offset(center.dx + cos(sweepAngle) * radius,
          center.dy + sin(sweepAngle) * radius),
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.08)
        ..strokeWidth = 12,
    );
    // Main beam
    canvas.drawLine(
      center,
      Offset(center.dx + cos(sweepAngle) * radius,
          center.dy + sin(sweepAngle) * radius),
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.75)
        ..strokeWidth = 1.5,
    );
  }

  void _drawConflictZone(Canvas canvas, Size size) {
    // Show conflict marker when replay passes the conflict moment
    if (t < conflictT * 0.8) return;

    final pos = _map(data.closestPointPxX, data.closestPointPxY, size);
    final isLOS = data.hadLOS;
    final color = isLOS ? AppTheme.danger : AppTheme.warning;

    // Pulsing outer ring
    final outerRadius = 18.0 + pulseVal * (isLOS ? 12.0 : 7.0);
    canvas.drawCircle(
      pos,
      outerRadius,
      Paint()
        ..color = color.withValues(alpha: 0.15 + pulseVal * 0.20)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      pos,
      outerRadius,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Inner dot
    canvas.drawCircle(pos, 5, Paint()..color = color.withValues(alpha: 0.8));

    // Label
    final label = isLOS ? 'LOS' : '⚠';
    _drawLabel(canvas, pos + const Offset(0, -22), label,
        color: color, fontSize: 9);
    _drawLabel(canvas, pos + const Offset(0, -32),
        '${data.minHorizDist.toStringAsFixed(0)} px',
        color: color.withValues(alpha: 0.7), fontSize: 8);
  }

  void _drawActionMarker(Canvas canvas, Size size) {
    if (actionT < 0 || t < actionT) return;

    // Find the selected aircraft's interpolated position at action time
    final selIdx = data.finalAircraft.indexWhere((a) => a.wasSelected);
    if (selIdx < 0) return;

    final pos = _lerp(data.initialAircraft[selIdx], data.finalAircraft[selIdx],
        actionT, size);

    // Yellow diamond marker
    final path = Path()
      ..moveTo(pos.dx, pos.dy - 12)
      ..lineTo(pos.dx + 8, pos.dy)
      ..lineTo(pos.dx, pos.dy + 12)
      ..lineTo(pos.dx - 8, pos.dy)
      ..close();
    canvas.drawPath(
        path, Paint()..color = Colors.yellowAccent.withValues(alpha: 0.25));
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.yellowAccent.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    _drawLabel(
        canvas,
        pos + const Offset(12, -8),
        data.userCommandSummary.length > 20
            ? '${data.userCommandSummary.substring(0, 20)}…'
            : data.userCommandSummary,
        color: Colors.yellowAccent.withValues(alpha: 0.8),
        fontSize: 8);
  }

  void _drawTrails(Canvas canvas, Size size) {
    for (int i = 0; i < data.initialAircraft.length; i++) {
      if (i >= data.finalAircraft.length) continue;
      final init = data.initialAircraft[i];
      final final_ = data.finalAircraft[i];
      final isConflict = data.conflictPairCallsigns.contains(init.callsign);
      final isSelected = final_.wasSelected;
      final color = isConflict
          ? AppTheme.danger
          : isSelected
              ? Colors.yellowAccent
              : AppTheme.primary;

      final startPt = _map(init.x, init.y, size);
      final endPt = _lerp(init, final_, t, size);

      canvas.drawLine(
        startPt,
        endPt,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawBlips(Canvas canvas, Size size) {
    for (int i = 0; i < data.initialAircraft.length; i++) {
      if (i >= data.finalAircraft.length) continue;
      final init = data.initialAircraft[i];
      final final_ = data.finalAircraft[i];
      final isConflict = data.conflictPairCallsigns.contains(init.callsign);
      final isSelected = final_.wasSelected;

      final color = isConflict
          ? AppTheme.danger
          : isSelected
              ? Colors.yellowAccent
              : AppTheme.primary;

      final pos = _lerp(init, final_, t, size);

      // Halo for conflict
      if (isConflict && t >= conflictT * 0.7) {
        canvas.drawCircle(pos, 10 + pulseVal * 5,
            Paint()..color = AppTheme.danger.withValues(alpha: 0.15));
      }

      // Blip
      canvas.drawCircle(
          pos,
          isConflict
              ? 7
              : isSelected
                  ? 6
                  : 5,
          Paint()..color = color);

      // Heading vector
      final ease = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
      final heading = init.heading + (final_.heading - init.heading) * ease;
      final rad = heading * pi / 180;
      canvas.drawLine(
        pos,
        Offset(pos.dx + cos(rad) * 16, pos.dy + sin(rad) * 16),
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1.2,
      );

      // Label
      _drawLabel(canvas, pos + const Offset(8, -8),
          '${init.callsign}\nFL${final_.altitude}',
          color: color, fontSize: 9);
    }
  }

  void _drawLabel(Canvas canvas, Offset pos, String text,
      {required Color color, double fontSize = 10}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, height: 1.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _ReplayPainter old) =>
      old.t != t || old.sweepAngle != sweepAngle || old.pulseVal != pulseVal;
}

// ── Small reusable widgets ─────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _MetricRow extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _MetricRow(this.label, this.value, this.valueColor);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11))),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _BreakdownSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;
  final String emptyItem;
  final String Function(String value) itemLocalizer;
  const _BreakdownSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
    required this.emptyItem,
    required this.itemLocalizer,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 5),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 6),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color, fontSize: 11)),
                    Expanded(
                        child: Text(s == 'None' ? emptyItem : itemLocalizer(s),
                            style: TextStyle(
                                color: color, fontSize: 11, height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      );
}
