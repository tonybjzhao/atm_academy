import 'dart:math';
import 'package:flutter/material.dart';
import '../core/models/aircraft.dart';
import '../core/theme/app_theme.dart';
import '../widgets/radar_painter.dart';

class RadarSimulationScreen extends StatefulWidget {
  const RadarSimulationScreen({super.key});
  @override
  State<RadarSimulationScreen> createState() => _RadarSimulationScreenState();
}

class _RadarSimulationScreenState extends State<RadarSimulationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  double _sweepAngle = 0;
  Aircraft? _selected;
  bool _running = true;

  final _aircraft = <Aircraft>[
    Aircraft(callsign: 'QFA123', x: 90, y: 120, heading: 25, speed: 0.7, altitude: 320),
    Aircraft(callsign: 'UAE406', x: 240, y: 180, heading: 210, speed: 0.6, altitude: 280),
    Aircraft(callsign: 'THA789', x: 160, y: 300, heading: 310, speed: 0.5, altitude: 250),
    Aircraft(callsign: 'SIA201', x: 300, y: 90, heading: 145, speed: 0.55, altitude: 310),
  ];

  bool get _hasConflict {
    for (int i = 0; i < _aircraft.length; i++) {
      for (int j = i + 1; j < _aircraft.length; j++) {
        final dx = _aircraft[i].x - _aircraft[j].x;
        final dy = _aircraft[i].y - _aircraft[j].y;
        if (sqrt(dx * dx + dy * dy) < 55) return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
        setState(() => _sweepAngle += 0.018);
      });
    _sweepCtrl.repeat();

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted || !_running) return false;
      setState(() {
        for (final a in _aircraft) {
          a.update(const Size(370, 430));
        }
      });
      return true;
    });
  }

  @override
  void dispose() {
    _running = false;
    _sweepCtrl.dispose();
    super.dispose();
  }

  void _command(String type) {
    final a = _selected;
    if (a == null) return;
    setState(() {
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
          a.speed = min(1.5, a.speed + 0.1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conflict = _hasConflict;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('RADAR SIM'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                conflict ? '⚠ CONFLICT' : '● NORMAL',
                style: TextStyle(
                  color: conflict ? AppTheme.danger : AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status panel
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: conflict
                  ? AppTheme.danger.withValues(alpha: 0.12)
                  : AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: conflict ? AppTheme.danger : AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  conflict ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: conflict ? AppTheme.danger : AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  conflict
                      ? 'CONFLICT ALERT — AIRCRAFT TOO CLOSE'
                      : 'TRAFFIC NORMAL — ${_aircraft.length} TRACKS',
                  style: TextStyle(
                    color: conflict ? AppTheme.danger : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Radar display
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final p = details.localPosition;
                Aircraft? hit;
                double minDist = 32;
                for (final a in _aircraft) {
                  final d = sqrt(pow(p.dx - a.x, 2) + pow(p.dy - a.y, 2));
                  if (d < minDist) {
                    minDist = d;
                    hit = a;
                  }
                }
                setState(() => _selected = hit);
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
          // Selected aircraft info + commands
          if (_selected != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flight, color: Colors.yellowAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_selected!.callsign}  FL${_selected!.altitude}  HDG ${_selected!.heading.toInt()}°  SPD ${_selected!.speed.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          // Command buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _cmdBtn('◀ Left', () => _command('left')),
                _cmdBtn('Right ▶', () => _command('right')),
                _cmdBtn('▲ Climb', () => _command('climb')),
                _cmdBtn('▼ Descend', () => _command('descend')),
                _cmdBtn('Slow', () => _command('slow')),
                _cmdBtn('Fast', () => _command('fast')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cmdBtn(String label, VoidCallback onTap) {
    final enabled = _selected != null;
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: BorderSide(color: enabled ? AppTheme.primary : AppTheme.borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
