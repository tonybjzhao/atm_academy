import 'dart:math' as math;

import '../models/aircraft_state.dart';
import '../models/separation_result.dart';

class SeparationCalculator {
  final double minimumLateralNm;
  final int minimumVerticalFt;

  const SeparationCalculator({
    this.minimumLateralNm = 5,
    this.minimumVerticalFt = 1000,
  });

  /// Under high pressure, aircraft may not maintain proper spacing due to
  /// reduced command efficiency. Effective spacing minimums are reduced.
  List<SeparationResult> calculatePairs(
    List<AircraftState> aircraft, {
    double pressureIndex = 0,
  }) {
    final active =
        aircraft.where((target) => target.active).toList(growable: false);
    final results = <SeparationResult>[];
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        results.add(calculate(active[i], active[j], pressureIndex: pressureIndex));
      }
    }
    return results;
  }

  SeparationResult calculate(
    AircraftState a,
    AircraftState b, {
    double pressureIndex = 0,
  }) {
    final lateral = lateralDistanceNm(a, b);
    final vertical = (a.altitudeFt - b.altitudeFt).abs();

    // Under high pressure, effective minimums are reduced (spacing degrades)
    final pressureFactor = _getPressureFactor(pressureIndex);
    final effectiveMinLateral = minimumLateralNm / pressureFactor;
    final effectiveMinVertical = (minimumVerticalFt / pressureFactor).round();

    return SeparationResult(
      aircraftAId: a.id,
      aircraftBId: b.id,
      lateralNm: lateral,
      verticalFt: vertical,
      isLossOfSeparation:
          lateral < effectiveMinLateral && vertical < effectiveMinVertical,
      isPredictedConflict: false,
    );
  }

  /// Returns a factor by which spacing minimums are degraded under pressure.
  /// At pressure 0–1.0: factor = 1.0 (normal spacing maintained)
  /// At pressure 1.0–2.0: factor = 0.9–0.8 (spacing compressed 10–20%)
  /// At pressure 2.0–3.0: factor = 0.8–0.65 (spacing compressed 20–35%)
  /// At pressure 3.0+: factor = 0.65 (spacing compressed 35%+)
  double _getPressureFactor(double pressureIndex) {
    if (pressureIndex <= 1.0) return 1.0;
    final excessPressure = (pressureIndex - 1.0).clamp(0, 2);
    return 1.0 - (excessPressure * 0.175); // 0 to 0.35 reduction
  }

  double lateralDistanceNm(AircraftState a, AircraftState b) {
    final dx = a.xNm - b.xNm;
    final dy = a.yNm - b.yNm;
    return math.sqrt(dx * dx + dy * dy);
  }
}
