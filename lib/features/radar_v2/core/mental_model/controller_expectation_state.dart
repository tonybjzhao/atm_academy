import 'expectation_confidence.dart';

enum MentalModelDriftLevel {
  aligned,
  drifting,
  biased,
  falseRecovery,
  criticalDrift,
}

class ControllerExpectationState {
  final ControllerExpectation runwayFlow;
  final ControllerExpectation spacingStability;
  final ControllerExpectation aircraftSequencing;
  final ControllerExpectation alertPatterns;
  final ControllerExpectation weatherBehavior;
  final double driftScore;
  final bool confirmationBiasActive;
  final bool falseRecoveryActive;
  final bool attentionAnchored;
  final double threatSensitivity;
  final MentalModelDriftLevel driftLevel;
  final List<String> reportLines;

  const ControllerExpectationState({
    required this.runwayFlow,
    required this.spacingStability,
    required this.aircraftSequencing,
    required this.alertPatterns,
    required this.weatherBehavior,
    required this.driftScore,
    required this.confirmationBiasActive,
    required this.falseRecoveryActive,
    required this.attentionAnchored,
    required this.threatSensitivity,
    required this.driftLevel,
    this.reportLines = const [],
  });

  static const ControllerExpectationState idle = ControllerExpectationState(
    runwayFlow: ControllerExpectation(expectedValue: 0, actualValue: 0),
    spacingStability: ControllerExpectation(expectedValue: 0, actualValue: 0),
    aircraftSequencing: ControllerExpectation(expectedValue: 0, actualValue: 0),
    alertPatterns: ControllerExpectation(expectedValue: 0, actualValue: 0),
    weatherBehavior: ControllerExpectation(expectedValue: 0, actualValue: 0),
    driftScore: 0,
    confirmationBiasActive: false,
    falseRecoveryActive: false,
    attentionAnchored: false,
    threatSensitivity: 1,
    driftLevel: MentalModelDriftLevel.aligned,
  );

  String get driftLabel => switch (driftLevel) {
        MentalModelDriftLevel.aligned => 'aligned',
        MentalModelDriftLevel.drifting => 'drifting',
        MentalModelDriftLevel.biased => 'confirmation bias',
        MentalModelDriftLevel.falseRecovery => 'false recovery',
        MentalModelDriftLevel.criticalDrift => 'critical drift',
      };

  ControllerExpectation get strongestDivergence {
    final expectations = [
      runwayFlow,
      spacingStability,
      aircraftSequencing,
      alertPatterns,
      weatherBehavior,
    ];
    expectations.sort((a, b) => b.drift.compareTo(a.drift));
    return expectations.first;
  }
}
