import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'radar_training_result.dart';

class RadarTrainingResultScreen extends StatelessWidget {
  final RadarTrainingResult result;
  final VoidCallback? onRestart;

  const RadarTrainingResultScreen({
    super.key,
    required this.result,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
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
            Row(
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
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ScoreBand(score: result.score.score),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: 'Losses', value: '${result.separationLosses}'),
                _Metric(label: 'Go-arounds', value: '${result.goArounds}'),
                _Metric(label: 'Commands', value: '${result.commandCount}'),
                _Metric(
                  label: 'Overload',
                  value: '${result.overloadDuration.inSeconds}s',
                ),
                _Metric(
                  label: 'Ignored critical',
                  value: '${result.ignoredCriticalAlerts}',
                ),
                _Metric(
                  label: 'Tunnel vision',
                  value: '${result.tunnelVisionEvents}',
                ),
                _Metric(
                  label: 'Expectation drift',
                  value: '${result.expectationDriftEvents}',
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Replay Explanation',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final line in result.replayExplanation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.insights,
                      color: AppTheme.primary,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
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
                    onPressed: onRestart,
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

  Color _gradeColor(String grade) {
    return switch (grade) {
      'A' => AppTheme.primary,
      'B' => Colors.greenAccent,
      'C' => AppTheme.warning,
      _ => AppTheme.danger,
    };
  }
}

class _ScoreBand extends StatelessWidget {
  final int score;

  const _ScoreBand({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text(
            'Final score',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '$score',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
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
    );
  }
}
