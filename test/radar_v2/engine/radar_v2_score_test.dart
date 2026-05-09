import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/commands/controller_command.dart';
import 'package:atm_flutter/features/radar_v2/engine/simulation_engine.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/scoring/radar_v2_score.dart';

void main() {
  test('score penalizes separation loss once per aircraft pair', () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 250,
        ),
        const AircraftState(
          id: 'b',
          callsign: 'VJA612',
          xNm: 2,
          yNm: 0,
          altitudeFt: 9300,
          headingDeg: 270,
          groundSpeedKt: 250,
        ),
      ],
    );
    final tracker = RadarV2ScoreTracker();

    tracker
      ..observe(engine.snapshot)
      ..observe(engine.snapshot);

    expect(tracker.snapshot.score, lessThanOrEqualTo(75));
    expect(
        tracker.snapshot.penalties
            .where((item) => item.contains('Separation loss')),
        hasLength(1));
  });

  test('score penalizes excessive commands and unnecessary altitude changes',
      () {
    final engine = SimulationEngine(
      aircraft: [
        const AircraftState(
          id: 'a',
          callsign: 'QFA214',
          xNm: 0,
          yNm: 0,
          altitudeFt: 9000,
          headingDeg: 90,
          groundSpeedKt: 250,
        ),
      ],
    );
    final tracker = RadarV2ScoreTracker();

    for (var i = 0; i < 9; i++) {
      tracker.recordCommand(
        AssignAltitude(
          aircraftId: 'a',
          issuedAt: Duration(seconds: i),
          altitudeFt: 10000 + i * 100,
        ),
        engine.snapshot,
      );
    }

    expect(tracker.snapshot.score, lessThan(100));
    expect(tracker.snapshot.commandCount, 9);
  });

  test('low total score does not classify efficiency as excellent', () {
    const snapshot = RadarV2ScoreSnapshot(
      score: 36,
      commandCount: 4,
      separationLossCount: 2,
      lateResolutionCount: 2,
      spacingStability: 92,
      throughputEfficiency: 88,
      weatherManagement: 90,
      commandEfficiency: 95,
      anticipationScore: 70,
      lastDelta: 0,
      lastReason: null,
      penalties: [],
      ignoredCriticalAlertCount: 1,
      commandBurstCount: 1,
    );

    expect(snapshot.isEfficiencyExcellent, isFalse);
    expect(snapshot.isEfficiencyGood, isFalse);
  });
}
