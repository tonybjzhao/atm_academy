import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../radar_v2_debug_screen.dart';
import 'radar_training_briefing_screen.dart';
import 'radar_training_catalog.dart';
import 'radar_training_progress_store.dart';
import 'radar_training_scenario.dart';

class RadarTrainingBetaScreen extends StatefulWidget {
  const RadarTrainingBetaScreen({super.key});

  @override
  State<RadarTrainingBetaScreen> createState() =>
      _RadarTrainingBetaScreenState();
}

class _RadarTrainingBetaScreenState extends State<RadarTrainingBetaScreen> {
  final RadarTrainingProgressStore _progressStore =
      const RadarTrainingProgressStore();
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    final show = await _progressStore.shouldShowOnboarding();
    if (mounted) setState(() => _showOnboarding = show);
  }

  Future<void> _dismissOnboarding() async {
    await _progressStore.markOnboardingSeen();
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Radar Training Beta'),
        backgroundColor: AppTheme.surface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_showOnboarding) ...[
              _OnboardingCard(onDismiss: _dismissOnboarding),
              const SizedBox(height: 14),
            ],
            for (final scenario in RadarTrainingCatalog.scenarios) ...[
              _ProgressScenarioCard(
                scenario: scenario,
                progressStore: _progressStore,
                onTap: () => _openBriefing(context, scenario),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _openBriefing(BuildContext context, RadarTrainingScenario scenario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadarTrainingBriefingScreen(
          scenario: scenario,
          onStart: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => RadarV2DebugScreen(
                  betaMode: true,
                  initialScenarioName: scenario.scenarioName,
                  scenarioAssets: RadarTrainingCatalog.scenarioAssets,
                  trainingScenarioTitle: scenario.title,
                  trainingScenarioId: scenario.id,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressScenarioCard extends StatelessWidget {
  final RadarTrainingScenario scenario;
  final RadarTrainingProgressStore progressStore;
  final VoidCallback onTap;

  const _ProgressScenarioCard({
    required this.scenario,
    required this.progressStore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RadarTrainingProgress>(
      future: progressStore.load(scenario.id),
      builder: (context, snapshot) {
        return _ScenarioCard(
          scenario: scenario,
          progress: snapshot.data ?? const RadarTrainingProgress(),
          onTap: onTap,
        );
      },
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final VoidCallback onDismiss;

  const _OnboardingCard({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF081823),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x6646F5A7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2200E676),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'This simulator trains',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'Workload management'),
              _Chip(label: 'Situational awareness'),
              _Chip(label: 'Attention control'),
              _Chip(label: 'Anticipation'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final RadarTrainingScenario scenario;
  final RadarTrainingProgress progress;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF091827),
          border: Border.all(
            color: progress.completedCount > 0
                ? const Color(0x6646F5A7)
                : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1800B0FF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scenario.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(label: scenario.difficultyLabel),
                _Chip(label: scenario.estimatedTimeLabel),
                _Chip(
                    label: 'Best ${progress.bestGrade} ${progress.bestScore}'),
                _Stars(value: progress.stars),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              scenario.learningGoal,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (progress.completedCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Completed ${progress.completedCount} time(s)',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int value;

  const _Stars({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++)
          Icon(
            i <= value ? Icons.star : Icons.star_border,
            color: AppTheme.warning,
            size: 15,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B28),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
