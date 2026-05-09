import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
            _InsightCard(
              icon: Icons.error_outline,
              title: 'Top mistake',
              body: result.topMistake,
              accent: AppTheme.warning,
            ),
            const SizedBox(height: 10),
            _InsightCard(
              icon: Icons.healing,
              title: 'Best recovery',
              body: result.bestRecovery,
              accent: AppTheme.primary,
            ),
            const SizedBox(height: 18),
            const _SectionTitle('Timeline Summary'),
            const SizedBox(height: 8),
            for (final line in result.timelineSummary)
              _TimelineLine(text: line),
            const SizedBox(height: 18),
            const _SectionTitle('Replay Explanation'),
            const SizedBox(height: 8),
            for (final line in result.replayExplanation)
              _ExplanationCard(text: line),
            if (moments.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _SectionTitle('Replay Timeline'),
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
