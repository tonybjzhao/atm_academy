import 'package:atm_flutter/features/radar_v2/rendering/radar_declutter_profile.dart';
import 'package:atm_flutter/features/radar_v2/rendering/radar_label_stability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadarLabelStabilityController', () {
    test('keeps preferred side when overlap improvement is small', () {
      final controller = RadarLabelStabilityController();
      final first = controller.resolve(
        tick: 1,
        replayMode: false,
        targets: const [
          RadarLabelTarget(
            aircraftId: 'A1',
            anchorCanvas: Offset(200, 200),
            headingDeg: 90,
            labelWidth: 92,
            labelHeight: 24,
            priority: RadarLabelPriority.normal,
            shouldShowFromDeclutter: true,
          ),
          RadarLabelTarget(
            aircraftId: 'B1',
            anchorCanvas: Offset(210, 196),
            headingDeg: 260,
            labelWidth: 92,
            labelHeight: 24,
            priority: RadarLabelPriority.normal,
            shouldShowFromDeclutter: true,
          ),
        ],
      );

      final second = controller.resolve(
        tick: 2,
        replayMode: false,
        targets: const [
          RadarLabelTarget(
            aircraftId: 'A1',
            anchorCanvas: Offset(201, 201),
            headingDeg: 92,
            labelWidth: 92,
            labelHeight: 24,
            priority: RadarLabelPriority.normal,
            shouldShowFromDeclutter: true,
          ),
          RadarLabelTarget(
            aircraftId: 'B1',
            anchorCanvas: Offset(211, 197),
            headingDeg: 262,
            labelWidth: 92,
            labelHeight: 24,
            priority: RadarLabelPriority.normal,
            shouldShowFromDeclutter: true,
          ),
        ],
      );

      expect(second['A1']!.anchorIndex, first['A1']!.anchorIndex);
    });

    test('hysteresis avoids immediate label pop-out near threshold', () {
      final controller = RadarLabelStabilityController();
      const target = RadarLabelTarget(
        aircraftId: 'A1',
        anchorCanvas: Offset(180, 150),
        headingDeg: 40,
        labelWidth: 74,
        labelHeight: 13,
        priority: RadarLabelPriority.normal,
        shouldShowFromDeclutter: true,
      );

      final frame1 = controller.resolve(
        tick: 1,
        replayMode: false,
        targets: const [target],
      );
      final frame2 = controller.resolve(
        tick: 2,
        replayMode: false,
        targets: const [
          RadarLabelTarget(
            aircraftId: 'A1',
            anchorCanvas: Offset(180, 150),
            headingDeg: 40,
            labelWidth: 74,
            labelHeight: 13,
            priority: RadarLabelPriority.normal,
            shouldShowFromDeclutter: false,
          ),
        ],
      );

      expect(frame1['A1']!.opacity, greaterThan(0));
      expect(frame2['A1']!.opacity, greaterThan(0));
      expect(frame2['A1']!.visible, isTrue);
    });

    test('selected and conflict labels remain visible regardless of declutter', () {
      final controller = RadarLabelStabilityController();

      final result = controller.resolve(
        tick: 10,
        replayMode: true,
        targets: const [
          RadarLabelTarget(
            aircraftId: 'SEL',
            anchorCanvas: Offset(120, 120),
            headingDeg: 0,
            labelWidth: 92,
            labelHeight: 24,
            priority: RadarLabelPriority.selected,
            shouldShowFromDeclutter: false,
          ),
          RadarLabelTarget(
            aircraftId: 'CFT',
            anchorCanvas: Offset(220, 120),
            headingDeg: 180,
            labelWidth: 92,
            labelHeight: 24,
            priority: RadarLabelPriority.conflict,
            shouldShowFromDeclutter: false,
          ),
        ],
      );

      expect(result['SEL']!.visible, isTrue);
      expect(result['SEL']!.opacity, 1);
      expect(result['CFT']!.visible, isTrue);
      expect(result['CFT']!.opacity, 1);
    });
  });
}
