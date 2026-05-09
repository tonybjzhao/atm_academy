import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'cognitive_timeline.dart';
import 'radar_training_text_localizer.dart';

class CognitiveTimelineVisualizer extends StatelessWidget {
  final CognitiveTimelineData data;
  final Duration selectedElapsed;
  final AppLocalizations localizations;
  final ValueChanged<Duration> onJump;

  const CognitiveTimelineVisualizer({
    super.key,
    required this.data,
    required this.selectedElapsed,
    required this.localizations,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final selectedSeconds = selectedElapsed.inSeconds
        .clamp(0, math.max(1, data.duration.inSeconds))
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                localizations.radarTrainingCognitiveTimeline,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              'T+${selectedSeconds.round()}s',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _jumpFromLocal(
                details.localPosition,
                constraints.maxWidth,
              ),
              child: SizedBox(
                height: 246,
                width: double.infinity,
                child: CustomPaint(
                  painter: _CognitiveTimelinePainter(
                    data: data,
                    localizations: localizations,
                    selectedElapsed: selectedElapsed,
                  ),
                ),
              ),
            );
          },
        ),
        Slider(
          value: selectedSeconds,
          min: 0,
          max: math.max(1, data.duration.inSeconds).toDouble(),
          onChanged: (value) => onJump(Duration(seconds: value.round())),
        ),
        _MarkerRail(data: data, localizations: localizations, onJump: onJump),
      ],
    );
  }

  void _jumpFromLocal(Offset localPosition, double width) {
    const labelWidth = 82.0;
    final usableWidth = width - labelWidth;
    if (usableWidth <= 0) return;
    final dx = (localPosition.dx - labelWidth).clamp(0.0, usableWidth);
    final seconds = (dx / usableWidth * data.duration.inSeconds).round();
    onJump(Duration(seconds: seconds));
  }
}

class _MarkerRail extends StatelessWidget {
  final CognitiveTimelineData data;
  final AppLocalizations localizations;
  final ValueChanged<Duration> onJump;

  const _MarkerRail({
    required this.data,
    required this.localizations,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final markers = data.markers.take(8).toList();
    if (markers.isEmpty) {
      return Text(
        localizations.radarTrainingNoMajorReplayMarkers,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final marker in markers)
          ActionChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: const Color(0xFF0B2133),
            side: BorderSide(
                color: _markerColor(marker.type).withValues(alpha: 0.55)),
            label: Text(
              'T+${marker.elapsed.inSeconds}s ${RadarTrainingTextLocalizer.line(localizations, _markerLabel(marker.type))}',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            onPressed: () => onJump(marker.elapsed),
          ),
      ],
    );
  }
}

class _CognitiveTimelinePainter extends CustomPainter {
  final CognitiveTimelineData data;
  final AppLocalizations localizations;
  final Duration selectedElapsed;

  const _CognitiveTimelinePainter({
    required this.data,
    required this.localizations,
    required this.selectedElapsed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelWidth = 82.0;
    final trackLeft = labelWidth;
    final trackRight = size.width;
    final trackWidth = math.max(1.0, trackRight - trackLeft);
    final rowHeight = size.height / data.layers.length;

    _drawTimeGrid(canvas, size, trackLeft, trackWidth);
    _drawSalienceRegions(canvas, size, trackLeft, trackWidth);

    for (var i = 0; i < data.layers.length; i++) {
      final layer = data.layers[i];
      final y = i * rowHeight;
      _drawLayerLabel(canvas, layer.label, y + rowHeight * 0.55);
      _drawLayerBase(canvas, Offset(trackLeft, y + rowHeight * 0.28),
          Size(trackWidth, rowHeight * 0.44));
      for (final segment in layer.segments) {
        _drawSegment(
          canvas,
          layer.type,
          segment,
          Rect.fromLTWH(
              trackLeft, y + rowHeight * 0.28, trackWidth, rowHeight * 0.44),
        );
      }
    }

    _drawMarkers(canvas, size, trackLeft, trackWidth);
    _drawSelectedTime(canvas, size, trackLeft, trackWidth);
  }

  void _drawTimeGrid(Canvas canvas, Size size, double left, double width) {
    final paint = Paint()
      ..color = AppTheme.borderColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final durationSeconds = math.max(1, data.duration.inSeconds);
    for (var i = 0; i <= 4; i++) {
      final x = left + width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - 18), paint);
      _drawText(
        canvas,
        '${(durationSeconds * i / 4).round()}s',
        Offset(x - 10, size.height - 14),
        const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
      );
    }
  }

  void _drawSalienceRegions(
    Canvas canvas,
    Size size,
    double left,
    double width,
  ) {
    for (final region in data.salienceRegions) {
      final rect = _rectFor(region, left, width, 0, size.height - 18);
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppTheme.primary.withValues(
            alpha: 0.05 + region.intensity * 0.08,
          ),
      );
    }
  }

  void _drawLayerLabel(Canvas canvas, String label, double y) {
    _drawText(
      canvas,
      RadarTrainingTextLocalizer.line(localizations, label),
      Offset(0, y - 7),
      const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _drawLayerBase(Canvas canvas, Offset offset, Size size) {
    final rect = RRect.fromRectAndRadius(
      offset & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF06111D),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppTheme.borderColor.withValues(alpha: 0.45),
    );
  }

  void _drawSegment(
    Canvas canvas,
    CognitiveTimelineLayerType type,
    CognitiveTimelineSegment segment,
    Rect rowRect,
  ) {
    if (segment.intensity <= 0.02) return;
    final rect = _rectFor(
      segment,
      rowRect.left,
      rowRect.width,
      rowRect.top,
      rowRect.height,
    );
    final color = _layerColor(type);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.34 + segment.intensity * 0.38),
          ],
        ).createShader(rect),
    );
  }

  void _drawMarkers(Canvas canvas, Size size, double left, double width) {
    for (final marker in data.markers) {
      final x = _xFor(marker.elapsed, left, width);
      final color = _markerColor(marker.type);
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 20),
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth =
              marker.type == CognitiveTimelineEventType.salience ? 2 : 1,
      );
      canvas.drawCircle(
        Offset(x, 7),
        marker.type == CognitiveTimelineEventType.salience ? 4 : 3,
        Paint()..color = color,
      );
    }
  }

  void _drawSelectedTime(Canvas canvas, Size size, double left, double width) {
    final x = _xFor(selectedElapsed, left, width);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height - 18),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..strokeWidth = 1.5,
    );
  }

  Rect _rectFor(
    CognitiveTimelineSegment segment,
    double left,
    double width,
    double top,
    double height,
  ) {
    final x1 = _xFor(segment.start, left, width);
    final x2 = _xFor(segment.end, left, width);
    return Rect.fromLTRB(
      math.min(x1, x2),
      top,
      math.max(x1 + 2, x2),
      top + height,
    );
  }

  double _xFor(Duration elapsed, double left, double width) {
    final durationSeconds = math.max(1, data.duration.inSeconds);
    final ratio = elapsed.inSeconds.clamp(0, durationSeconds) / durationSeconds;
    return left + width * ratio;
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 76);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CognitiveTimelinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.selectedElapsed != selectedElapsed;
  }
}

Color _layerColor(CognitiveTimelineLayerType type) {
  return switch (type) {
    CognitiveTimelineLayerType.workload => AppTheme.warning,
    CognitiveTimelineLayerType.attentionQuality => AppTheme.primary,
    CognitiveTimelineLayerType.workingMemory => Colors.lightBlueAccent,
    CognitiveTimelineLayerType.surpriseLoad => Colors.deepOrangeAccent,
    CognitiveTimelineLayerType.fixation => Colors.amberAccent,
    CognitiveTimelineLayerType.scanBlind => Colors.redAccent,
    CognitiveTimelineLayerType.recovery => Colors.greenAccent,
    CognitiveTimelineLayerType.expectationConfidence => Colors.cyanAccent,
    CognitiveTimelineLayerType.selfAssessment => Colors.purpleAccent,
  };
}

Color _markerColor(CognitiveTimelineEventType type) {
  return switch (type) {
    CognitiveTimelineEventType.separationWarning => AppTheme.danger,
    CognitiveTimelineEventType.delayedRecognition => AppTheme.warning,
    CognitiveTimelineEventType.forgottenIntention => Colors.lightBlueAccent,
    CognitiveTimelineEventType.expectationMismatch => Colors.cyanAccent,
    CognitiveTimelineEventType.cascadeOnset => Colors.deepOrangeAccent,
    CognitiveTimelineEventType.overloadPeak => AppTheme.warning,
    CognitiveTimelineEventType.recovery => Colors.greenAccent,
    CognitiveTimelineEventType.salience => AppTheme.primary,
  };
}

String _markerLabel(CognitiveTimelineEventType type) {
  return switch (type) {
    CognitiveTimelineEventType.separationWarning => 'warning',
    CognitiveTimelineEventType.delayedRecognition => 'late',
    CognitiveTimelineEventType.forgottenIntention => 'memory',
    CognitiveTimelineEventType.expectationMismatch => 'expectation',
    CognitiveTimelineEventType.cascadeOnset => 'cascade',
    CognitiveTimelineEventType.overloadPeak => 'overload',
    CognitiveTimelineEventType.recovery => 'recovery',
    CognitiveTimelineEventType.salience => 'debrief',
  };
}
