import 'package:atm_flutter/features/radar_v2/rendering/radar_view_transform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadarViewTransform', () {
    test('round trips canvas and nautical-mile coordinates', () {
      const transform = RadarViewTransform(
        size: Size(400, 300),
        sectorRangeNm: 40,
        visibleRangeNm: 24,
        viewCenterNm: Offset(6, -4),
      );

      const world = Offset(12, -9);
      final canvas = transform.nmToCanvas(world.dx, world.dy);
      final roundTrip = transform.canvasToNm(canvas);

      expect(roundTrip.dx, closeTo(world.dx, 1e-9));
      expect(roundTrip.dy, closeTo(world.dy, 1e-9));
    });

    test('zoom around keeps focal world coordinate stable', () {
      const transform = RadarViewTransform(
        size: Size(400, 400),
        sectorRangeNm: 40,
        visibleRangeNm: 40,
      );
      const focal = Offset(260, 170);
      final before = transform.canvasToNm(focal);

      final zoomed = transform.zoomAround(
        targetRangeNm: 20,
        focalCanvas: focal,
      );
      final after = zoomed.canvasToNm(focal);

      expect(after.dx, closeTo(before.dx, 1e-9));
      expect(after.dy, closeTo(before.dy, 1e-9));
      expect(zoomed.visibleRangeNm, 20);
    });

    test('clamps range and pan to sector bounds', () {
      const transform = RadarViewTransform(
        size: Size(400, 400),
        sectorRangeNm: 40,
        visibleRangeNm: 40,
      );

      final close = transform.withView(
        visibleRangeNm: 4,
        viewCenterNm: const Offset(99, -99),
      );
      expect(close.visibleRangeNm, RadarViewTransform.minTacticalRangeNm);
      expect(close.viewCenterNm.dx, 28);
      expect(close.viewCenterNm.dy, -28);

      final full = close.withView(visibleRangeNm: 100);
      expect(full.visibleRangeNm, 40);
      expect(full.viewCenterNm, Offset.zero);
    });
  });
}
