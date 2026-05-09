enum PendingIntentionType {
  plannedDescent,
  expectedTurn,
  runwayReassignment,
  sequencingAdjustment,
  handoffIntention,
}

class PendingIntentionSnapshot {
  final String id;
  final PendingIntentionType type;
  final Duration createdAt;
  final Duration lastTouchedAt;
  final List<String> targetAircraftIds;
  final String? targetRunwayId;
  final double salience;
  final bool interrupted;
  final bool overdue;
  final bool forgotten;
  final bool resolved;

  const PendingIntentionSnapshot({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.lastTouchedAt,
    this.targetAircraftIds = const [],
    this.targetRunwayId,
    required this.salience,
    this.interrupted = false,
    this.overdue = false,
    this.forgotten = false,
    this.resolved = false,
  });

  Duration ageAt(Duration elapsed) => elapsed - createdAt;

  String get typeLabel => switch (type) {
        PendingIntentionType.plannedDescent => 'planned descent',
        PendingIntentionType.expectedTurn => 'expected turn',
        PendingIntentionType.runwayReassignment => 'runway reassignment',
        PendingIntentionType.sequencingAdjustment => 'sequencing adjustment',
        PendingIntentionType.handoffIntention => 'handoff intention',
      };
}

class WorkingMemoryState {
  final List<PendingIntentionSnapshot> pendingIntentions;
  final int forgottenIntentionCount;
  final int interruptedWorkflowCount;
  final int delayedFollowThroughCount;
  final int recoveredTaskCount;
  final int unrecoveredTaskCount;
  final int catchUpBurstCount;
  final double stressRecoveryLoad;
  final List<String> reportLines;

  const WorkingMemoryState({
    this.pendingIntentions = const [],
    this.forgottenIntentionCount = 0,
    this.interruptedWorkflowCount = 0,
    this.delayedFollowThroughCount = 0,
    this.recoveredTaskCount = 0,
    this.unrecoveredTaskCount = 0,
    this.catchUpBurstCount = 0,
    this.stressRecoveryLoad = 0,
    this.reportLines = const [],
  });

  static const WorkingMemoryState idle = WorkingMemoryState();
}
