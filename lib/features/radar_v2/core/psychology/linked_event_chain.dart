class LinkedEventChainStep {
  final String label;
  final Duration offset;
  final double pressureBump;

  const LinkedEventChainStep({
    required this.label,
    required this.offset,
    required this.pressureBump,
  });
}

class LinkedEventChain {
  final String id;
  final String origin;
  final Duration startedAt;
  final List<LinkedEventChainStep> steps;

  const LinkedEventChain({
    required this.id,
    required this.origin,
    required this.startedAt,
    required this.steps,
  });

  LinkedEventChainStep? activeStepAt(Duration elapsed) {
    LinkedEventChainStep? active;
    for (final step in steps) {
      if (elapsed - startedAt >= step.offset) active = step;
    }
    return active;
  }

  static LinkedEventChain weatherDeviation(Duration startedAt) =>
      LinkedEventChain(
        id: 'weather_deviation_chain_${startedAt.inSeconds}',
        origin: 'weather deviation',
        startedAt: startedAt,
        steps: const [
          LinkedEventChainStep(
            label: 'weather deviation',
            offset: Duration.zero,
            pressureBump: 0.15,
          ),
          LinkedEventChainStep(
            label: 'spacing compression',
            offset: Duration(seconds: 18),
            pressureBump: 0.24,
          ),
          LinkedEventChainStep(
            label: 'unstable approach',
            offset: Duration(seconds: 34),
            pressureBump: 0.32,
          ),
          LinkedEventChainStep(
            label: 'departure hold',
            offset: Duration(seconds: 48),
            pressureBump: 0.22,
          ),
          LinkedEventChainStep(
            label: 'runway backlog',
            offset: Duration(seconds: 58),
            pressureBump: 0.36,
          ),
        ],
      );
}
