import 'package:atm_flutter/features/radar_v2/rendering/radar_declutter_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadarDeclutterProfile', () {
    test('wide zoom enables declutter and trail reduction', () {
      final profile = RadarDeclutterProfile.fromVisibleRange(
        visibleRangeNm: 80,
        sectorRangeNm: 80,
      );

      expect(profile.wideZoomFactor, greaterThan(0.9));
      expect(profile.showSecondaryLabelDetails, isFalse);
      expect(profile.simplifyWeather, isTrue);
      expect(profile.maxTrailPoints, lessThanOrEqualTo(10));
      expect(profile.trailPointStride, greaterThanOrEqualTo(2));
      expect(profile.nonCriticalLabelBudget, lessThanOrEqualTo(6));
    });

    test('selected aircraft label is preserved at wide zoom', () {
      final profile = RadarDeclutterProfile.fromVisibleRange(
        visibleRangeNm: 70,
        sectorRangeNm: 80,
      );

      final selectedVisible = profile.shouldShowAircraftLabel(
        priority: RadarLabelPriority.selected,
        nonCriticalRank: 99,
      );
      final lowPriorityHidden = profile.shouldShowAircraftLabel(
        priority: RadarLabelPriority.normal,
        nonCriticalRank: profile.nonCriticalLabelBudget + 4,
      );

      expect(selectedVisible, isTrue);
      expect(lowPriorityHidden, isFalse);
    });

    test('conflict and warning labels remain visible at wide zoom', () {
      final profile = RadarDeclutterProfile.fromVisibleRange(
        visibleRangeNm: 80,
        sectorRangeNm: 80,
      );

      final conflictVisible = profile.shouldShowAircraftLabel(
        priority: RadarLabelPriority.conflict,
        nonCriticalRank: 999,
      );
      final warningVisible = profile.shouldShowAircraftLabel(
        priority: RadarLabelPriority.warning,
        nonCriticalRank: 999,
      );

      expect(conflictVisible, isTrue);
      expect(warningVisible, isTrue);
    });
  });
}
