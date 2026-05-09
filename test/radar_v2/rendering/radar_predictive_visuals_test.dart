import 'package:atm_flutter/features/radar_v2/models/aircraft_intent.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/rendering/radar_predictive_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadarPredictiveVisuals', () {
    test('vector scaling grows with speed and trend', () {
      final slow = AircraftState(
        id: 'A',
        callsign: 'AAL101',
        xNm: 0,
        yNm: 0,
        altitudeFt: 12000,
        headingDeg: 90,
        groundSpeedKt: 190,
        speedTrendKtPerSecond: -0.2,
      );
      final fast = slow.copyWith(
        groundSpeedKt: 280,
        speedTrendKtPerSecond: 0.35,
        intent: const AircraftIntent(assignedHeadingDeg: 130),
      );

      final slowStyle = RadarPredictiveVisuals.vectorStyle(
        aircraft: slow,
        scalePxPerNm: 7,
        replayMode: false,
        selected: false,
      );
      final fastStyle = RadarPredictiveVisuals.vectorStyle(
        aircraft: fast,
        scalePxPerNm: 7,
        replayMode: false,
        selected: true,
      );

      expect(fastStyle.projectedLengthPx, greaterThan(slowStyle.projectedLengthPx));
      expect(fastStyle.speedTrend, SpeedTrendIndicator.accelerating);
      expect(slowStyle.speedTrend, SpeedTrendIndicator.decelerating);
      expect(fastStyle.turnArcSweepRad, greaterThan(0));
    });

    test('closure visualization is symmetric and consistent', () {
      final a = AircraftState(
        id: 'A',
        callsign: 'A1',
        xNm: -4,
        yNm: 0,
        altitudeFt: 13000,
        headingDeg: 90,
        groundSpeedKt: 260,
      );
      final b = AircraftState(
        id: 'B',
        callsign: 'B1',
        xNm: 4,
        yNm: 0,
        altitudeFt: 13200,
        headingDeg: 270,
        groundSpeedKt: 250,
      );

      final forward = RadarPredictiveVisuals.closureStyle(
        a: a,
        b: b,
        replayMode: false,
      );
      final reversed = RadarPredictiveVisuals.closureStyle(
        a: b,
        b: a,
        replayMode: false,
      );

      expect(forward.closureRateKt, closeTo(reversed.closureRateKt, 1e-6));
      expect(forward.convergenceStrength, inInclusiveRange(0, 1));
      expect(forward.leadFraction, inInclusiveRange(0.2, 0.62));
      expect(forward.strokeWidth, greaterThanOrEqualTo(1));
    });

    test('replay prediction emphasis remains stable for same inputs', () {
      final style1 = RadarPredictiveVisuals.replayStyle(
        currentTtc: const Duration(seconds: 70),
        previousTtc: const Duration(seconds: 90),
      );
      final style2 = RadarPredictiveVisuals.replayStyle(
        currentTtc: const Duration(seconds: 70),
        previousTtc: const Duration(seconds: 90),
      );
      final compressed = RadarPredictiveVisuals.replayStyle(
        currentTtc: const Duration(seconds: 40),
        previousTtc: const Duration(seconds: 95),
      );

      expect(style1.conflictEmphasisOpacity,
          closeTo(style2.conflictEmphasisOpacity, 1e-9));
      expect(style1.compressionGlow, closeTo(style2.compressionGlow, 1e-9));
      expect(compressed.compressionGlow, greaterThan(style1.compressionGlow));
    });
  });
}
