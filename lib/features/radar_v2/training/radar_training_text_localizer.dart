import '../../../l10n/app_localizations.dart';

class RadarTrainingTextLocalizer {
  const RadarTrainingTextLocalizer._();

  static String line(AppLocalizations l10n, String input) {
    final text = input.trim();
    if (text.isEmpty) return text;

    final timelineOverload = RegExp(r'^Overload lasted (\d+)s$').firstMatch(text);
    if (timelineOverload != null) {
      return l10n.radarTrainingTimelineOverload(
        int.parse(timelineOverload.group(1)!),
      );
    }

    final separationEvents =
        RegExp(r'^(\d+) separation loss event\(s\)$').firstMatch(text);
    if (separationEvents != null) {
      return l10n.radarTrainingTimelineSeparationLossEvents(
        int.parse(separationEvents.group(1)!),
      );
    }

    final commandEvents =
        RegExp(r'^(\d+) controller commands$').firstMatch(text);
    if (commandEvents != null) {
      return l10n.radarTrainingTimelineControllerCommands(
        int.parse(commandEvents.group(1)!),
      );
    }

    final rootSurprise = RegExp(r'^Root surprise event: (.+)\.$').firstMatch(text);
    if (rootSurprise != null) {
      return l10n.radarTrainingRootSurpriseEvent(rootSurprise.group(1)!);
    }

    final recoveredTasks =
        RegExp(r'^Recovered tasks: (\d+); unrecovered: (\d+)\.$').firstMatch(text);
    if (recoveredTasks != null) {
      return l10n.radarTrainingRecoveredTasks(
        int.parse(recoveredTasks.group(1)!),
        int.parse(recoveredTasks.group(2)!),
      );
    }

    final cascadeEdgeInterrupted = RegExp(
            r'^Evidence suggests (.+) was interrupted by recovery activity \((.+)\)\.$')
        .firstMatch(text);
    if (cascadeEdgeInterrupted != null) {
      final fromLabel = cascadeEdgeInterrupted.group(1)!;
      final factorText = cascadeEdgeInterrupted.group(2)!;
      final localizedFactor = _localizeFactor(l10n, factorText);
      return l10n.radarTrainingCascadeEvidenceInterrupted(
        fromLabel,
        localizedFactor,
      );
    }

    final cascadeEdgeContributed = RegExp(
            r'^Evidence suggests (.+) likely contributed to (.+) through (.+)\.(.*?)$')
        .firstMatch(text);
    if (cascadeEdgeContributed != null) {
      final fromLabel = cascadeEdgeContributed.group(1)!;
      final toLabel = cascadeEdgeContributed.group(2)!;
      var factorText = cascadeEdgeContributed.group(3)!;
      final recoveryClause = cascadeEdgeContributed.group(4)?.trim() ?? '';
      final localizedFactor = _localizeFactor(l10n, factorText);
      final recoveryPart = recoveryClause.isNotEmpty
          ? ' ${l10n.radarTrainingCascadeEvidenceRecoveryWeakens}'
          : '';
      return l10n.radarTrainingCascadeEvidenceContributed(
        fromLabel,
        toLabel,
        localizedFactor,
      ) + recoveryPart;
    }

    final conflictLateResolution = RegExp(
            r'^A conflict was resolved later than the traffic picture required\.$')
        .firstMatch(text);
    if (conflictLateResolution != null) {
      return l10n.radarTrainingCascadeLateResolution;
    }

    final workloadCompetition = RegExp(
            r'^Workload rose as unresolved alerts and commands competed\.$')
        .firstMatch(text);
    if (workloadCompetition != null) {
      return l10n.radarTrainingCascadeWorkloadCompetition;
    }

    final conflictSeparationPressure = RegExp(
            r'^Conflict cue was not resolved before separation pressure rose\.$')
        .firstMatch(text);
    if (conflictSeparationPressure != null) {
      return l10n.radarTrainingCascadeConflictSeparationPressure;
    }

    final recoveryUnstable = RegExp(
            r'^Recovery stayed unstable while safety-critical pressure remained\.$')
        .firstMatch(text);
    if (recoveryUnstable != null) {
      return l10n.radarTrainingCascadeRecoveryUnstable;
    }

    const directMap = <String, String>{
      'T+0s: Scenario started': 'radarTrainingTimelineStarted',
      'Expectation drift detected near final workload phase':
          'radarTrainingTimelineExpectationDrift',
      'Traffic remained inside planned operating limits':
          'radarTrainingTimelineStable',
      'No radio cadence sample available.':
          'radarTrainingNoRadioCadenceSample',
      'No timely readbacks captured (all beyond 12s).':
          'radarTrainingNoTimelyReadbacks',
      'Traffic flow remained stable with no major debrief item.':
          'radarTrainingStableNoMajorDebrief',
      'Traffic flow remained stable with no major cognitive events.':
          'radarTrainingStableNoMajorCognitiveEvents',
      'No major replay markers captured.': 'radarTrainingNoMajorReplayMarkers',
      'No cascade propagation detected in this replay.':
          'radarTrainingNoCascadePropagationDetected',
      'Primary propagation chain': 'radarTrainingPrimaryPropagationChain',
      'Top mistake': 'radarTrainingTopMistake',
      'Best recovery': 'radarTrainingBestRecovery',
      'Additional Debrief': 'radarTrainingAdditionalDebrief',
      'Operational Pressure Ecology': 'radarTrainingOperationalPressureEcology',
      'Timeline Summary': 'radarTrainingTimelineSummary',
      'Replay Explanation': 'radarTrainingReplayExplanation',
      'Controller Evaluation': 'radarTrainingControllerEvaluation',
      'More details': 'radarTrainingMoreDetails',
      'Advanced analysis and replay context':
          'radarTrainingAdvancedAnalysisReplayContext',
      'Cognitive Timeline': 'radarTrainingCognitiveTimeline',
      'Cascade Propagation': 'radarTrainingCascadePropagation',
      'warning': 'radarTrainingMarkerWarning',
      'late': 'radarTrainingMarkerLate',
      'memory': 'radarTrainingMarkerMemory',
      'expectation': 'radarTrainingMarkerExpectation',
      'cascade': 'radarTrainingMarkerCascade',
      'overload': 'radarTrainingMarkerOverload',
      'recovery': 'radarTrainingMarkerRecovery',
      'debrief': 'radarTrainingMarkerDebrief',
      'Workload': 'radarTrainingLabelWorkload',
      'Attention': 'radarTrainingLabelAttention',
      'Memory': 'radarTrainingLabelMemory',
      'Surprise': 'radarTrainingLabelSurprise',
      'Fixation': 'radarTrainingCascadeFixation',
      'Scan blind': 'radarTrainingLabelScanBlind',
      'Recovery': 'radarTrainingLabelRecovery',
      'Expectation': 'radarTrainingLabelExpectation',
      'Self-check': 'radarTrainingLabelSelfCheck',
      'Baseline workload': 'radarTrainingLabelBaselineWorkload',
      'Overload peak': 'radarTrainingLabelOverloadPeak',
      'Sustained overload': 'radarTrainingLabelSustainedOverload',
      'Attention quality': 'radarTrainingLabelAttentionQuality',
      'Long unseen interval': 'radarTrainingLabelLongUnseenInterval',
      'Task stability': 'radarTrainingLabelTaskStability',
      'Surprise load': 'radarTrainingLabelSurpriseLoad',
      'Stabilized flow': 'radarTrainingLabelStabilizedFlow',
      'False recovery': 'radarTrainingLabelFalseRecovery',
      'Fixation risk': 'radarTrainingLabelFixationRisk',
      'Scan narrowing': 'radarTrainingLabelScanNarrowing',
      'Confidence collapse': 'radarTrainingLabelConfidenceCollapse',
      'Self-assessment divergence': 'radarTrainingLabelSelfAssessmentDivergence',
    };

    final method = directMap[text];
    if (method != null) {
      return _lookupSimple(l10n, method);
    }

    if (l10n.localeName != 'en' && RegExp(r'[A-Za-z]').hasMatch(text)) {
      return l10n.radarTrainingAdditionalOperationalDetail;
    }

    return text;
  }

  static String insightTitle(AppLocalizations l10n, String title) {
    switch (title) {
      case 'Separation Risk':
        return l10n.radarTrainingInsightSeparationRisk;
      case 'Ignored Alert':
        return l10n.radarTrainingInsightIgnoredAlert;
      case 'Attention Fixation':
        return l10n.radarTrainingInsightAttentionFixation;
      case 'Workload Spike':
        return l10n.radarTrainingInsightWorkloadSpike;
      case 'Runway Flow Risk':
        return l10n.radarTrainingInsightRunwayFlowRisk;
      case 'Expectation Drift':
        return l10n.radarTrainingInsightExpectationDrift;
      case 'Destabilisation':
        return l10n.radarTrainingInsightDestabilisation;
      case 'Task Follow-Through':
        return l10n.radarTrainingInsightTaskFollowThrough;
      case 'Safety Insight':
        return l10n.radarTrainingInsightSafety;
      case 'Workload Insight':
        return l10n.radarTrainingInsightWorkload;
      case 'Attention Insight':
        return l10n.radarTrainingInsightAttention;
      case 'Memory Insight':
        return l10n.radarTrainingInsightMemory;
      case 'Prediction Insight':
        return l10n.radarTrainingInsightPrediction;
      case 'Cascade Insight':
        return l10n.radarTrainingInsightCascade;
      case 'Self-Monitoring Insight':
        return l10n.radarTrainingInsightSelfMonitoring;
      case 'Controller Profile':
        return l10n.radarTrainingInsightControllerProfile;
      case 'Training Pattern':
        return l10n.radarTrainingInsightTrainingPattern;
      case 'Recovery Insight':
        return l10n.radarTrainingInsightRecovery;
      case 'Traffic Flow Insight':
        return l10n.radarTrainingInsightTrafficFlow;
      default:
        return line(l10n, title);
    }
  }

  static String cascadeNodeLabel(AppLocalizations l10n, String label) {
    switch (label) {
      case 'Cascade origin':
        return l10n.radarTrainingCascadeOrigin;
      case 'Fixation':
        return l10n.radarTrainingCascadeFixation;
      case 'Scan neglect':
        return l10n.radarTrainingCascadeScanNeglect;
      case 'Task memory failure':
        return l10n.radarTrainingCascadeTaskMemoryFailure;
      case 'Missed conflict':
        return l10n.radarTrainingCascadeMissedConflict;
      case 'Overload increase':
        return l10n.radarTrainingCascadeOverloadIncrease;
      case 'Expectation drift':
        return l10n.radarTrainingCascadeExpectationDrift;
      case 'Confidence erosion':
        return l10n.radarTrainingCascadeConfidenceErosion;
      case 'Delayed intervention':
        return l10n.radarTrainingCascadeDelayedIntervention;
      case 'Recovery interrupted':
        return l10n.radarTrainingCascadeRecoveryInterrupted;
      case 'Stabilization':
        return l10n.radarTrainingCascadeStabilization;
      case 'Recovery breakdown':
        return l10n.radarTrainingCascadeRecoveryBreakdown;
      default:
        return line(l10n, label);
    }
  }

  static String cascadeChainTitle(AppLocalizations l10n, String title) {
    final parallel = RegExp(r'^Parallel chain (\d+)$').firstMatch(title);
    if (parallel != null) {
      return l10n.radarTrainingParallelChain(int.parse(parallel.group(1)!));
    }
    if (title == 'Primary propagation chain') {
      return l10n.radarTrainingPrimaryPropagationChain;
    }
    return line(l10n, title);
  }

  static String _localizeFactor(AppLocalizations l10n, String factor) {
    switch (factor.trim()) {
      case 'close timing':
        return l10n.radarTrainingCascadeFactorCloseTiming;
      case 'alert density':
        return l10n.radarTrainingCascadeFactorAlertDensity;
      case 'attention degradation overlap':
        return l10n.radarTrainingCascadeFactorAttentionDegradation;
      case 'unresolved conflict pressure':
        return l10n.radarTrainingCascadeFactorUnresolvedConflict;
      case 'recovery interruption reduced confidence':
        return l10n.radarTrainingCascadeFactorRecoveryInterruption;
      case 'weak timing signal':
        return l10n.radarTrainingCascadeFactorWeakTiming;
      default:
        return factor;
    }
  }

  static String _lookupSimple(AppLocalizations l10n, String key) {
    switch (key) {
      case 'radarTrainingTimelineStarted':
        return l10n.radarTrainingTimelineStarted;
      case 'radarTrainingTimelineExpectationDrift':
        return l10n.radarTrainingTimelineExpectationDrift;
      case 'radarTrainingTimelineStable':
        return l10n.radarTrainingTimelineStable;
      case 'radarTrainingNoRadioCadenceSample':
        return l10n.radarTrainingNoRadioCadenceSample;
      case 'radarTrainingNoTimelyReadbacks':
        return l10n.radarTrainingNoTimelyReadbacks;
      case 'radarTrainingStableNoMajorDebrief':
        return l10n.radarTrainingStableNoMajorDebrief;
      case 'radarTrainingStableNoMajorCognitiveEvents':
        return l10n.radarTrainingStableNoMajorCognitiveEvents;
      case 'radarTrainingNoMajorReplayMarkers':
        return l10n.radarTrainingNoMajorReplayMarkers;
      case 'radarTrainingNoCascadePropagationDetected':
        return l10n.radarTrainingNoCascadePropagationDetected;
      case 'radarTrainingPrimaryPropagationChain':
        return l10n.radarTrainingPrimaryPropagationChain;
      case 'radarTrainingTopMistake':
        return l10n.radarTrainingTopMistake;
      case 'radarTrainingBestRecovery':
        return l10n.radarTrainingBestRecovery;
      case 'radarTrainingAdditionalDebrief':
        return l10n.radarTrainingAdditionalDebrief;
      case 'radarTrainingOperationalPressureEcology':
        return l10n.radarTrainingOperationalPressureEcology;
      case 'radarTrainingTimelineSummary':
        return l10n.radarTrainingTimelineSummary;
      case 'radarTrainingReplayExplanation':
        return l10n.radarTrainingReplayExplanation;
      case 'radarTrainingControllerEvaluation':
        return l10n.radarTrainingControllerEvaluation;
      case 'radarTrainingMoreDetails':
        return l10n.radarTrainingMoreDetails;
      case 'radarTrainingAdvancedAnalysisReplayContext':
        return l10n.radarTrainingAdvancedAnalysisReplayContext;
      case 'radarTrainingCognitiveTimeline':
        return l10n.radarTrainingCognitiveTimeline;
      case 'radarTrainingCascadePropagation':
        return l10n.radarTrainingCascadePropagation;
      case 'radarTrainingMarkerWarning':
        return l10n.radarTrainingMarkerWarning;
      case 'radarTrainingMarkerLate':
        return l10n.radarTrainingMarkerLate;
      case 'radarTrainingMarkerMemory':
        return l10n.radarTrainingMarkerMemory;
      case 'radarTrainingMarkerExpectation':
        return l10n.radarTrainingMarkerExpectation;
      case 'radarTrainingMarkerCascade':
        return l10n.radarTrainingMarkerCascade;
      case 'radarTrainingMarkerOverload':
        return l10n.radarTrainingMarkerOverload;
      case 'radarTrainingMarkerRecovery':
        return l10n.radarTrainingMarkerRecovery;
      case 'radarTrainingMarkerDebrief':
        return l10n.radarTrainingMarkerDebrief;
      case 'radarTrainingLabelWorkload':
        return l10n.radarTrainingLabelWorkload;
      case 'radarTrainingLabelAttention':
        return l10n.radarTrainingLabelAttention;
      case 'radarTrainingLabelMemory':
        return l10n.radarTrainingLabelMemory;
      case 'radarTrainingLabelSurprise':
        return l10n.radarTrainingLabelSurprise;
      case 'radarTrainingLabelScanBlind':
        return l10n.radarTrainingLabelScanBlind;
      case 'radarTrainingLabelRecovery':
        return l10n.radarTrainingLabelRecovery;
      case 'radarTrainingLabelExpectation':
        return l10n.radarTrainingLabelExpectation;
      case 'radarTrainingLabelSelfCheck':
        return l10n.radarTrainingLabelSelfCheck;
      case 'radarTrainingLabelBaselineWorkload':
        return l10n.radarTrainingLabelBaselineWorkload;
      case 'radarTrainingLabelOverloadPeak':
        return l10n.radarTrainingLabelOverloadPeak;
      case 'radarTrainingLabelSustainedOverload':
        return l10n.radarTrainingLabelSustainedOverload;
      case 'radarTrainingLabelAttentionQuality':
        return l10n.radarTrainingLabelAttentionQuality;
      case 'radarTrainingLabelLongUnseenInterval':
        return l10n.radarTrainingLabelLongUnseenInterval;
      case 'radarTrainingLabelTaskStability':
        return l10n.radarTrainingLabelTaskStability;
      case 'radarTrainingLabelSurpriseLoad':
        return l10n.radarTrainingLabelSurpriseLoad;
      case 'radarTrainingLabelStabilizedFlow':
        return l10n.radarTrainingLabelStabilizedFlow;
      case 'radarTrainingLabelFalseRecovery':
        return l10n.radarTrainingLabelFalseRecovery;
      case 'radarTrainingLabelFixationRisk':
        return l10n.radarTrainingLabelFixationRisk;
      case 'radarTrainingLabelScanNarrowing':
        return l10n.radarTrainingLabelScanNarrowing;
      case 'radarTrainingLabelConfidenceCollapse':
        return l10n.radarTrainingLabelConfidenceCollapse;
      case 'radarTrainingLabelSelfAssessmentDivergence':
        return l10n.radarTrainingLabelSelfAssessmentDivergence;
      default:
        return key;
    }
  }
}
