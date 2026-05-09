import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/aircraft.dart';
import '../core/theme/app_theme.dart';
import '../data/radar_levels.dart';
import '../l10n/app_localizations.dart';
import '../models/radar_level_config.dart';
import '../services/daily_challenge_service.dart';
import '../services/pilot_radio_audio_service.dart';
import '../services/progression_service.dart';
import '../services/radio_audio_settings_service.dart';
import '../widgets/radar_painter.dart';

enum _ScenarioState { playing, success, failed }

class RadarSimulationScreen extends StatefulWidget {
  const RadarSimulationScreen({super.key});

  @override
  State<RadarSimulationScreen> createState() => _RadarSimulationScreenState();
}

class _RadarSimulationScreenState extends State<RadarSimulationScreen>
    with SingleTickerProviderStateMixin {
  // ── Sweep ─────────────────────────────────────────────────────────────────
  late final AnimationController _sweepCtrl;
  double _sweepAngle = 0;

  // ── Config ────────────────────────────────────────────────────────────────
  late RadarLevelConfig _config;

  // ── Physics ───────────────────────────────────────────────────────────────
  bool _running = true;
  late List<Aircraft> _aircraft;
  Aircraft? _selected;

  // ── Scenario state ────────────────────────────────────────────────────────
  _ScenarioState _state = _ScenarioState.playing;
  int _timeLeft = 60;
  int _score = 100;
  int _conflictFreeTicks = 0;
  bool _everSelected = false;
  int _xpEarned = 0;
  final PilotRadioAudioService _radioAudio = PilotRadioAudioService.instance;
  final RadioAudioSettingsService _audioSettings =
      RadioAudioSettingsService.instance;
  bool _playedConflictWarning = false;
  bool _playedRunwayPressureWarning = false;
  bool _playedOverloadWarning = false;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _countdownTimer;
  Timer? _penaltyTimer;

  // ── Conflict ──────────────────────────────────────────────────────────────
  bool get _hasConflict {
    for (int i = 0; i < _aircraft.length; i++) {
      for (int j = i + 1; j < _aircraft.length; j++) {
        final dx = _aircraft[i].x - _aircraft[j].x;
        final dy = _aircraft[i].y - _aircraft[j].y;
        final horiz = sqrt(dx * dx + dy * dy);
        final vert = (_aircraft[i].altitude - _aircraft[j].altitude).abs();
        if (horiz < _config.conflictDistancePx && vert < 10) return true;
      }
    }
    return false;
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  void _loadConfig() {
    _config =
        RadarLevelConfig.forLevel(ProgressionService.instance.currentLevel);
  }

  void _initAircraft() {
    _aircraft = _config.aircraft
        .map((a) => Aircraft(
              callsign: a.callsign,
              x: a.x,
              y: a.y,
              heading: a.heading,
              speed: a.speed * _config.speedMultiplier,
              altitude: a.altitude,
            ))
        .toList();
  }

  void _startTimers() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state != _ScenarioState.playing) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _state = _ScenarioState.failed;
          _stopTimers();
          ProgressionService.instance.awardParticipationXp();
        }
      });
    });

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
    _loadConfig();
    _initAircraft();
    _audioSettings.ensureLoaded();
    _radioAudio.initialize();
    _timeLeft = _config.timeLimitSeconds;
    _score = _config.startingScore;

    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() => setState(() => _sweepAngle += 0.018));
    _sweepCtrl.repeat();

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
            if (_conflictFreeTicks >= _config.requiredClearTicks) {
              _xpEarned = _config.successBonus + 100;
              if (_score >= 100) _xpEarned += 50;
              _score = min(_config.startingScore + _config.successBonus,
                  _score + _config.successBonus);
              _state = _ScenarioState.success;
              _stopTimers();
              ProgressionService.instance.completeLevel(_config.level, _score);
            }
          } else {
            _conflictFreeTicks = 0;
          }
        });
        _tickPlaybackWarnings();
      }
      return true;
    });

    _startTimers();
  }

  void _resetScenario({int? level}) {
    _stopTimers();
    if (level != null) {
      _config = RadarLevelConfig.forLevel(level);
    }
    _initAircraft();
    setState(() {
      _state = _ScenarioState.playing;
      _timeLeft = _config.timeLimitSeconds;
      _score = _config.startingScore;
      _conflictFreeTicks = 0;
      _selected = null;
      _everSelected = false;
      _xpEarned = 0;
      _playedConflictWarning = false;
      _playedRunwayPressureWarning = false;
      _playedOverloadWarning = false;
    });
    _radioAudio.clearQueue(stopCurrent: true);
    _startTimers();
  }

  @override
  void dispose() {
    _running = false;
    _radioAudio.clearQueue(stopCurrent: true);
    _sweepCtrl.dispose();
    _stopTimers();
    super.dispose();
  }

  // ── Commands ──────────────────────────────────────────────────────────────
  void _issueCommand(String type) {
    final a = _selected;
    if (a == null) return;
    setState(() {
      _score = max(0, _score - 2);
      switch (type) {
        case 'left':
          a.heading -= 15;
        case 'right':
          a.heading += 15;
        case 'climb':
          a.altitude += 10;
        case 'descend':
          a.altitude -= 10;
        case 'slow':
          a.speed = max(0.2, a.speed - 0.1);
        case 'fast':
          a.speed = min(1.8, a.speed + 0.1);
      }
    });
    _enqueuePilotAck(a, type);
  }

  void _enqueuePilotAck(Aircraft a, String command) {
    final heading = a.heading.round() % 360;
    final headingText = heading.toString().padLeft(3, '0');
    final speedText = (a.speed * 200).round();
    final altitudeFt = a.altitude * 100;

    final text = switch (command) {
      'left' => '${a.callsign} turning heading $headingText',
      'right' => '${a.callsign} turning heading $headingText',
      'climb' => '${a.callsign} climbing $altitudeFt',
      'descend' => '${a.callsign} descending $altitudeFt',
      'slow' => '${a.callsign} reducing speed $speedText',
      'fast' => '${a.callsign} increasing speed $speedText',
      _ => '${a.callsign} roger',
    };
    _radioAudio.enqueuePilotAck(callsign: a.callsign, spokenText: text);
  }

  void _tickPlaybackWarnings() {
    if (!_audioSettings.settings.value.warningsEnabled ||
        _state != _ScenarioState.playing) {
      return;
    }
    final conflict = _hasConflict;

    if (!_playedConflictWarning && conflict) {
      _playedConflictWarning = true;
      _radioAudio.enqueueWarning(RadioWarningType.conflict, interrupt: true);
    }

    if (!_playedRunwayPressureWarning && _timeLeft <= 12) {
      _playedRunwayPressureWarning = true;
      _radioAudio.enqueueWarning(RadioWarningType.runwayPressure);
    }

    if (!_playedOverloadWarning && _score <= 35) {
      _playedOverloadWarning = true;
      _radioAudio.enqueueWarning(RadioWarningType.overloadPeak,
          interrupt: true);
    }
  }

  // ── Score colour ──────────────────────────────────────────────────────────
  Color _scoreColor() {
    if (_score >= 80) return AppTheme.primary;
    if (_score >= 40) return AppTheme.warning;
    return AppTheme.danger;
  }

  // ── Technique label ───────────────────────────────────────────────────────
  String _techniqueLabel(AppLocalizations l10n) {
    switch (_config.primaryTechnique) {
      case 'heading':
        return l10n.radarTechHeading;
      case 'altitude':
        return l10n.radarTechAltitude;
      case 'speed':
        return l10n.radarTechSpeed;
      default:
        return l10n.radarTechMixed;
    }
  }

  // ── Rank label ────────────────────────────────────────────────────────────
  String _rankLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'progRankMaster':
        return l10n.progRankMaster;
      case 'progRankSenior':
        return l10n.progRankSenior;
      case 'progRankController':
        return l10n.progRankController;
      case 'progRankTrainee':
        return l10n.progRankTrainee;
      default:
        return l10n.progRankCadet;
    }
  }

  // ── Level scenario name ───────────────────────────────────────────────────
  String _levelName(AppLocalizations l10n) {
    switch (_config.scenarioKey) {
      case 'radarLevel1Name':
        return l10n.radarLevel1Name;
      case 'radarLevel2Name':
        return l10n.radarLevel2Name;
      case 'radarLevel3Name':
        return l10n.radarLevel3Name;
      case 'radarLevel4Name':
        return l10n.radarLevel4Name;
      case 'radarLevel5Name':
        return l10n.radarLevel5Name;
      case 'radarLevel6Name':
        return l10n.radarLevel6Name;
      case 'radarLevel7Name':
        return l10n.radarLevel7Name;
      case 'radarLevel8Name':
        return l10n.radarLevel8Name;
      case 'radarLevel9Name':
        return l10n.radarLevel9Name;
      case 'radarLevel10Name':
        return l10n.radarLevel10Name;
      default:
        return _config.scenarioKey;
    }
  }

  // ── Level failure tip ─────────────────────────────────────────────────────
  String _levelTip(AppLocalizations l10n) {
    switch (_config.tipKey) {
      case 'radarLevel1Tip':
        return l10n.radarLevel1Tip;
      case 'radarLevel2Tip':
        return l10n.radarLevel2Tip;
      case 'radarLevel3Tip':
        return l10n.radarLevel3Tip;
      case 'radarLevel4Tip':
        return l10n.radarLevel4Tip;
      case 'radarLevel5Tip':
        return l10n.radarLevel5Tip;
      case 'radarLevel6Tip':
        return l10n.radarLevel6Tip;
      case 'radarLevel7Tip':
        return l10n.radarLevel7Tip;
      case 'radarLevel8Tip':
        return l10n.radarLevel8Tip;
      case 'radarLevel9Tip':
        return l10n.radarLevel9Tip;
      case 'radarLevel10Tip':
        return l10n.radarLevel10Tip;
      default:
        return '';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prog = ProgressionService.instance;
    final conflict = _hasConflict;
    final resolving =
        !conflict && _conflictFreeTicks > 0 && _state == _ScenarioState.playing;
    final resolvePct =
        (_conflictFreeTicks / _config.requiredClearTicks).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.radarSimTitle),
            Text(
              '${l10n.radarLevelLabel(_config.level)} · '
              '${_rankLabel(l10n, prog.rankKey)} · '
              '${l10n.radarTotalXp(prog.totalXp)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
        actions: [
          // Timer
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _timeLeft <= 15
                      ? AppTheme.danger.withValues(alpha: 0.2)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _timeLeft <= 15
                        ? AppTheme.danger
                        : AppTheme.borderColor,
                  ),
                ),
                child: Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    color: _timeLeft <= 15
                        ? AppTheme.danger
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          // Score
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '$_score / ${_config.startingScore + _config.successBonus}',
                style: TextStyle(
                  color: _scoreColor(),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
          SafeArea(
            child: Column(
              children: [
                // ── Scenario description ──────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.adjust,
                          color: AppTheme.secondary, size: 13),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.radarLevelLabel(_config.level)} — ${_levelName(l10n)}',
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              l10n.radarTechnique(_techniqueLabel(l10n)),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (prog.getBestScore(_config.level) > 0)
                        Text(
                          l10n.radarBestScore(prog.getBestScore(_config.level)),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Status bar ────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                        size: 15,
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
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (resolving)
                        SizedBox(
                          width: 55,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: resolvePct,
                              minHeight: 3,
                              color: AppTheme.primary,
                              backgroundColor: AppTheme.borderColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── How-to hint (until first selection) ──────────────────────
                if (!_everSelected && _state == _ScenarioState.playing)
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

                // ── Radar ─────────────────────────────────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTapDown: (d) {
                      if (_state != _ScenarioState.playing) return;
                      final p = d.localPosition;
                      Aircraft? hit;
                      double minDist = 32;
                      for (final a in _aircraft) {
                        final dist =
                            sqrt(pow(p.dx - a.x, 2) + pow(p.dy - a.y, 2));
                        if (dist < minDist) {
                          minDist = dist;
                          hit = a;
                        }
                      }
                      setState(() {
                        _selected = hit;
                        if (hit != null) _everSelected = true;
                      });
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

                // ── Selected aircraft info ─────────────────────────────────────
                if (_selected != null && _state == _ScenarioState.playing)
                  Container(
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
                          '${_selected!.callsign}  FL${_selected!.altitude}  '
                          'HDG ${_selected!.heading.toInt()}°  '
                          'SPD ${_selected!.speed.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Command buttons ────────────────────────────────────────────
                if (_state == _ScenarioState.playing)
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
                            _selected != null
                                ? () => _issueCommand('left')
                                : null),
                        _cmdBtn(
                            l10n.cmdTurnRight,
                            _selected != null
                                ? () => _issueCommand('right')
                                : null),
                        _cmdBtn(
                            l10n.cmdClimb,
                            _selected != null
                                ? () => _issueCommand('climb')
                                : null),
                        _cmdBtn(
                            l10n.cmdDescend,
                            _selected != null
                                ? () => _issueCommand('descend')
                                : null),
                        _cmdBtn(
                            l10n.cmdSlow,
                            _selected != null
                                ? () => _issueCommand('slow')
                                : null),
                        _cmdBtn(
                            l10n.cmdFast,
                            _selected != null
                                ? () => _issueCommand('fast')
                                : null),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Result overlay ─────────────────────────────────────────────────
          if (_state != _ScenarioState.playing)
            SafeArea(
              child: _ResultOverlay(
                success: _state == _ScenarioState.success,
                level: _config.level,
                score: _score,
                xpEarned: _xpEarned,
                tip: _state == _ScenarioState.failed ? _levelTip(l10n) : null,
                hasNextLevel: _config.level < RadarLevelConfig.maxLevel,
                onReset: () => _resetScenario(),
                onNextLevel: _config.level < RadarLevelConfig.maxLevel
                    ? () => _resetScenario(level: _config.level + 1)
                    : null,
              ),
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

// ── Result overlay ─────────────────────────────────────────────────────────

class _ResultOverlay extends StatelessWidget {
  final bool success;
  final int level;
  final int score;
  final int xpEarned;
  final String? tip;
  final bool hasNextLevel;
  final VoidCallback onReset;
  final VoidCallback? onNextLevel;

  const _ResultOverlay({
    required this.success,
    required this.level,
    required this.score,
    required this.xpEarned,
    required this.tip,
    required this.hasNextLevel,
    required this.onReset,
    required this.onNextLevel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prog = ProgressionService.instance;
    final maxScore =
        allLevels[level - 1].startingScore + allLevels[level - 1].successBonus;

    return Container(
      color: AppTheme.background.withValues(alpha: 0.94),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success ? Icons.verified : Icons.cancel_outlined,
                size: 72,
                color: success ? AppTheme.primary : AppTheme.danger,
              ),
              const SizedBox(height: 16),
              Text(
                success
                    ? l10n.radarLevelComplete(level)
                    : l10n.radarV2ScenarioFailed,
                style: TextStyle(
                  color: success ? AppTheme.primary : AppTheme.danger,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              if (success) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.radarV2SuccessHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
                ),
              ],
              const SizedBox(height: 12),
              // Score / XP row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InfoCell(
                        label: l10n.radarV2FinalScore,
                        value: '$score / $maxScore'),
                    if (success) ...[
                      const SizedBox(width: 24),
                      _InfoCell(
                          label: 'XP',
                          value: '+$xpEarned',
                          valueColor: AppTheme.primary),
                    ],
                    const SizedBox(width: 24),
                    _InfoCell(
                      label: 'TOTAL XP',
                      value: '${prog.totalXp}',
                      valueColor: AppTheme.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Failure tip
              if (!success && tip != null && tip!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppTheme.warning, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip!,
                          style: const TextStyle(
                              color: AppTheme.warning,
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              // Buttons
              if (success && hasNextLevel)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(l10n.radarNextLevel(level + 1)),
                    onPressed: onNextLevel,
                  ),
                ),
              if (success && !hasNextLevel)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stars_rounded, size: 16),
                    label: Text(l10n.radarAllLevelsComplete),
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: AppTheme.background,
                    ),
                  ),
                ),
              if (success) const SizedBox(height: 10),
              if (success)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flag_rounded, size: 15),
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
              if (success) const SizedBox(height: 10),
              if (success)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 15),
                    label: Text(l10n.radarShareCopied.split('—').first.trim()),
                    onPressed: () async {
                      final shareText = l10n.radarShareText(level, score);
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.radarShareCopied),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 15),
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

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
