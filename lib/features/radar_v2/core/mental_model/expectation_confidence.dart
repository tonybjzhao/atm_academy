class ExpectationConfidence {
  final double value;

  const ExpectationConfidence(this.value);

  static const ExpectationConfidence low = ExpectationConfidence(0.28);
  static const ExpectationConfidence medium = ExpectationConfidence(0.55);
  static const ExpectationConfidence high = ExpectationConfidence(0.82);

  ExpectationConfidence adjust(double delta) =>
      ExpectationConfidence((value + delta).clamp(0.05, 0.98).toDouble());

  String get label {
    if (value < 0.4) return 'low';
    if (value < 0.7) return 'medium';
    return 'high';
  }
}

class ControllerExpectation {
  final double expectedValue;
  final double actualValue;
  final ExpectationConfidence confidence;

  const ControllerExpectation({
    required this.expectedValue,
    required this.actualValue,
    this.confidence = ExpectationConfidence.medium,
  });

  double get drift => (actualValue - expectedValue).abs().clamp(0, 1);

  bool get contradiction => actualValue > expectedValue + 0.18;

  ControllerExpectation update({
    required double actual,
    required double learningRate,
    required bool underConfirmationBias,
  }) {
    final gap = actual - expectedValue;
    final biasedRate =
        underConfirmationBias && gap > 0 ? learningRate * 0.42 : learningRate;
    final nextExpected =
        (expectedValue + gap * biasedRate).clamp(0, 1).toDouble();
    final confidenceDelta = gap.abs() < 0.12 ? 0.035 : -0.055;
    return ControllerExpectation(
      expectedValue: nextExpected,
      actualValue: actual,
      confidence: confidence.adjust(confidenceDelta),
    );
  }
}
