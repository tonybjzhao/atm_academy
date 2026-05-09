import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'debrief_insight.dart';
import 'radar_training_result.dart';

class RadarTrainingResultScreen extends StatefulWidget {
  final RadarTrainingResult result;
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

  RadarTrainingResult get result => widget.result;

  @override
  Widget build(BuildContext context) {
    final moments = result.replayMoments;
    final selectedMoment = moments.isEmpty
        ? null
        : moments[_momentIndex.clamp(0, moments.length - 1)];
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scenario Result'),
        backgroundColor: AppTheme.surface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ResultHeader(result: result),
            const SizedBox(height: 14),
            _ScoreReveal(score: result.score.score),
            const SizedBox(height: 14),
            _Metrics(result: result),
            const SizedBox(height: 18),
            const _SectionTitle('Main Debrief'),
            const SizedBox(height: 8),
            for (final insight in result.debriefSalience.primaryInsights)
              _DebriefInsightCard(insight: insight),
            if (result.debriefSalience.primaryInsights.isEmpty)
              const _ExplanationCard(
                text:
                    'Traffic flow remained stable with no major debrief item.',
              ),
            const SizedBox(height: 12),
            _MoreDetails(result: result),
            if (moments.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _SectionTitle('Replay Timeline'),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _momentIndex > 0
                        ? () => setState(() => _momentIndex--)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Prev'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Moment ${_momentIndex + 1}/${moments.length}',
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
                        ? () => setState(() => _momentIndex++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
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
                  setState(() => _momentIndex = value.round());
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
                    label: const Text('Scenario List'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onRestart,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return _Panel(
          child: Row(
            children: [
              const Text(
                'Final score',
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(label: 'Losses', value: '${result.separationLosses}'),
        _Metric(label: 'Go-arounds', value: '${result.goArounds}'),
        _Metric(label: 'Commands', value: '${result.commandCount}'),
        _Metric(
            label: 'Overload', value: '${result.overloadDuration.inSeconds}s'),
        _Metric(
            label: 'Ignored critical',
            value: '${result.ignoredCriticalAlerts}'),
        _Metric(label: 'Tunnel vision', value: '${result.tunnelVisionEvents}'),
        _Metric(
            label: 'Expectation drift',
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

  const _DebriefInsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(insight.severity);
    final timestamp =
        insight.timestamp == null ? null : 'T+${insight.timestamp!.inSeconds}s';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                          insight.title,
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
                    insight.body,
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

  const _MoreDetails({required this.result});

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
          title: const Text(
            'More details',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: const Text(
            'Advanced analysis and replay context',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          children: [
            _InsightCard(
              icon: Icons.error_outline,
              title: 'Top mistake',
              body: result.topMistake,
              accent: AppTheme.warning,
            ),
            const SizedBox(height: 8),
            _InsightCard(
              icon: Icons.healing,
              title: 'Best recovery',
              body: result.bestRecovery,
              accent: AppTheme.primary,
            ),
            if (extraInsights.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionTitle('Additional Debrief'),
              const SizedBox(height: 8),
              for (final insight in extraInsights.take(6))
                _DebriefInsightCard(insight: insight),
            ],
            const SizedBox(height: 12),
            const _SectionTitle('Timeline Summary'),
            const SizedBox(height: 8),
            for (final line in result.timelineSummary)
              _TimelineLine(text: line),
            const SizedBox(height: 12),
            const _SectionTitle('Replay Explanation'),
            const SizedBox(height: 8),
            for (final line in result.replayExplanation)
              _ExplanationCard(text: line),
            const SizedBox(height: 12),
            const _SectionTitle('Controller Evaluation'),
            const SizedBox(height: 8),
            for (final line in _advancedLines(result).take(18))
              _EvaluationChip(text: line),
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
    return _Panel(
      accent: _typeColor(moment.type),
      child: Row(
        children: [
          Icon(Icons.timeline, color: _typeColor(moment.type), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'T+${moment.elapsed.inSeconds}s  ${moment.label}',
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
