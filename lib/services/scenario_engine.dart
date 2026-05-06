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

  // Clear ticks: physics at 50 ms → 20 ticks/s → 100 ticks = 5 s
  int _clearTicks = 0;
  bool _hadLOS = false;

  int _goodCommands = 0;
  int _badCommands  = 0;
  AlertLevel _levelAtFirstCommand = AlertLevel.normal;
  bool _firstCommandIssued = false;

  int _elapsedMs = 0;

  ScenarioEngine(this.scenario) {
    _reset();
  }

  void _reset() {
    aircraft = scenario.aircraft.map((a) => Aircraft(
      callsign: a.callsign,
      x: a.x,
      y: a.y,
      heading: a.heading,
      speed: a.speed,
      altitude: a.altitude,
    )).toList();
    alertLevel = AlertLevel.normal;
    minHorizDist = double.infinity;
    _clearTicks = 0;
    _hadLOS = false;
    _goodCommands = 0;
    _badCommands = 0;
    _firstCommandIssued = false;
    _elapsedMs = 0;
  }

  // ── Physics (call every 50 ms) ───────────────────────────────────────────
  void update(Size size) {
    _elapsedMs += 50;
    for (final a in aircraft) {
      a.update(size);
    }
    alertLevel = _computeAlert();
    minHorizDist = _minHoriz();

    final r = scenario.conflictRules;
    if (alertLevel == AlertLevel.los) {
      _hadLOS = true;
      _clearTicks = 0;
    } else if (minHorizDist > r.minHorizontalDistancePx) {
      _clearTicks++;
    } else {
      _clearTicks = 0;
    }
  }

  bool get separationMaintained =>
      _clearTicks >= scenario.maintainSafeSeparationForSeconds * 20;

  // ── Alert level ──────────────────────────────────────────────────────────
  AlertLevel _computeAlert() {
    final r = scenario.conflictRules;
    double minH = double.infinity;
    int minV = 9999;
    for (int i = 0; i < aircraft.length; i++) {
      for (int j = i + 1; j < aircraft.length; j++) {
        final dx = aircraft[i].x - aircraft[j].x;
        final dy = aircraft[i].y - aircraft[j].y;
        final h = sqrt(dx * dx + dy * dy);
        final v = (aircraft[i].altitude - aircraft[j].altitude).abs();
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
        min = min < sqrt(dx * dx + dy * dy) ? min : sqrt(dx * dx + dy * dy);
      }
    }
    return min;
  }

  // ── Commands ─────────────────────────────────────────────────────────────
  // Returns 'good' | 'neutral' | 'bad'
  String issueCommand(String callsign, String command) {
    if (!_firstCommandIssued) {
      _firstCommandIssued = true;
      _levelAtFirstCommand = alertLevel;
    }

    final prevMin = _minHoriz();
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

    // One-step lookahead to gauge direction
    final newMin = _minHoriz();
    if (newMin > prevMin + 1.5) {
      _goodCommands++;
      return 'good';
    }
    if (newMin < prevMin - 1.5) {
      _badCommands++;
      return 'bad';
    }
    return 'neutral';
  }

  // ── Final result ─────────────────────────────────────────────────────────
  ScenarioResult finalize(int timeLeft) {
    int score = 100;

    // LOS penalty
    if (_hadLOS) score -= 50;

    // Late first action penalty
    if (_levelAtFirstCommand.index >= AlertLevel.warning.index) score -= 30;

    // Bad command penalty
    score -= _badCommands * 10;

    // Good command bonus
    score += _goodCommands * 5;

    // Separation maintained bonus
    if (separationMaintained) score += 10;

    // Time bonus
    final resolvedEarly = timeLeft > scenario.timeLimitSeconds ~/ 2;
    if (resolvedEarly) score += 20;

    score = score.clamp(0, 120);

    final ScenarioRating rating;
    if (score >= 90) {
      rating = ScenarioRating.excellent;
    } else if (score >= 70) {
      rating = ScenarioRating.safe;
    } else if (score >= 40) {
      rating = ScenarioRating.needsImprovement;
    } else {
      rating = ScenarioRating.unsafe;
    }

    return ScenarioResult(
      score: score,
      rating: rating,
      hadLOS: _hadLOS,
      resolvedInFirstHalf: resolvedEarly,
      goodCommands: _goodCommands,
      badCommands: _badCommands,
      separationMaintained: separationMaintained,
      levelAtFirstCommand: _levelAtFirstCommand,
    );
  }
}
