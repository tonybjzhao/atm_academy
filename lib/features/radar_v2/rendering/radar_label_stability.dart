import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'radar_declutter_profile.dart';

class RadarLabelTarget {
  final String aircraftId;
  final Offset anchorCanvas;
  final double headingDeg;
  final double labelWidth;
  final double labelHeight;
  final RadarLabelPriority priority;
  final bool shouldShowFromDeclutter;

  const RadarLabelTarget({
    required this.aircraftId,
    required this.anchorCanvas,
    required this.headingDeg,
    required this.labelWidth,
    required this.labelHeight,
    required this.priority,
    required this.shouldShowFromDeclutter,
  });
}

class RadarLabelPlacement {
  final Offset offset;
  final bool visible;
  final double opacity;
  final int anchorIndex;

  const RadarLabelPlacement({
    required this.offset,
    required this.visible,
    required this.opacity,
    required this.anchorIndex,
  });
}

class RadarLabelStabilityController {
  final Map<String, _LabelTrack> _tracks = <String, _LabelTrack>{};
  int _lastTick = -1;

  Map<String, RadarLabelPlacement> resolve({
    required int tick,
    required List<RadarLabelTarget> targets,
    required bool replayMode,
  }) {
    if (tick == 0 && _lastTick > 30) {
      _tracks.clear();
    }
    _lastTick = tick;

    final result = <String, RadarLabelPlacement>{};
    final presentIds = targets.map((e) => e.aircraftId).toSet();
    _tracks.removeWhere((id, track) =>
        !presentIds.contains(id) && (tick - track.lastSeenTick) > 180);

    final sortedTargets = List<RadarLabelTarget>.from(targets)
      ..sort((a, b) {
        final p = b.priority.index.compareTo(a.priority.index);
        if (p != 0) return p;
        return a.aircraftId.compareTo(b.aircraftId);
      });

    final occupiedRects = <Rect>[];
    for (final target in sortedTargets) {
      final previous = _tracks[target.aircraftId];
      final candidates = _candidateOffsets(target);
      final prevIndex = previous?.anchorIndex ?? _defaultAnchorIndex(target);
      final orderedIndices = _orderedIndices(prevIndex, candidates.length);
      final rects = List<Rect>.generate(candidates.length, (index) {
        final offset = candidates[index];
        return Rect.fromLTWH(
          target.anchorCanvas.dx + offset.dx,
          target.anchorCanvas.dy + offset.dy,
          target.labelWidth,
          target.labelHeight,
        ).inflate(2.5);
      });

      final desiredVisible = target.priority != RadarLabelPriority.normal
          ? true
          : target.shouldShowFromDeclutter;
      final opacity = _nextOpacity(
        previousOpacity: previous?.opacity ?? 0,
        desiredVisible: desiredVisible,
        priority: target.priority,
        replayMode: replayMode,
      );
      final visible = target.priority != RadarLabelPriority.normal
          ? true
          : (opacity > 0.08 || desiredVisible);

      var chosenIndex = orderedIndices.first;
      var bestOverlap = double.infinity;
      for (final index in orderedIndices) {
        final overlap = _overlapScore(rects[index], occupiedRects);
        if (overlap <= 0.001) {
          chosenIndex = index;
          bestOverlap = 0;
          break;
        }
        if (overlap < bestOverlap) {
          bestOverlap = overlap;
          chosenIndex = index;
        }
      }

      if (previous != null && previous.anchorIndex != chosenIndex) {
        final previousOverlap = _overlapScore(rects[previous.anchorIndex], occupiedRects);
        final improvedEnough = bestOverlap < previousOverlap * (replayMode ? 0.55 : 0.68);
        final canSwitch =
            target.priority != RadarLabelPriority.normal || improvedEnough;
        if (!canSwitch) {
          chosenIndex = previous.anchorIndex;
        }
      }

      final placement = RadarLabelPlacement(
        offset: candidates[chosenIndex],
        visible: visible,
        opacity: opacity,
        anchorIndex: chosenIndex,
      );
      result[target.aircraftId] = placement;
      _tracks[target.aircraftId] = _LabelTrack(
        anchorIndex: chosenIndex,
        opacity: opacity,
        lastSeenTick: tick,
      );

      if (placement.visible && placement.opacity > 0.08) {
        occupiedRects.add(rects[chosenIndex]);
      }
    }

    return result;
  }

  void clear() => _tracks.clear();

  List<Offset> _candidateOffsets(RadarLabelTarget target) {
    final left = -(target.labelWidth + 4);
    final right = 10.0;
    final top = -22.0;
    final bottom = 8.0;

    final rightTop = Offset(right, top);
    final rightBottom = Offset(right, bottom);
    final leftTop = Offset(left, top);
    final leftBottom = Offset(left, bottom);
    return <Offset>[rightTop, rightBottom, leftTop, leftBottom];
  }

  int _defaultAnchorIndex(RadarLabelTarget target) {
    final headingRad = target.headingDeg * math.pi / 180;
    final primaryRight = math.sin(headingRad) >= 0;
    final primaryTop = -math.cos(headingRad) <= 0;
    if (primaryRight && primaryTop) return 0;
    if (primaryRight && !primaryTop) return 1;
    if (!primaryRight && primaryTop) return 2;
    return 3;
  }

  List<int> _orderedIndices(int preferred, int count) {
    final result = <int>[];
    result.add(preferred.clamp(0, count - 1));
    for (var step = 1; step < count; step++) {
      final plus = preferred + step;
      final minus = preferred - step;
      if (plus < count) result.add(plus);
      if (minus >= 0) result.add(minus);
    }
    return result.toSet().toList(growable: false);
  }

  double _nextOpacity({
    required double previousOpacity,
    required bool desiredVisible,
    required RadarLabelPriority priority,
    required bool replayMode,
  }) {
    if (priority != RadarLabelPriority.normal) return 1.0;
    final rise = replayMode ? 0.16 : 0.22;
    final fall = replayMode ? 0.05 : 0.07;
    final next = desiredVisible
        ? previousOpacity + rise
        : previousOpacity - fall;
    return next.clamp(0.0, 1.0);
  }

  double _overlapScore(Rect rect, List<Rect> occupied) {
    var score = 0.0;
    for (final other in occupied) {
      final overlap = rect.intersect(other);
      if (overlap.isEmpty) continue;
      score += overlap.width * overlap.height;
    }
    return score;
  }
}

class _LabelTrack {
  final int anchorIndex;
  final double opacity;
  final int lastSeenTick;

  const _LabelTrack({
    required this.anchorIndex,
    required this.opacity,
    required this.lastSeenTick,
  });
}
