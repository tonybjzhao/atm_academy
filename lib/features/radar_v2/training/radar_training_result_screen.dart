import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'cognitive_timeline.dart';
import 'cognitive_timeline_visualizer.dart';
import 'cognitive_cascade_propagation.dart';
import 'cognitive_cascade_propagation_view.dart';
import 'debrief_insight.dart';
import 'radar_training_result.dart';
import 'radar_training_text_localizer.dart';

class RadarTrainingResultScreen extends StatefulWidget {
  final RadarTrainingResult? result;
  final VoidCallback? onRestart;

  const RadarTrainingResultScreen({
    super.key,
    required this.result,
    this.onRestart,
  });

  @override
  State<RadarTrainingResultScreen> createState() =>
      _RadarTrainingResultScreenState();
}

class _RadarTrainingResultScreenState extends State<RadarTrainingResultScreen> {
  int _momentIndex = 0;
  Duration _selectedElapsed = Duration.zero;
  CognitiveTimelineData? _timelineData;
  CognitiveCascadePropagationData? _cascadeData;
  Object? _initError;

  RadarTrainingResult? get result => widget.result;

  @override
  void initState() {
    super.initState();
    developer.log(
      'ScenarioResultScreen received result=${widget.result != null} scenarioId=${widget.result?.scenarioId ?? 'none'} score=${widget.result?.score.score}',
      name: 'RadarTrainingResult',
    );
    final result = widget.result;
    if (result == null) {
      _initError = null;
      return;
    }
    try {
      _timelineData = const CognitiveTimelineBuilder().build(result);
      _cascadeData = const CognitiveCascadePropagationBuilder().build(result);
      _selectedElapsed = result.replayMoments.isEmpty
          ? Duration.zero
          : result.replayMoments.first.elapsed;
    } catch (e) {
      _initError = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = widget.result;
    if (result == null) {
      return _ResultFallbackScreen(localizations: l10n);
    }
    if (_initError != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(l10n.scenarioResult),
          backgroundColor: AppTheme.surface,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.danger, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    l10n.radarTrainingResultLoadFailed,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.radarTrainingResultLoadFailedHelp,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.radarTrainingDismiss),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final timelineData = _timelineData;
    final cascadeData = _cascadeData;
    final moments = result.replayMoments;
    final selectedMoment = moments.isEmpty
        ? null
        : moments[_momentIndex.clamp(0, moments.length - 1)];
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.scenarioResult),
        backgroundColor: AppTheme.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ResultHeader(result: result),
              const SizedBox(height: 14),
              _ScoreReveal(score: result.score.score),
              const SizedBox(height: 14),
              _Metrics(result: result),
              const SizedBox(height: 18),
              _SectionTitle(l10n.radarTrainingMainDebrief),
              const SizedBox(height: 8),
              for (final insight in result.debriefSalience.primaryInsights)
                _DebriefInsightCard(
                  insight: insight,
                  localizations: l10n,
                  onTap: () => _jumpToInsight(insight),
                ),
              if (result.debriefSalience.primaryInsights.isEmpty)
                _ExplanationCard(
                  text: l10n.radarTrainingStableNoMajorDebrief,
                ),
              const SizedBox(height: 12),
              _MoreDetails(
                result: result,
                localizations: l10n,
                onInsightTap: _jumpToInsight,
              ),
              const SizedBox(height: 18),
              if (cascadeData != null)
                _Panel(
                  child: CognitiveCascadePropagationView(
                    data: cascadeData,
                    selectedElapsed: _selectedElapsed,
                    localizations: l10n,
                    onJump: _jumpToElapsed,
                  ),
                ),
              if (cascadeData != null && timelineData != null)
                const SizedBox(height: 18),
              if (timelineData != null)
                _Panel(
                  child: CognitiveTimelineVisualizer(
                    data: timelineData,
                    selectedElapsed: _selectedElapsed,
                    localizations: l10n,
                    onJump: _jumpToElapsed,
                  ),
                ),
              if (moments.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionTitle(l10n.radarTrainingReplayTimeline),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _momentIndex > 0
                          ? () => _jumpToMoment(_momentIndex - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      label: Text(l10n.btnPrevious),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.radarTrainingMoment(
                            _momentIndex + 1, moments.length),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _momentIndex < moments.length - 1
                          ? () => _jumpToMoment(_momentIndex + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: Text(l10n.btnNext),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _momentIndex.toDouble(),
                  min: 0,
                  max: (moments.length - 1).toDouble(),
                  divisions: moments.length > 1 ? moments.length - 1 : null,
                  onChanged: (value) {
                    _jumpToMoment(value.round());
                  },
                ),
                if (selectedMoment != null)
                  _ReplayMomentCard(moment: selectedMoment),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      ),
                      icon: const Icon(Icons.list_alt),
                      label: Text(l10n.radarTrainingScenarioList),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onRestart,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(l10n.scenarioRetry),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _jumpToInsight(DebriefInsight insight) {
    final elapsed = insight.timestamp ?? _nearestInsightMoment(insight);
    _jumpToElapsed(elapsed ?? _selectedElapsed);
  }

  void _jumpToMoment(int index) {
    final moments = result?.replayMoments ?? const <ReplayMoment>[];
    if (moments.isEmpty) return;
    final clamped = index.clamp(0, moments.length - 1);
    setState(() {
      _momentIndex = clamped;
      _selectedElapsed = moments[clamped].elapsed;
    });
  }

  void _jumpToElapsed(Duration elapsed) {
    final max = _timelineData?.duration ?? Duration.zero;
    final clamped = elapsed < Duration.zero
        ? Duration.zero
        : elapsed > max
            ? max
            : elapsed;
    final moments = result?.replayMoments ?? const <ReplayMoment>[];
    var nearestIndex = _momentIndex;
    if (moments.isNotEmpty) {
      var bestDelta = (moments.first.elapsed - clamped).abs();
      nearestIndex = 0;
      for (var i = 1; i < moments.length; i++) {
        final delta = (moments[i].elapsed - clamped).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          nearestIndex = i;
        }
      }
    }
    setState(() {
      _selectedElapsed = clamped;
      _momentIndex = nearestIndex;
    });
  }

  Duration? _nearestInsightMoment(DebriefInsight insight) {
    final moments = result?.replayMoments.where((moment) {
          final text = '${moment.label} ${moment.type}'.toLowerCase();
          return insight.title
                  .toLowerCase()
                  .split(RegExp(r'\s+'))
                  .where((word) => word.length > 3)
                  .any(text.contains) ||
              insight.body.toLowerCase().contains(moment.type.toLowerCase());
        }) ??
        const Iterable<ReplayMoment>.empty();
    return moments.isEmpty ? null : moments.first.elapsed;
  }
}

class _ResultFallbackScreen extends StatelessWidget {
  final AppLocalizations localizations;

  const _ResultFallbackScreen({required this.localizations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(localizations.scenarioResult),
        backgroundColor: AppTheme.surface,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No result data available. Please retry scenario.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  final RadarTrainingResult result;

  const _ResultHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            result.scenarioTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          result.score.grade,
          style: TextStyle(
            color: _gradeColor(result.score.grade),
            fontSize: 46,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Color _gradeColor(String grade) {
    return switch (grade) {
      'A' => AppTheme.primary,
      'B' => Colors.greenAccent,
      'C' => AppTheme.warning,
      _ => AppTheme.danger,
    };
  }
}

class _ScoreReveal extends StatelessWidget {
  final int score;

  const _ScoreReveal({required this.score});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return _Panel(
          child: Row(
            children: [
              Text(
                l10n.radarTrainingFinalScore,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                value.round().toString(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metrics extends StatelessWidget {
  final RadarTrainingResult result;

  const _Metrics({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(
            label: l10n.radarTrainingMetricLosses,
            value: '${result.separationLosses}'),
        _Metric(
            label: l10n.radarTrainingMetricGoArounds,
            value: '${result.goArounds}'),
        _Metric(
            label: l10n.radarTrainingMetricCommands,
            value: '${result.commandCount}'),
        _Metric(
            label: l10n.radarTrainingMetricOverload,
            value: '${result.overloadDuration.inSeconds}s'),
        _Metric(
            label: l10n.radarTrainingMetricIgnoredCritical,
            value: '${result.ignoredCriticalAlerts}'),
        _Metric(
            label: l10n.radarTrainingMetricTunnelVision,
            value: '${result.tunnelVisionEvents}'),
        _Metric(
            label: l10n.radarTrainingMetricExpectationDrift,
            value: '${result.expectationDriftEvents}'),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebriefInsightCard extends StatelessWidget {
  final DebriefInsight insight;
  final AppLocalizations localizations;
  final VoidCallback? onTap;

  const _DebriefInsightCard({
    required this.insight,
    required this.localizations,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(insight.severity);
    final timestamp =
        insight.timestamp == null ? null : 'T+${insight.timestamp!.inSeconds}s';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: _Panel(
          accent: accent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_categoryIcon(insight.category), color: accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            RadarTrainingTextLocalizer.insightTitle(
                              localizations,
                              insight.title,
                            ),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            timestamp,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      RadarTrainingTextLocalizer.line(
                          localizations, insight.body),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(DebriefInsightSeverity severity) {
    return switch (severity) {
      DebriefInsightSeverity.critical => AppTheme.danger,
      DebriefInsightSeverity.high => AppTheme.warning,
      DebriefInsightSeverity.medium => AppTheme.primary,
      DebriefInsightSeverity.low => AppTheme.textSecondary,
    };
  }

  IconData _categoryIcon(DebriefInsightCategory category) {
    return switch (category) {
      DebriefInsightCategory.safety => Icons.warning_amber_rounded,
      DebriefInsightCategory.workload => Icons.speed,
      DebriefInsightCategory.attention => Icons.center_focus_strong,
      DebriefInsightCategory.workingMemory => Icons.pending_actions,
      DebriefInsightCategory.predictiveModel => Icons.query_stats,
      DebriefInsightCategory.cascade => Icons.account_tree_outlined,
      DebriefInsightCategory.metaCognition => Icons.psychology_alt,
      DebriefInsightCategory.archetype => Icons.badge_outlined,
      DebriefInsightCategory.traitScenario => Icons.tune,
      DebriefInsightCategory.recovery => Icons.healing,
      DebriefInsightCategory.flow => Icons.merge_type,
    };
  }
}

class _MoreDetails extends StatelessWidget {
  final RadarTrainingResult result;
  final AppLocalizations localizations;
  final ValueChanged<DebriefInsight> onInsightTap;

  const _MoreDetails({
    required this.result,
    required this.localizations,
    required this.onInsightTap,
  });

  @override
  Widget build(BuildContext context) {
    final extraInsights = [
      ...result.debriefSalience.secondaryInsights,
      ...result.debriefSalience.hiddenInsights,
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: _Panel(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          iconColor: AppTheme.primary,
          collapsedIconColor: AppTheme.textSecondary,
          title: Text(
            localizations.radarTrainingMoreDetails,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            localizations.radarTrainingAdvancedAnalysisReplayContext,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          children: [
            _InsightCard(
              icon: Icons.error_outline,
              title: localizations.radarTrainingTopMistake,
              body: RadarTrainingTextLocalizer.line(
                  localizations, result.topMistake),
              accent: AppTheme.warning,
            ),
            const SizedBox(height: 8),
            _InsightCard(
              icon: Icons.healing,
              title: localizations.radarTrainingBestRecovery,
              body: RadarTrainingTextLocalizer.line(
                  localizations, result.bestRecovery),
              accent: AppTheme.primary,
            ),
            if (extraInsights.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionTitle(localizations.radarTrainingAdditionalDebrief),
              const SizedBox(height: 8),
              for (final insight in extraInsights.take(6))
                _DebriefInsightCard(
                  insight: insight,
                  localizations: localizations,
                  onTap: () => onInsightTap(insight),
                ),
            ],
            if (result.environmentalEcology.reportLines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionTitle(
                  localizations.radarTrainingOperationalPressureEcology),
              const SizedBox(height: 8),
              for (final line in result.environmentalEcology.reportLines)
                _EvaluationChip(
                  text: RadarTrainingTextLocalizer.line(localizations, line),
                ),
            ],
            const SizedBox(height: 12),
            _SectionTitle(localizations.radarTrainingTimelineSummary),
            const SizedBox(height: 8),
            for (final line in result.timelineSummary)
              _TimelineLine(
                text: RadarTrainingTextLocalizer.line(localizations, line),
              ),
            const SizedBox(height: 12),
            _SectionTitle(localizations.radarTrainingReplayExplanation),
            const SizedBox(height: 8),
            for (final line in result.replayExplanation)
              _ExplanationCard(
                text: RadarTrainingTextLocalizer.line(localizations, line),
              ),
            const SizedBox(height: 12),
            _SectionTitle(localizations.radarTrainingControllerEvaluation),
            const SizedBox(height: 8),
            for (final line in _advancedLines(result).take(18))
              _EvaluationChip(
                text: RadarTrainingTextLocalizer.line(localizations, line),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _advancedLines(RadarTrainingResult result) {
    return [
      ...result.controllerEvaluation,
      ...result.commandTimingQuality,
      ...result.hesitationWindows,
      ...result.lateVectorRecognition,
      ...result.neglectedAircraft,
      ...result.scanBlindPeriods,
      ...result.fixationWindows,
      ...result.delayedAwarenessMoments,
      ...result.forgottenIntentions,
      ...result.interruptedWorkflows,
      ...result.delayedFollowThrough,
      ...result.intentionRecovery,
      ...result.expectationMismatches,
      ...result.lateAbnormalRecognition,
      ...result.surpriseOverloadMoments,
      ...result.assumptionDrivenErrors,
      ...result.cognitiveCascadeChains,
      ...result.rootSurpriseEvent,
      ...result.secondaryFailuresCaused,
      ...result.recoveryQuality,
      ...result.inaccurateSelfAssessmentMoments,
      ...result.unnoticedOverload,
      ...result.successfulSelfRecovery,
      ...result.confidenceCalibrationQuality,
      ...result.archetypeDebrief,
      ...result.traitScenarioInteraction,
      ...result.environmentalEcology.reportLines,
    ];
  }
}

class _ExplanationCard extends StatelessWidget {
  final String text;

  const _ExplanationCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.insights, color: AppTheme.primary, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationChip extends StatelessWidget {
  final String text;

  const _EvaluationChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: Row(
          children: [
            const Icon(Icons.rule_folder_outlined,
                color: AppTheme.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayMomentCard extends StatelessWidget {
  final ReplayMoment moment;

  const _ReplayMomentCard({required this.moment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Panel(
      accent: _typeColor(moment.type),
      child: Row(
        children: [
          Icon(Icons.timeline, color: _typeColor(moment.type), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.radarTrainingMomentLabel(
                moment.elapsed.inSeconds,
                RadarTrainingTextLocalizer.line(l10n, moment.label),
              ),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    if (type == 'overload') return AppTheme.warning;
    if (type == 'separationWarning' || type == 'separationLoss') {
      return AppTheme.danger;
    }
    return AppTheme.primary;
  }
}

class _TimelineLine extends StatelessWidget {
  final String text;

  const _TimelineLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _Panel({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091827),
        border: Border.all(
            color: accent?.withValues(alpha: 0.55) ?? AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1600B0FF), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}
