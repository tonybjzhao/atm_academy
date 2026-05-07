import 'dart:math';
import '../core/models/scenario.dart';
import '../core/models/scenario_result.dart' as engine;
import '../models/projected_outcome.dart';
import '../models/replay_data.dart';
import '../models/replay_event.dart';
import '../models/scenario_result.dart';
import '../models/score_penalty.dart';

/// Transforms the engine-level [engine.ScenarioResult] + [ScenarioReplayData]
/// into a richer [DetailedScenarioResult] suitable for the debrief screen.
///
/// Flutter remains the single source of truth for all scoring — this class
/// only re-packages data that already exists.
class ScoringEngine {
  ScoringEngine._();

  // ── Main entry point ────────────────────────────────────────────────────────
  static DetailedScenarioResult fromExistingResult({
    required Scenario scenario,
    required engine.ScenarioResult result,
    required ScenarioReplayData replayData,
    required DateTime startedAt,
    required DateTime completedAt,
  }) {
    final frames    = _buildFrames(replayData);
    final events    = _buildEvents(replayData, result);
    final actions   = _buildUserActions(replayData, result);
    final penalties = _buildPenalties(result, replayData);
    final bonuses   = _buildBonuses(result);
    final projected = _buildProjectedOutcomes(result, replayData);
    final ideal     = _buildIdealFrames(replayData, result);
    final summary   = _buildSummary(result, replayData, scenario);
    final tips      = _buildTips(result, replayData);
    final grade     = ScenarioGradeLabel.fromScore(result.score);

    return DetailedScenarioResult(
      scenarioId:       scenario.id,
      scenarioTitle:    scenario.title.en,
      finalScore:       result.score,
      maxScore:         120,
      grade:            grade,
      startedAt:        startedAt,
      completedAt:      completedAt,
      replayFrames:     frames,
      idealFrames:      ideal,
      replayEvents:     events,
      userActions:      actions,
      penalties:        penalties,
      bonuses:          bonuses,
      projectedOutcomes: projected,
      summaryText:      summary,
      improvementTips:  tips,
      hadLOS:           result.hadLOS,
      minHorizDistPx:   result.minHorizontalDistancePx,
    );
  }

  // ── Interpolated replay frames ─────────────────────────────────────────────
  // Generates ~120 frames (20/s × 6 s) by linearly interpolating between
  // initial and final aircraft positions.
  static List<AircraftStateFrame> _buildFrames(ScenarioReplayData data) {
    const totalSec  = 6.0;
    const frameRate = 20.0; // frames per second
    final count = (totalSec * frameRate).round();
    final frames = <AircraftStateFrame>[];

    for (int f = 0; f <= count; f++) {
      final t   = f / count;
      final sec = f / frameRate;
      final ease = _smoothStep(t);

      for (int i = 0; i < data.initialAircraft.length; i++) {
        if (i >= data.finalAircraft.length) continue;
        final ini  = data.initialAircraft[i];
        final fin  = data.finalAircraft[i];
        frames.add(AircraftStateFrame(
          timestampSeconds: sec,
          callsign: ini.callsign,
          x:        ini.x + (fin.x - ini.x) * ease,
          y:        ini.y + (fin.y - ini.y) * ease,
          altitude: (ini.altitude + (fin.altitude - ini.altitude) * ease).round(),
          heading:  ini.heading + (fin.heading - ini.heading) * ease,
          speed:    ini.speed + (fin.speed - ini.speed) * ease,
        ));
      }
    }
    return frames;
  }

  // ── Replay events ──────────────────────────────────────────────────────────
  static List<ReplayEvent> _buildEvents(
      ScenarioReplayData data, engine.ScenarioResult result) {
    final events = <ReplayEvent>[];
    const totalSec = 6.0;

    // Conflict zone event
    if (data.closestPointTimeSec > 0) {
      events.add(ReplayEvent(
        timestampSeconds: data.closestPointTimeSec.clamp(0, totalSec),
        aircraftId: data.conflictPairCallsigns.join('/'),
        x: data.closestPointPxX,
        y: data.closestPointPxY,
        eventType: result.hadLOS
            ? ReplayEventType.separationLoss
            : ReplayEventType.conflictWarning,
        label: result.hadLOS ? 'LOS' : '⚠',
      ));
    }

    // User action event
    if (data.actionTimeSec > 0 && data.actionTimeSec <= totalSec) {
      // Find selected aircraft position at action time
      final selIdx = data.initialAircraft.indexWhere(
          (a) => data.finalAircraft.any((f) => f.callsign == a.callsign && f.wasSelected));
      final t    = data.actionTimeSec / totalSec;
      final ease = _smoothStep(t.clamp(0.0, 1.0));
      final ini  = selIdx >= 0 ? data.initialAircraft[selIdx] : data.initialAircraft.first;
      final fin  = selIdx >= 0 && selIdx < data.finalAircraft.length
          ? data.finalAircraft[selIdx]
          : data.finalAircraft.first;

      events.add(ReplayEvent(
        timestampSeconds: data.actionTimeSec,
        aircraftId: ini.callsign,
        x: ini.x + (fin.x - ini.x) * ease,
        y: ini.y + (fin.y - ini.y) * ease,
        eventType: _commandToEventType(data.userCommandSummary),
        label: _shortCommandLabel(data.userCommandSummary),
      ));
    }

    // Recovery event if separation was maintained
    if (!result.hadLOS && result.separationMaintained && data.closestPointTimeSec > 0) {
      final recoveryTime = (data.closestPointTimeSec + 2.5).clamp(0, 6.0);
      events.add(ReplayEvent(
        timestampSeconds: recoveryTime.toDouble(),
        aircraftId: '',
        x: 185, y: 215,
        eventType: ReplayEventType.recovered,
        label: '✓ Clear',
      ));
    }

    events.sort((a, b) => a.timestampSeconds.compareTo(b.timestampSeconds));
    return events;
  }

  // ── User actions ──────────────────────────────────────────────────────────
  static List<UserAction> _buildUserActions(
      ScenarioReplayData data, engine.ScenarioResult result) {
    if (data.actionTimeSec <= 0 || data.userCommandSummary.isEmpty) return [];

    // Derive command type from summary string
    final summary = data.userCommandSummary.toLowerCase();
    String cmd = 'left';
    if (summary.contains('right'))   cmd = 'right';
    else if (summary.contains('climb'))   cmd = 'climb';
    else if (summary.contains('descend')) cmd = 'descend';
    else if (summary.contains('slow'))    cmd = 'slow';
    else if (summary.contains('fast') || summary.contains('accel')) cmd = 'fast';

    // Feedback: good if result was safe, bad if LOS
    final fb = result.hadLOS ? 'bad' : result.goodCommands > 0 ? 'good' : 'neutral';

    return [
      UserAction(
        timestampSeconds: data.actionTimeSec,
        callsign: result.conflictPair.isNotEmpty ? result.conflictPair.first : '',
        command: cmd,
        feedback: fb,
      ),
    ];
  }

  // ── Penalties ──────────────────────────────────────────────────────────────
  static List<ScorePenalty> _buildPenalties(
      engine.ScenarioResult result, ScenarioReplayData data) {
    final list = <ScorePenalty>[];
    if (result.penaltyBreakdown.isEmpty ||
        result.penaltyBreakdown.first == 'None') return list;

    final pairStr = result.conflictPair.join(' & ');
    final ts = data.closestPointTimeSec > 0 ? data.closestPointTimeSec : 3.0;

    for (final raw in result.penaltyBreakdown) {
      final lower = raw.toLowerCase();

      if (lower.contains('loss of separation')) {
        list.add(ScorePenalty(
          timestampSeconds: ts,
          type:         ScorePenaltyType.separationLoss,
          pointsLost:   60,
          title:        'Loss of Separation',
          explanation:  '$pairStr came within ${result.minHorizontalDistancePx.toStringAsFixed(0)} px '
                        '— below the 60 px minimum. Separation was lost.',
          recommendation: 'Issue a heading or altitude change as soon as aircraft enter '
                          'the advisory zone (90 px), not after the warning triggers.',
        ));
      } else if (lower.contains('warning zone')) {
        list.add(ScorePenalty(
          timestampSeconds: ts,
          type:         ScorePenaltyType.conflictWarningUnresolved,
          pointsLost:   25,
          title:        'Warning Zone Reached',
          explanation:  '$pairStr entered the warning zone '
                        '(${result.minHorizontalDistancePx.toStringAsFixed(0)} px). '
                        'Separation was not fully lost but reached a critical level.',
          recommendation: 'React before the warning activates. '
                          'Proactive early vectors are safer and score higher.',
        ));
      } else if (lower.contains('no command')) {
        list.add(ScorePenalty(
          timestampSeconds: 0,
          type:         ScorePenaltyType.noCommandIssued,
          pointsLost:   30,
          title:        'No Command Issued',
          explanation:  'No action was taken during the scenario.',
          recommendation: 'Always issue a command when aircraft are converging — '
                          'even a small heading change early creates useful separation.',
        ));
      } else if (lower.contains('late command')) {
        final pts = lower.contains('−20') || lower.contains('-20') ? 20 : 10;
        final reactionStr = result.reactionTimeSec > 0
            ? '${result.reactionTimeSec.toStringAsFixed(1)} s'
            : 'unknown';
        list.add(ScorePenalty(
          timestampSeconds: result.reactionTimeSec,
          type:         ScorePenaltyType.lateVector,
          pointsLost:   pts,
          title:        'Late Command ($reactionStr)',
          explanation:  'Your first command came $reactionStr into the scenario. '
                        'Conflict risk was already elevated.',
          recommendation: 'Act within 5 seconds when aircraft are converging. '
                          'Early action gives more room to manoeuvre.',
        ));
      } else if (lower.contains('wrong aircraft')) {
        list.add(ScorePenalty(
          timestampSeconds: result.reactionTimeSec,
          type:         ScorePenaltyType.wrongAircraftSelected,
          pointsLost:   20,
          title:        'Wrong Aircraft Selected',
          explanation:  'The aircraft you commanded was not part of the conflict pair ($pairStr).',
          recommendation: 'Identify the conflicting pair first — they appear in red/orange. '
                          'Issue commands to one of those aircraft.',
        ));
      } else if (lower.contains('ineffective command')) {
        final match = RegExp(r'×(\d+)').firstMatch(raw);
        final count = match != null ? int.tryParse(match.group(1) ?? '1') ?? 1 : 1;
        final pts   = count * 25;
        list.add(ScorePenalty(
          timestampSeconds: result.reactionTimeSec > 0 ? result.reactionTimeSec + 0.5 : 2.0,
          type:         ScorePenaltyType.ineffectiveCommand,
          pointsLost:   pts,
          title:        'Ineffective Command${count > 1 ? " ×$count" : ""}',
          explanation:  'Your command${count > 1 ? "s" : ""} did not improve projected separation — '
                        '${count > 1 ? "they" : "it"} may have worsened the trajectory.',
          recommendation: 'Check the projected path before acting. '
                          'A turn toward the other aircraft increases risk.',
        ));
      } else if (lower.contains('unnecessary command')) {
        list.add(ScorePenalty(
          timestampSeconds: result.reactionTimeSec > 0 ? result.reactionTimeSec + 1.0 : 3.0,
          type:         ScorePenaltyType.excessiveHeadingChange,
          pointsLost:   10,
          title:        'Unnecessary Commands',
          explanation:  'Extra commands that did not help separation were issued.',
          recommendation: 'Issue one clear command and allow time for it to take effect '
                          'before issuing another. Over-controlling adds complexity.',
        ));
      }
    }
    return list;
  }

  // ── Bonuses ────────────────────────────────────────────────────────────────
  static List<ScoreBonus> _buildBonuses(engine.ScenarioResult result) {
    final list = <ScoreBonus>[];
    for (final raw in result.bonusBreakdown) {
      if (raw == 'None') continue;
      final lower = raw.toLowerCase();
      if (lower.contains('separation maintained')) {
        list.add(const ScoreBonus(
          title: 'Separation Maintained',
          pointsGained: 10,
          explanation: 'Aircraft remained separated for 5+ continuous seconds.',
        ));
      } else if (lower.contains('correct aircraft')) {
        list.add(const ScoreBonus(
          title: 'Correct Aircraft Selected',
          pointsGained: 10,
          explanation: 'You immediately identified and commanded the right aircraft.',
        ));
      } else if (lower.contains('early')) {
        list.add(const ScoreBonus(
          title: 'Early Effective Action',
          pointsGained: 10,
          explanation: 'Your command was issued within 5 s and improved the projected path.',
        ));
      }
    }
    return list;
  }

  // ── Projected outcomes ────────────────────────────────────────────────────
  // Simple approximation: not physics-accurate, but convincing and fair.
  // For each major penalty we estimate how much separation would have
  // improved with a better decision, then phrase it in coaching language.
  static List<ProjectedOutcome> _buildProjectedOutcomes(
      engine.ScenarioResult result, ScenarioReplayData data) {

    final outcomes   = <ProjectedOutcome>[];
    final actualSep  = result.minHorizontalDistancePx;
    final pairFirst  = result.conflictPair.isNotEmpty ? result.conflictPair.first : '';
    final pairStr    = result.conflictPair.join(' & ');
    final reactionSec = result.reactionTimeSec;

    for (final raw in result.penaltyBreakdown) {
      if (raw == 'None') continue;
      final lower = raw.toLowerCase();

      // ── Loss of separation ────────────────────────────────────────────────
      if (lower.contains('loss of separation')) {
        final timeSaved   = 8.0;
        final projSep     = (actualSep + 38.0)\.clamp(0.0, 300.0);
        final idealAction = reactionSec > timeSaved
            ? reactionSec - timeSaved
            : max(0.0, reactionSec - 2);
        outcomes.add(ProjectedOutcome(
          timestampSeconds:          idealAction,
          aircraftId:                pairFirst,
          alternativeAction:         'Turn $pairFirst at t=${idealAction.toStringAsFixed(0)}s '
                                     '(${timeSaved.toInt()}s earlier)',
          projectedSeparation:       projSep,
          projectedConflictResolved: projSep >= 60,
          explanation:               'At t=${idealAction.toStringAsFixed(0)}s the aircraft '
                                     'were still ~${(actualSep + 55).toStringAsFixed(0)} px apart. '
                                     'An early turn of 15° would have kept projected separation '
                                     'above ${projSep.toStringAsFixed(0)} px — above the 60 px threshold.',
          insightText:               'Earlier vectoring gives more room to manoeuvre. '
                                     'Act before the warning activates.',
        ));
      }

      // ── Late command ──────────────────────────────────────────────────────
      else if (lower.contains('late command')) {
        final timeSaved = 5.0;
        final projSep   = (actualSep + 22.0)\.clamp(0.0, 300.0);
        final idealTs   = max(0.0, reactionSec - timeSaved);
        outcomes.add(ProjectedOutcome(
          timestampSeconds:          idealTs,
          aircraftId:                pairFirst,
          alternativeAction:         'Act at t=${idealTs.toStringAsFixed(0)}s '
                                     '(${timeSaved.toInt()}s sooner)',
          projectedSeparation:       projSep,
          projectedConflictResolved: projSep >= 60,
          explanation:               'Issuing the same command ${timeSaved.toInt()}s earlier '
                                     'would have given the aircraft more time to diverge, '
                                     'raising projected minimum separation to '
                                     '~${projSep.toStringAsFixed(0)} px.',
          insightText:               'Good recovery, but earlier action improves the safety margin.',
        ));
      }

      // ── Wrong aircraft ────────────────────────────────────────────────────
      else if (lower.contains('wrong aircraft')) {
        final projSep = (actualSep + 32.0)\.clamp(0.0, 300.0);
        outcomes.add(ProjectedOutcome(
          timestampSeconds:          reactionSec,
          aircraftId:                pairFirst,
          alternativeAction:         'Command $pairFirst (conflict aircraft) instead',
          projectedSeparation:       projSep,
          projectedConflictResolved: true,
          explanation:               '$pairFirst was the aircraft driving the conflict. '
                                     'Commanding it directly at t=${reactionSec.toStringAsFixed(1)}s '
                                     'would have increased projected separation to '
                                     '~${projSep.toStringAsFixed(0)} px.',
          insightText:               'Identify the conflict pair first — they appear in red. '
                                     'Always act on one of those aircraft.',
        ));
      }

      // ── No command ────────────────────────────────────────────────────────
      else if (lower.contains('no command')) {
        final projSep = (actualSep + 45.0)\.clamp(0.0, 300.0);
        outcomes.add(ProjectedOutcome(
          timestampSeconds:          3.0,
          aircraftId:                pairFirst,
          alternativeAction:         'Turn $pairFirst left 15° at t=3s',
          projectedSeparation:       projSep,
          projectedConflictResolved: projSep >= 60,
          explanation:               'A single 15° heading change on $pairFirst at t=3s '
                                     'would have deflected its track, raising minimum '
                                     'separation to ~${projSep.toStringAsFixed(0)} px.',
          insightText:               'Even a small heading change early in the scenario '
                                     'is enough to prevent most conflicts.',
        ));
      }

      // ── Ineffective command ───────────────────────────────────────────────
      else if (lower.contains('ineffective command')) {
        final projSep = (actualSep + 28.0)\.clamp(0.0, 300.0);
        outcomes.add(ProjectedOutcome(
          timestampSeconds:          reactionSec,
          aircraftId:                pairFirst,
          alternativeAction:         'Turn $pairFirst in the opposite direction',
          projectedSeparation:       projSep,
          projectedConflictResolved: projSep >= 60,
          explanation:               'Your command moved $pairFirst toward the conflict. '
                                     'Turning the opposite way at the same moment would '
                                     'have projected separation to ~${projSep.toStringAsFixed(0)} px.',
          insightText:               'Check which way opens separation before turning. '
                                     'A turn toward the other aircraft makes things worse.',
        ));
      }
    }
    return outcomes;
  }

  // ── Ideal replay frames ────────────────────────────────────────────────────
  // Generates an alternative set of aircraft frames showing what the replay
  // would have looked like if the user had acted earlier / more effectively.
  // Approximation: the selected aircraft is deflected away from the conflict
  // pair after the "ideal action time", creating more separation.
  static List<AircraftStateFrame> _buildIdealFrames(
      ScenarioReplayData data, engine.ScenarioResult result) {

    if (data.initialAircraft.isEmpty || data.finalAircraft.isEmpty) return [];

    // Identify the "key" aircraft (conflict pair member) and its index
    final keyCallsign = result.conflictPair.isNotEmpty ? result.conflictPair.first : '';
    final keyIdx = data.initialAircraft.indexWhere((a) => a.callsign == keyCallsign);
    if (keyIdx < 0) return []; // cannot build ideal without conflict pair info

    // Ideal action 6 seconds earlier than actual (clamped to t=2s minimum)
    final idealActionSec = max(2.0, result.reactionTimeSec - 6.0);

    const totalSec   = 6.0;
    const frameCount = 120;
    final frames = <AircraftStateFrame>[];

    for (int f = 0; f <= frameCount; f++) {
      final t    = f / frameCount;
      final sec  = f / 20.0;
      final ease = _smoothStep(t);

      for (int i = 0; i < data.initialAircraft.length; i++) {
        if (i >= data.finalAircraft.length) continue;
        final ini = data.initialAircraft[i];
        final fin = data.finalAircraft[i];

        double x = ini.x + (fin.x - ini.x) * ease;
        double y = ini.y + (fin.y - ini.y) * ease;

        // Apply deflection to the key aircraft after ideal action time
        if (i == keyIdx && sec >= idealActionSec) {
          final deflectFrac = ((sec - idealActionSec) / (totalSec - idealActionSec))
              .clamp(0.0, 1.0);
          // Perpendicular push: assume conflict is horizontal, push vertically
          final deflectAmount = deflectFrac * 55.0; // up to 55 px offset
          // Determine push direction: away from the other conflict aircraft
          final otherIdx = data.initialAircraft.indexWhere(
              (a) => result.conflictPair.contains(a.callsign) && a.callsign != keyCallsign);
          if (otherIdx >= 0) {
            final otherY = data.initialAircraft[otherIdx].y +
                (data.finalAircraft[otherIdx].y - data.initialAircraft[otherIdx].y) * ease;
            y += y < otherY ? -deflectAmount : deflectAmount;
          } else {
            y -= deflectAmount; // default: push up
          }
        }

        frames.add(AircraftStateFrame(
          timestampSeconds: sec,
          callsign: ini.callsign,
          x: x,
          y: y,
          altitude: (ini.altitude + (fin.altitude - ini.altitude) * ease).round(),
          heading:  ini.heading + (fin.heading - ini.heading) * ease,
          speed:    ini.speed + (fin.speed - ini.speed) * ease,
        ));
      }
    }
    return frames;
  }

  // ── Summary text ──────────────────────────────────────────────────────────
  static String _buildSummary(
      engine.ScenarioResult result, ScenarioReplayData data, Scenario scenario) {
    final pairStr = result.conflictPair.join(' & ');
    final sepStr  = '${result.minHorizontalDistancePx.toStringAsFixed(0)} px';

    if (result.hadLOS) {
      return '$pairStr lost separation (closest: $sepStr). '
             'Act earlier to prevent conflict from developing.';
    }
    if (result.warningReached) {
      return '$pairStr entered the warning zone ($sepStr). '
             'Separation held, but the situation was close.';
    }
    if (!result.separationMaintained) {
      return 'Conflict resolved but separation window was tight. '
             'Earlier action gives a safer margin.';
    }
    return 'Good control. $pairStr maintained safe separation throughout.';
  }

  // ── Improvement tips ──────────────────────────────────────────────────────
  static List<String> _buildTips(
      engine.ScenarioResult result, ScenarioReplayData data) {
    final tips = <String>[];

    if (result.reactionTimeSec > 8) {
      tips.add('Issue commands earlier — within 5 s of detecting a converging '
               'track. The later you act, the fewer options remain.');
    }
    if (!result.selectedAircraftCorrect) {
      tips.add('Select the aircraft that is part of the conflict pair (shown in '
               'red/orange). Commanding the wrong aircraft wastes time.');
    }
    if (result.badCommands > 0) {
      tips.add('Check the projected path before commanding. A turn that points '
               'an aircraft toward another will worsen the situation.');
    }
    if (result.hadLOS) {
      tips.add('After a loss of separation, issue a vertical (climb/descend) command '
               'immediately — it provides the fastest separation.');
    }
    if (result.neutralCommands > 2) {
      tips.add('Avoid issuing multiple commands in quick succession. '
               'Issue one command and wait to observe the effect.');
    }
    if (tips.isEmpty) {
      tips.add('Try to resolve the conflict in the first half of the time limit '
               'for a +20 time bonus.');
    }
    return tips.take(3).toList();
  }

  // ── Mock data (for testing without a real scenario) ───────────────────────
  static DetailedScenarioResult mock() {
    final now = DateTime.now();
    return DetailedScenarioResult(
      scenarioId:    'mock_crossing',
      scenarioTitle: 'Crossing Traffic at Same Level',
      finalScore:    75,
      maxScore:      120,
      grade:         ScenarioGrade.good,
      startedAt:     now.subtract(const Duration(seconds: 28)),
      completedAt:   now,
      hadLOS:        false,
      minHorizDistPx: 64.0,
      summaryText: 'QFA123 & UAE406 entered the warning zone (64 px). '
                   'Separation held, but the situation was close.',
      improvementTips: [
        'Act within 5 s of detecting a converging track.',
        'A single early heading change creates more margin.',
      ],
      userActions: [
        const UserAction(
          timestampSeconds: 7.2,
          callsign: 'QFA123',
          command: 'left',
          feedback: 'good',
        ),
      ],
      replayEvents: [
        const ReplayEvent(
          timestampSeconds: 4.5,
          aircraftId: 'QFA123/UAE406',
          x: 185, y: 200,
          eventType: ReplayEventType.conflictWarning,
          label: '⚠',
        ),
        const ReplayEvent(
          timestampSeconds: 7.2,
          aircraftId: 'QFA123',
          x: 140, y: 195,
          eventType: ReplayEventType.userVector,
          label: '↙ Turn',
        ),
        const ReplayEvent(
          timestampSeconds: 10.5,
          aircraftId: '',
          x: 185, y: 215,
          eventType: ReplayEventType.recovered,
          label: '✓ Clear',
        ),
      ],
      replayFrames: _mockFrames(),
      penalties: [
        const ScorePenalty(
          timestampSeconds: 4.5,
          type: ScorePenaltyType.conflictWarningUnresolved,
          pointsLost: 25,
          title: 'Warning Zone Reached',
          explanation: 'QFA123 & UAE406 entered the warning zone (64 px).',
          recommendation: 'React before the warning activates with an early vector.',
        ),
        const ScorePenalty(
          timestampSeconds: 7.2,
          type: ScorePenaltyType.lateVector,
          pointsLost: 10,
          title: 'Late Command (7.2 s)',
          explanation: 'Your first command came 7.2 s in. Conflict risk was already elevated.',
          recommendation: 'Act within 5 s when aircraft are converging.',
        ),
      ],
      bonuses: [
        const ScoreBonus(
          title: 'Separation Maintained',
          pointsGained: 10,
          explanation: 'Aircraft remained separated for 5+ continuous seconds.',
        ),
      ],
      projectedOutcomes: [
        const ProjectedOutcome(
          timestampSeconds:          2.2,
          aircraftId:                'QFA123',
          alternativeAction:         'Turn QFA123 at t=2s (5s earlier)',
          projectedSeparation:       86.0,
          projectedConflictResolved: true,
          explanation:               'At t=2s the aircraft were ~115 px apart. '
                                     'A 15° left turn on QFA123 would have kept '
                                     'projected minimum separation above 86 px — well '
                                     'clear of the 60 px threshold.',
          insightText:               'Good recovery, but earlier action improves the safety margin.',
        ),
      ],
      idealFrames: [],  // populated by _buildIdealFrames in real usage
    );
  }

  static List<AircraftStateFrame> _mockFrames() {
    final frames = <AircraftStateFrame>[];
    const count = 120;
    for (int f = 0; f <= count; f++) {
      final t    = f / count;
      final sec  = f / 20.0;
      final ease = _smoothStep(t);

      // QFA123: x 60→180, y 210→165
      frames.add(AircraftStateFrame(
        timestampSeconds: sec,
        callsign: 'QFA123',
        x: 60  + (180  - 60)  * ease,
        y: 210 + (165 - 210) * ease,
        altitude: 320,
        heading: 90 + (-15) * ease, // turns left
        speed: 0.8,
      ));
      // UAE406: x 310→222, y 210→205
      frames.add(AircraftStateFrame(
        timestampSeconds: sec,
        callsign: 'UAE406',
        x: 310 + (222 - 310) * ease,
        y: 210 + (205 - 210) * ease,
        altitude: 320,
        heading: 270,
        speed: 0.8,
      ));
    }
    return frames;
  }

  // ── Utilities ─────────────────────────────────────────────────────────────
  static double _smoothStep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static ReplayEventType _commandToEventType(String summary) {
    final s = summary.toLowerCase();
    if (s.contains('climb') || s.contains('descend')) {
      return ReplayEventType.userAltitudeChange;
    }
    if (s.contains('slow') || s.contains('fast')) {
      return ReplayEventType.userSpeedChange;
    }
    return ReplayEventType.userVector;
  }

  static String _shortCommandLabel(String summary) {
    if (summary.isEmpty) return '';
    final s = summary.toLowerCase();
    if (s.contains('turn left'))    return '↙';
    if (s.contains('turn right'))   return '↘';
    if (s.contains('climb'))        return '▲';
    if (s.contains('descend'))      return '▼';
    if (s.contains('slow'))         return '◀';
    if (s.contains('fast') || s.contains('accel')) return '▶';
    return '⬤';
  }
}
