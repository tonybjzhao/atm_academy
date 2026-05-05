import 'package:flutter/material.dart';
import '../core/models/lesson.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/comms_pulse_animation.dart';
import '../widgets/radar_sweep_animation.dart';
import '../widgets/runway_flow_animation.dart';
import '../widgets/separation_demo_animation.dart';
import 'quiz_screen.dart';

class LessonDetailScreen extends StatelessWidget {
  final Lesson lesson;
  final String languageCode;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    required this.languageCode,
  });

  Color _levelColor(LessonLevel level) {
    switch (level) {
      case LessonLevel.beginner:
        return Colors.green;
      case LessonLevel.intermediate:
        return Colors.blue;
      case LessonLevel.advanced:
        return Colors.orange;
      case LessonLevel.expert:
        return Colors.red;
    }
  }

  String _levelLabel(LessonLevel level, AppLocalizations l10n) {
    switch (level) {
      case LessonLevel.beginner:
        return l10n.levelBeginner.toUpperCase();
      case LessonLevel.intermediate:
        return l10n.levelIntermediate.toUpperCase();
      case LessonLevel.advanced:
        return l10n.levelAdvanced.toUpperCase();
      case LessonLevel.expert:
        return l10n.levelExpert.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(lesson.level);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lesson.title.of(languageCode)),
        backgroundColor: AppTheme.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animation header
            if (lesson.animationType != AnimationType.none)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Center(
                  child: _buildAnimation(),
                ),
              ),
            if (lesson.animationType != AnimationType.none) const SizedBox(height: 16),
            // Level badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: levelColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _levelLabel(lesson.level, AppLocalizations.of(context)!),
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lesson.summary.of(languageCode),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.keyPointsSection,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...lesson.keyPoints.map((keyPoint) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: AppTheme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chevron_right, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              keyPoint.of(languageCode),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.quiz_outlined),
                label: Text(AppLocalizations.of(context)!.startQuiz),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      lesson: lesson,
                      languageCode: languageCode,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    switch (lesson.animationType) {
      case AnimationType.radarSweep:
        return const RadarSweepAnimation(size: 160);
      case AnimationType.runwayFlow:
        return const RunwayFlowAnimation(width: 300, height: 100);
      case AnimationType.separationDemo:
        return const SeparationDemoAnimation(size: 220);
      case AnimationType.commsPulse:
        return const CommsPulseAnimation(size: 140);
      case AnimationType.none:
        return const SizedBox.shrink();
    }
  }
}
