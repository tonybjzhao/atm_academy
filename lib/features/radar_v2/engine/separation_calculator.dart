import 'dart:math' as math;

import '../models/aircraft_performance_profile.dart';
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
        results
            .add(calculate(active[i], active[j], pressureIndex: pressureIndex));
      }
    }
    return results;
  }

  SeparationResult calculate(
    AircraftState a,
    AircraftState b, {
    double pressureIndex = 0,
  }) {
    final baseLateral = lateralDistanceNm(a, b);
    final lateral = (baseLateral + _pairLateralBiasNm(a.id, b.id)).clamp(0.0, 999.0);
    final vertical = (a.altitudeFt - b.altitudeFt).abs();

    // Under high pressure, effective minimums are reduced (spacing degrades)
    final pressureFactor = _getPressureFactor(pressureIndex);
    final pairScale = _pairSpacingScale(a.id, b.id);
    final wakeScale = _wakeSpacingScale(a, b);
    final effectiveMinLateral =
      (minimumLateralNm / pressureFactor) * pairScale * wakeScale;
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

  // Small deterministic pair bias creates realistic spacing compression/
  // stretch variation while remaining stable and replayable.
  double _pairLateralBiasNm(String aId, String bId) {
    final hash = _pairHash(aId, bId);
    final normalized = (hash % 1000) / 1000.0;
    return (normalized - 0.5) * 0.36; // approx -0.18..+0.18 NM
  }

  double _pairSpacingScale(String aId, String bId) {
    final hash = _pairHash(aId, bId);
    final normalized = (hash % 1000) / 1000.0;
    return 0.96 + normalized * 0.08; // 0.96..1.04
  }

  int _pairHash(String aId, String bId) {
    final ids = [aId, bId]..sort();
    return ('${ids[0]}:${ids[1]}').hashCode & 0x7fffffff;
  }

  double _wakeSpacingScale(AircraftState a, AircraftState b) {
    final forward = AircraftPerformanceProfile.wakeSpacingMultiplier(
      leaderType: a.performanceType,
      followerType: b.performanceType,
    );
    final reverse = AircraftPerformanceProfile.wakeSpacingMultiplier(
      leaderType: b.performanceType,
      followerType: a.performanceType,
    );
    final scale = math.max(forward, reverse);
    return scale.clamp(1.0, 1.45);
  }
}
