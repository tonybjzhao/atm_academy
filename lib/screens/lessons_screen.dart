import 'package:flutter/material.dart';
import '../core/models/lesson.dart';
import '../core/theme/app_theme.dart';
import '../data/lessons_data.dart';
import '../l10n/app_localizations.dart';
import '../l10n/lesson_l10n.dart';
import 'lesson_detail_screen.dart';
import 'quiz_screen.dart';

class LessonsScreen extends StatelessWidget {
  final String languageCode;
  final bool quizMode;

  const LessonsScreen({
    super.key,
    required this.languageCode,
    this.quizMode = false,
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

  IconData _animTypeIcon(AnimationType type) {
    switch (type) {
      case AnimationType.radarSweep:
        return Icons.radar;
      case AnimationType.runwayFlow:
        return Icons.flight_land;
      case AnimationType.separationDemo:
        return Icons.warning_amber;
      case AnimationType.commsPulse:
        return Icons.wifi;
      case AnimationType.none:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(quizMode ? AppLocalizations.of(context)!.lessonsSelectTitle : AppLocalizations.of(context)!.lessonsTitle),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: EdgeInsets.only(
          top: 8, bottom: MediaQuery.of(context).padding.bottom + 24),
        children: LessonLevel.values.expand((level) {
          final levelLessons = lessonsData.where((l) => l.level == level).toList();
          if (levelLessons.isEmpty) return <Widget>[];
          final color = _levelColor(level);
          return [
            // Level header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _levelLabel(level, AppLocalizations.of(context)!),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Lessons for this level
            ...levelLessons.map((lesson) {
              final levelColor = _levelColor(lesson.level);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Card(
                  color: AppTheme.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: levelColor.withValues(alpha: 0.15),
                      child: Icon(
                        _animTypeIcon(lesson.animationType),
                        color: levelColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      lesson.localizedTitle(context),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      lesson.localizedSummary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    onTap: () {
                      if (quizMode) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              lesson: lesson,
                              languageCode: languageCode,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LessonDetailScreen(
                              lesson: lesson,
                              languageCode: languageCode,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            }),
          ];
        }).toList(),
      ),
      ), // SafeArea
    );
  }
}
