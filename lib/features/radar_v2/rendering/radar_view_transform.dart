import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadarViewTransform {
  static const double minTacticalRangeNm = 12.0;

  final Size size;
  final double sectorRangeNm;
  final double visibleRangeNm;
  final Offset viewCenterNm;

  const RadarViewTransform({
    required this.size,
    required this.sectorRangeNm,
    required this.visibleRangeNm,
    this.viewCenterNm = Offset.zero,
  });

  double get radiusPx => math.min(size.width, size.height) * 0.46;
  double get scalePxPerNm => radiusPx / visibleRangeNm;
  Offset get canvasCenter => Offset(size.width / 2, size.height / 2);

  Offset nmToCanvas(double xNm, double yNm) {
    final scale = scalePxPerNm;
    return canvasCenter.translate(
      (xNm - viewCenterNm.dx) * scale,
      -(yNm - viewCenterNm.dy) * scale,
    );
  }

  Offset canvasToNm(Offset canvas) {
    final scale = scalePxPerNm;
    return Offset(
      viewCenterNm.dx + (canvas.dx - canvasCenter.dx) / scale,
      viewCenterNm.dy - (canvas.dy - canvasCenter.dy) / scale,
    );
  }

  Offset clampedCenter(Offset requestedCenter) {
    final maxPan = math.max(0.0, sectorRangeNm - visibleRangeNm);
    return Offset(
      requestedCenter.dx.clamp(-maxPan, maxPan).toDouble(),
      requestedCenter.dy.clamp(-maxPan, maxPan).toDouble(),
    );
  }

  double clampedRange(double requestedRange) {
    final minRange = math.min(minTacticalRangeNm, sectorRangeNm);
    return requestedRange.clamp(minRange, sectorRangeNm).toDouble();
  }

  RadarViewTransform withView({
    double? visibleRangeNm,
    Offset? viewCenterNm,
  }) {
    final nextRange = clampedRange(visibleRangeNm ?? this.visibleRangeNm);
    final next = RadarViewTransform(
      size: size,
      sectorRangeNm: sectorRangeNm,
      visibleRangeNm: nextRange,
      viewCenterNm: Offset.zero,
    );
    return RadarViewTransform(
      size: size,
      sectorRangeNm: sectorRangeNm,
      visibleRangeNm: nextRange,
      viewCenterNm: next.clampedCenter(viewCenterNm ?? this.viewCenterNm),
    );
  }

  RadarViewTransform zoomAround({
    required double targetRangeNm,
    required Offset focalCanvas,
  }) {
    final focalNm = canvasToNm(focalCanvas);
    final nextRange = clampedRange(targetRangeNm);
    final nextScale = radiusPx / nextRange;
    final nextCenter = Offset(
      focalNm.dx - (focalCanvas.dx - canvasCenter.dx) / nextScale,
      focalNm.dy + (focalCanvas.dy - canvasCenter.dy) / nextScale,
    );
    return withView(
      visibleRangeNm: nextRange,
      viewCenterNm: nextCenter,
    );
  }
}
