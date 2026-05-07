import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/replay_event.dart';
import '../models/scenario_result.dart';

/// Animated 2-D radar replay driven by [DetailedScenarioResult].
/// Shows aircraft moving along interpolated tracks, conflict events,
/// and user action markers.
class RadarReplayView extends StatefulWidget {
  final DetailedScenarioResult result;
  final ValueNotifier<double>? externalProgress; // 0→1, optional external control

  const RadarReplayView({
    super.key,
    required this.result,
    this.externalProgress,
  });

  @override
  State<RadarReplayView> createState() => _RadarReplayViewState();
}

class _RadarReplayViewState extends State<RadarReplayView>
    with TickerProviderStateMixin {

  late AnimationController _sweepCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sweepCtrl, _pulseCtrl]),
      builder: (context, _) {
        final t = widget.externalProgress?.value ?? 0.0;
        return CustomPaint(
          painter: _RadarReplayPainter(
            result:     widget.result,
            t:          t,
            sweepAngle: _sweepCtrl.value * 2 * pi,
            pulseVal:   _pulseCtrl.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────

class _RadarReplayPainter extends CustomPainter {
  final DetailedScenarioResult result;
  final double t;           // 0→1 replay progress
  final double sweepAngle;
  final double pulseVal;

  static const _srcW = 370.0;
  static const _srcH = 430.0;

  const _RadarReplayPainter({
    required this.result,
    required this.t,
    required this.sweepAngle,
    required this.pulseVal,
  });

  // ── Frame lookup ───────────────────────────────────────────────────────────
  AircraftStateFrame? _frameAt(String callsign, double targetSec) {
    AircraftStateFrame? best;
    for (final f in result.replayFrames) {
      if (f.callsign != callsign) continue;
      if (f.timestampSeconds <= targetSec) best = f;
    }
    return best;
  }

  Set<String> get _conflictCallsigns {
    for (final e in result.replayEvents) {
      if (e.eventType == ReplayEventType.separationLoss ||
          e.eventType == ReplayEventType.conflictWarning) {
        return e.aircraftId.split('/').toSet();
      }
    }
    return {};
  }

  Set<String> get _selectedCallsigns {
    final sel = <String>{};
    for (final a in result.userActions) {
      sel.add(a.callsign);
    }
    return sel;
  }

  Offset _toCanvas(double x, double y, Size size) => Offset(
        x / _srcW * size.width,
        y / _srcH * size.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawSweep(canvas, size);

    final currentSec = t * result.totalDurationSeconds;
    final conflict   = _conflictCallsigns;
    final selected   = _selectedCallsigns;

    // Draw trails + blips for each unique callsign
    final callsigns = result.replayFrames.map((f) => f.callsign).toSet();
    for (final cs in callsigns) {
      final isConflict = conflict.contains(cs);
      final isSelected = selected.contains(cs);
      final color      = isConflict ? AppTheme.danger
                       : isSelected ? Colors.yellowAccent
                       : AppTheme.primary;
      _drawTrail(canvas, size, cs, currentSec, color);
      _drawBlip(canvas, size, cs, currentSec, color, isConflict);
    }

    _drawEventMarkers(canvas, size, currentSec);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) * 0.46;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF050F0A));

    final ring = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final frac in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(c, r * frac, ring);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);
  }

  void _drawSweep(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) * 0.46;
    final tip = Offset(c.dx + cos(sweepAngle) * r, c.dy + sin(sweepAngle) * r);

    canvas.drawLine(c, tip,
        Paint()..color = AppTheme.primary.withValues(alpha: 0.08)..strokeWidth = 10);
    canvas.drawLine(c, tip,
        Paint()..color = AppTheme.primary.withValues(alpha: 0.65)..strokeWidth = 1.4);
  }

  void _drawTrail(Canvas canvas, Size size, String cs, double sec, Color color) {
    final path = Path();
    bool started = false;
    for (final f in result.replayFrames) {
      if (f.callsign != cs || f.timestampSeconds > sec) continue;
      final pt = _toCanvas(f.x, f.y, size);
      if (!started) { path.moveTo(pt.dx, pt.dy); started = true; }
      else          { path.lineTo(pt.dx, pt.dy); }
    }
    if (started) {
      canvas.drawPath(path,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round);
    }
  }

  void _drawBlip(Canvas canvas, Size size, String cs, double sec,
      Color color, bool isConflict) {
    final frame = _frameAt(cs, sec);
    if (frame == null) return;
    final pos = _toCanvas(frame.x, frame.y, size);

    // Conflict halo
    if (isConflict) {
      canvas.drawCircle(pos, 10 + pulseVal * 6,
          Paint()..color = AppTheme.danger.withValues(alpha: 0.13));
    }

    // Heading vector
    final rad = frame.heading * pi / 180;
    canvas.drawLine(pos,
        Offset(pos.dx + cos(rad) * 14, pos.dy + sin(rad) * 14),
        Paint()..color = color.withValues(alpha: 0.55)..strokeWidth = 1.1);

    // Blip
    canvas.drawCircle(pos, isConflict ? 6.5 : 5,
        Paint()..color = color);

    // Label
    _label(canvas, pos + const Offset(8, -8),
        '$cs\nFL${frame.altitude}', color: color, size: 9);
  }

  void _drawEventMarkers(Canvas canvas, Size size, double sec) {
    for (final e in result.replayEvents) {
      if (e.timestampSeconds > sec) continue;
      final pos = _toCanvas(e.x, e.y, size);

      switch (e.eventType) {
        case ReplayEventType.separationLoss:
        case ReplayEventType.conflictWarning:
          final c = e.eventType == ReplayEventType.separationLoss
              ? AppTheme.danger : AppTheme.warning;
          canvas.drawCircle(pos, 14 + pulseVal * 8,
              Paint()..color = c.withValues(alpha: 0.12));
          canvas.drawCircle(pos, 14 + pulseVal * 8,
              Paint()
                ..color = c.withValues(alpha: 0.45)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2);
          canvas.drawCircle(pos, 4, Paint()..color = c.withValues(alpha: 0.8));
          if (e.label != null) {
            _label(canvas, pos + const Offset(0, -22), e.label!,
                color: c, size: 9);
          }

        case ReplayEventType.userVector:
        case ReplayEventType.userAltitudeChange:
        case ReplayEventType.userSpeedChange:
          final path = Path()
            ..moveTo(pos.dx, pos.dy - 11)
            ..lineTo(pos.dx + 7, pos.dy)
            ..lineTo(pos.dx, pos.dy + 11)
            ..lineTo(pos.dx - 7, pos.dy)
            ..close();
          canvas.drawPath(path,
              Paint()..color = Colors.yellowAccent.withValues(alpha: 0.22));
          canvas.drawPath(path,
              Paint()
                ..color = Colors.yellowAccent.withValues(alpha: 0.7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);

        case ReplayEventType.recovered:
          canvas.drawCircle(pos, 8,
              Paint()..color = AppTheme.primary.withValues(alpha: 0.25));
          canvas.drawCircle(pos, 8,
              Paint()
                ..color = AppTheme.primary.withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);
          if (e.label != null) {
            _label(canvas, pos + const Offset(10, -6), e.label!,
                color: AppTheme.primary, size: 9);
          }

        case ReplayEventType.normal:
          break;
      }
    }
  }

  void _label(Canvas canvas, Offset pos, String text,
      {required Color color, double size = 10}) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(color: color, fontSize: size, height: 1.3)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _RadarReplayPainter old) =>
      old.t != t || old.sweepAngle != sweepAngle || old.pulseVal != pulseVal;
}
