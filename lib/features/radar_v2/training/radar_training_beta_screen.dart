import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../radar_v2_debug_screen.dart';
import 'radar_training_briefing_screen.dart';
import 'radar_training_catalog.dart';
import 'radar_training_scenario.dart';

class RadarTrainingBetaScreen extends StatelessWidget {
  const RadarTrainingBetaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Radar Training Beta'),
        backgroundColor: AppTheme.surface,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: RadarTrainingCatalog.scenarios.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final scenario = RadarTrainingCatalog.scenarios[index];
            return _ScenarioCard(
              scenario: scenario,
              onTap: () {
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
                              scenarioAssets:
                                  RadarTrainingCatalog.scenarioAssets,
                              trainingScenarioTitle: scenario.title,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final RadarTrainingScenario scenario;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
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
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
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
          ],
        ),
      ),
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
