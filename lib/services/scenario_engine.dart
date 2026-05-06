import 'dart:math';
import 'package:flutter/material.dart';
import '../core/models/aircraft.dart';
import '../core/models/scenario.dart';
import '../core/models/scenario_result.dart';

class ScenarioEngine {
  final Scenario scenario;

  late List<Aircraft> aircraft;

  AlertLevel alertLevel = AlertLevel.normal;
  double minHorizDist = double.infinity;

  // ── Conflict tracking ──────────────────────────────────────────────────────
  bool _hadLOS = false;
  bool _warningReached = false;

  // Closest pair metrics
  double       _closestPairHoriz   = double.infinity;
  int          _closestPairVertFL  = 9999;
  double       _closestPairTimeSec = 0;
  List<String> _conflictPair       = [];
  double       _closestPairMidX    = 185; // midpoint in Flutter coords
  double       _closestPairMidY    = 215;

  // Clear ticks: physics at 50 ms → 20 ticks/s → 100 ticks = 5 s
  int _clearTicks = 0;

  // ── Command tracking ───────────────────────────────────────────────────────
  int          _goodCommands     = 0;
  int          _badCommands      = 0;
  int          _neutralCommands  = 0;
  bool         _firstCommandIssued = false;
  int          _firstCommandMs    = 0; // elapsed ms at first command
  AlertLevel   _levelAtFirstCommand = AlertLevel.normal;
  String       _firstCommandCallsign = '';
  String       _firstCommandType    = '';
  bool         _selectedAircraftCorrect = false;

  // ── Elapsed time ───────────────────────────────────────────────────────────
  int _elapsedMs = 0;

  // ── Projection constants ───────────────────────────────────────────────────
  static const _projTicks  = 30;
  static const _radarSize  = Size(370, 430);

  ScenarioEngine(this.scenario) { _reset(); }

  // ── Reset ──────────────────────────────────────────────────────────────────
  void _reset() {
    aircraft = scenario.aircraft.map((a) => Aircraft(
      callsign: a.callsign, x: a.x, y: a.y,
      heading: a.heading, speed: a.speed, altitude: a.altitude,
    )).toList();

    alertLevel       = AlertLevel.normal;
    minHorizDist     = double.infinity;
    _clearTicks      = 0;
    _hadLOS          = false;
    _warningReached  = false;

    _closestPairHoriz   = double.infinity;
    _closestPairVertFL  = 9999;
    _closestPairTimeSec = 0;
    _conflictPair       = [];
    _closestPairMidX    = 185;
    _closestPairMidY    = 215;

    _goodCommands          = 0;
    _badCommands           = 0;
    _neutralCommands       = 0;
    _firstCommandIssued    = false;
    _firstCommandMs        = 0;
    _levelAtFirstCommand   = AlertLevel.normal;
    _firstCommandCallsign  = '';
    _firstCommandType      = '';
    _selectedAircraftCorrect = false;

    _elapsedMs = 0;
  }

  // ── Physics (call every 50 ms) ─────────────────────────────────────────────
  void update(Size size) {
    _elapsedMs += 50;
    for (final a in aircraft) a.update(size);

    alertLevel   = _computeAlert();
    minHorizDist = _minHoriz();

    // Update closest pair record
    _updateClosestPair();

    // Track warning + LOS history
    if (alertLevel == AlertLevel.warning || alertLevel == AlertLevel.advisory) {
      _warningReached = true;
    }
    if (alertLevel == AlertLevel.los) {
      _hadLOS         = true;
      _warningReached = true;
      _clearTicks     = 0;
    } else if (minHorizDist > scenario.conflictRules.minHorizontalDistancePx) {
      _clearTicks++;
    } else {
      _clearTicks = 0;
    }
  }

  bool get separationMaintained =>
      _clearTicks >= scenario.maintainSafeSeparationForSeconds * 20;

  // ── Closest pair ──────────────────────────────────────────────────────────
  void _updateClosestPair() {
    double minH = double.infinity;
    int    minV = 9999;
    String a1 = '', a2 = '';
    double midX = 185, midY = 215;

    for (int i = 0; i < aircraft.length; i++) {
      for (int j = i + 1; j < aircraft.length; j++) {
        final dx = aircraft[i].x - aircraft[j].x;
        final dy = aircraft[i].y - aircraft[j].y;
        final h  = sqrt(dx * dx + dy * dy);
        if (h < minH) {
          minH = h;
          minV = (aircraft[i].altitude - aircraft[j].altitude).abs();
          a1   = aircraft[i].callsign;
          a2   = aircraft[j].callsign;
          midX = (aircraft[i].x + aircraft[j].x) / 2;
          midY = (aircraft[i].y + aircraft[j].y) / 2;
        }
      }
    }

    if (minH < _closestPairHoriz) {
      _closestPairHoriz   = minH;
      _closestPairVertFL  = minV;
      _closestPairTimeSec = _elapsedMs / 1000.0;
      _conflictPair       = [a1, a2];
      _closestPairMidX    = midX;
      _closestPairMidY    = midY;
    }
  }

  // ── Alert level ────────────────────────────────────────────────────────────
  AlertLevel _computeAlert() {
    final r = scenario.conflictRules;
    double minH = double.infinity;
    int    minV = 9999;
    for (int i = 0; i < aircraft.length; i++) {
      for (int j = i + 1; j < aircraft.length; j++) {
        final dx = aircraft[i].x - aircraft[j].x;
        final dy = aircraft[i].y - aircraft[j].y;
        final h  = sqrt(dx * dx + dy * dy);
        final v  = (aircraft[i].altitude - aircraft[j].altitude).abs();
        if (h < minH) { minH = h; minV = v; }
      }
    }
    if (minH <= r.minHorizontalDistancePx && minV < r.minVerticalSeparationFL) {
      return AlertLevel.los;
    }
    if (minH <= r.warningDistancePx)  return AlertLevel.warning;
    if (minH <= r.advisoryDistancePx) return AlertLevel.advisory;
    return AlertLevel.normal;
  }

  double _minHoriz() {
    double min = double.infinity;
    for (int i = 0; i < aircraft.length; i++) {
      for (int j = i + 1; j < aircraft.length; j++) {
        final dx = aircraft[i].x - aircraft[j].x;
        final dy = aircraft[i].y - aircraft[j].y;
        final d  = sqrt(dx * dx + dy * dy);
        if (d < min) min = d;
      }
    }
    return min;
  }

  // ── Projected separation ───────────────────────────────────────────────────
  double _projectedMinHoriz() {
    final clones = aircraft.map((a) => Aircraft(
      callsign: a.callsign, x: a.x, y: a.y,
      heading: a.heading, speed: a.speed, altitude: a.altitude,
    )).toList();
    for (int t = 0; t < _projTicks; t++) {
      for (final c in clones) c.update(_radarSize);
    }
    double min = double.infinity;
    for (int i = 0; i < clones.length; i++) {
      for (int j = i + 1; j < clones.length; j++) {
        final dx = clones[i].x - clones[j].x;
        final dy = clones[i].y - clones[j].y;
        final d  = sqrt(dx * dx + dy * dy);
        if (d < min) min = d;
      }
    }
    return min;
  }

  bool _altitudeSeparationRestored() {
    final r = scenario.conflictRules;
    for (int i = 0; i < aircraft.length; i++) {
      for (int j = i + 1; j < aircraft.length; j++) {
        final dx    = aircraft[i].x - aircraft[j].x;
        final dy    = aircraft[i].y - aircraft[j].y;
        final horiz = sqrt(dx * dx + dy * dy);
        if (horiz < r.advisoryDistancePx) {
          final vert = (aircraft[i].altitude - aircraft[j].altitude).abs();
          if (vert >= r.minVerticalSeparationFL) return true;
        }
      }
    }
    return false;
  }

  // ── Commands ───────────────────────────────────────────────────────────────
  /// Returns 'good' | 'neutral' | 'bad'
  String issueCommand(String callsign, String command) {
    if (!_firstCommandIssued) {
      _firstCommandIssued   = true;
      _firstCommandMs       = _elapsedMs;
      _levelAtFirstCommand  = alertLevel;
      _firstCommandCallsign = callsign;
      _firstCommandType     = command;

      // Correct aircraft = selected from conflict pair when in warning/LOS
      if (alertLevel.index >= AlertLevel.warning.index) {
        _selectedAircraftCorrect = _conflictPair.contains(callsign);
      } else {
        // Proactive action before warning — always count as correct
        _selectedAircraftCorrect = true;
      }
    }

    final projBefore = _projectedMinHoriz();
    final a = aircraft.firstWhere((a) => a.callsign == callsign,
        orElse: () => aircraft.first);

    switch (command) {
      case 'left':    a.heading -= 15;
      case 'right':   a.heading += 15;
      case 'climb':   a.altitude += 10;
      case 'descend': a.altitude -= 10;
      case 'slow':    a.speed = max(0.2, a.speed - 0.1);
      case 'fast':    a.speed = min(1.8,  a.speed + 0.1);
    }

    if ((command == 'climb' || command == 'descend') && _altitudeSeparationRestored()) {
      _goodCommands++;
      return 'good';
    }

    final projAfter = _projectedMinHoriz();
    if (projAfter > projBefore + 2.0) { _goodCommands++;   return 'good'; }
    if (projAfter < projBefore - 2.0) { _badCommands++;    return 'bad';  }
    _neutralCommands++;
    return 'neutral';
  }

  // ── Finalize ───────────────────────────────────────────────────────────────
  ScenarioResult finalize(int timeLeft) {
    final penalties = <String>[];
    final bonuses   = <String>[];
    int score = 120;

    // ── Penalties ────────────────────────────────────────────────────────────

    if (_hadLOS) {
      score -= 60;
      penalties.add('Loss of separation: −60');
    } else if (_warningReached) {
      score -= 25;
      penalties.add('Warning zone reached: −25');
    }

    if (!_firstCommandIssued) {
      score -= 30;
      penalties.add('No command issued: −30');
    } else {
      final reactionSec = _firstCommandMs / 1000.0;
      if (reactionSec > 12) {
        score -= 20;
        penalties.add('Late command (${reactionSec.toStringAsFixed(0)} s): −20');
      } else if (reactionSec > 8) {
        score -= 10;
        penalties.add('Late command (${reactionSec.toStringAsFixed(0)} s): −10');
      }

      if (!_selectedAircraftCorrect) {
        score -= 20;
        penalties.add('Wrong aircraft selected: −20');
      }
    }

    if (_badCommands > 0) {
      final pen = _badCommands * 25;
      score -= pen;
      penalties.add(
          'Ineffective command${_badCommands > 1 ? " ×$_badCommands" : ""}: −$pen');
    }

    // Over-control: first neutral is "ok", subsequent ones are penalised
    final overControl = _neutralCommands > 1 ? _neutralCommands - 1 : 0;
    if (overControl > 0) {
      final pen = overControl * 10;
      score -= pen;
      penalties.add('Unnecessary command${overControl > 1 ? " ×$overControl" : ""}: −$pen');
    }

    // ── Bonuses ──────────────────────────────────────────────────────────────

    if (separationMaintained) {
      score += 10;
      bonuses.add('Safe separation maintained: +10');
    }

    if (_firstCommandIssued && _selectedAircraftCorrect) {
      score += 10;
      bonuses.add('Correct aircraft selected: +10');
    }

    if (_firstCommandIssued && _goodCommands > 0) {
      final reactionSec = _firstCommandMs / 1000.0;
      if (reactionSec < 5.0) {
        score += 10;
        bonuses.add('Early effective action: +10');
      }
    }

    score = score.clamp(0, 120);

    // ── Rating (V1 thresholds) ────────────────────────────────────────────────
    final ScenarioRating rating;
    if (score >= 105)     rating = ScenarioRating.excellent;
    else if (score >= 80) rating = ScenarioRating.safe;
    else if (score >= 50) rating = ScenarioRating.needsImprovement;
    else                  rating = ScenarioRating.unsafe;

    // ── Explanations ──────────────────────────────────────────────────────────
    final pairStr = _conflictPair.isNotEmpty
        ? _conflictPair.join(' & ')
        : 'aircraft';
    final sepStr  = _closestPairHoriz == double.infinity
        ? 'N/A'
        : '${_closestPairHoriz.toStringAsFixed(0)} px';
    final vertStr = _closestPairVertFL == 9999
        ? 'N/A'
        : '${(_closestPairVertFL * 100)} ft';

    final short = _hadLOS
        ? '$pairStr lost separation (closest: $sepStr / $vertStr).'
        : 'Closest separation: $sepStr horizontal, $vertStr vertical between $pairStr.';

    final reactionStr = _firstCommandIssued
        ? '${(_firstCommandMs / 1000.0).toStringAsFixed(1)} s'
        : 'no command';

    final long = _buildLongExplanation(
      pairStr: pairStr, sepStr: sepStr, vertStr: vertStr,
      reactionStr: reactionStr, penalties: penalties, bonuses: bonuses,
    );

    return ScenarioResult(
      score: score,
      rating: rating,
      hadLOS: _hadLOS,
      warningReached: _warningReached,
      resolvedInFirstHalf: timeLeft > scenario.timeLimitSeconds ~/ 2,
      separationMaintained: separationMaintained,
      minHorizontalDistancePx: _closestPairHoriz == double.infinity
          ? 999 : _closestPairHoriz,
      minVerticalDistanceFt: _closestPairVertFL == 9999
          ? 0 : _closestPairVertFL * 100,
      closestPointTimeSec: _closestPairTimeSec,
      conflictPair: _conflictPair.isEmpty ? ['—'] : _conflictPair,
      reactionTimeSec: _firstCommandMs / 1000.0,
      selectedAircraftCorrect: _selectedAircraftCorrect,
      goodCommands: _goodCommands,
      badCommands: _badCommands,
      neutralCommands: _neutralCommands,
      levelAtFirstCommand: _levelAtFirstCommand,
      penaltyBreakdown: penalties.isEmpty ? ['None'] : penalties,
      bonusBreakdown: bonuses.isEmpty ? ['None'] : bonuses,
      replayExplanationShort: short,
      replayExplanationLong: long,
    );
  }

  String _buildLongExplanation({
    required String pairStr, required String sepStr, required String vertStr,
    required String reactionStr,
    required List<String> penalties, required List<String> bonuses,
  }) {
    final sb = StringBuffer();

    if (_hadLOS) {
      sb.write(
          '$pairStr came within $sepStr horizontal and $vertStr vertical — '
          'below the 60 px / 1 000 ft loss-of-separation threshold. ');
    } else if (_warningReached) {
      sb.write(
          '$pairStr entered the warning zone (closest: $sepStr / $vertStr). '
          'Separation was not lost but reached a critical level. ');
    } else {
      sb.write(
          'Separation was maintained. Closest point: $sepStr horizontal / $vertStr vertical. ');
    }

    if (!_firstCommandIssued) {
      sb.write('No command was issued during the scenario.');
    } else {
      sb.write('First command issued after $reactionStr. ');
      if (_goodCommands > 0) {
        sb.write('$_goodCommands effective command${_goodCommands > 1 ? "s" : ""} '
            'improved projected separation. ');
      }
      if (_badCommands > 0) {
        sb.write('$_badCommands command${_badCommands > 1 ? "s" : ""} '
            'worsened or had no effect on projected separation. ');
      }
    }

    return sb.toString().trim();
  }

  // ── Exposed helpers for ReplayData ─────────────────────────────────────────
  double get closestPairMidX    => _closestPairMidX;
  double get closestPairMidY    => _closestPairMidY;
  String get firstCommandType   => _firstCommandType;
  String get firstCommandCallsign => _firstCommandCallsign;
  bool   get warningReached     => _warningReached;
}
