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

  List<SeparationResult> calculatePairs(List<AircraftState> aircraft) {
    final active =
        aircraft.where((target) => target.active).toList(growable: false);
    final results = <SeparationResult>[];
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        results.add(calculate(active[i], active[j]));
      }
    }
    return results;
  }

  SeparationResult calculate(AircraftState a, AircraftState b) {
    final lateral = lateralDistanceNm(a, b);
    final vertical = (a.altitudeFt - b.altitudeFt).abs();
    return SeparationResult(
      aircraftAId: a.id,
      aircraftBId: b.id,
      lateralNm: lateral,
      verticalFt: vertical,
      isLossOfSeparation:
          lateral < minimumLateralNm && vertical < minimumVerticalFt,
      isPredictedConflict: false,
    );
  }

  double lateralDistanceNm(AircraftState a, AircraftState b) {
    final dx = a.xNm - b.xNm;
    final dy = a.yNm - b.yNm;
    return math.sqrt(dx * dx + dy * dy);
  }
}
