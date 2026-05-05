import 'package:flutter/material.dart';
import '../data/atm_course_catalog.dart';
import '../l10n/l10n_extensions.dart';
import '../l10n/l10n_key_resolver.dart';
import '../models/atm_lesson.dart';
import '../services/language_service.dart';
import 'atm_lesson_detail_screen.dart';
import 'language_settings_screen.dart';

class AtmCourseHomeScreen extends StatelessWidget {
  final LanguageService languageService;

  const AtmCourseHomeScreen({super.key, required this.languageService});

  Color _levelColor(AtmLevel level, BuildContext context) {
    switch (level) {
      case AtmLevel.beginner:
        return Colors.green;
      case AtmLevel.intermediate:
        return Colors.blue;
      case AtmLevel.advanced:
        return Colors.orange;
      case AtmLevel.expert:
        return Colors.red;
    }
  }

  String _levelLabel(AtmLevel level, BuildContext context) {
    switch (level) {
      case AtmLevel.beginner:
        return context.l10n.levelBeginner;
      case AtmLevel.intermediate:
        return context.l10n.levelIntermediate;
      case AtmLevel.advanced:
        return context.l10n.levelAdvanced;
      case AtmLevel.expert:
        return context.l10n.levelExpert;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group lessons by level
    final grouped = <AtmLevel, List<AtmLesson>>{};
    for (final lesson in atmCourseCatalog) {
      grouped.putIfAbsent(lesson.level, () => []).add(lesson);
    }
    const levels = AtmLevel.values;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.courseHomeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: context.l10n.languageScreenTitle,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguageSettingsScreen(
                    languageService: languageService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final level in levels)
            if (grouped.containsKey(level)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _levelColor(level, context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _levelLabel(level, context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final lesson in grouped[level]!)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _levelColor(lesson.level, context).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.flight,
                        color: _levelColor(lesson.level, context),
                      ),
                    ),
                    title: Text(resolveKey(context, lesson.titleKey)),
                    subtitle: Text(
                      resolveKey(context, lesson.summaryKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AtmLessonDetailScreen(lesson: lesson),
                        ),
                      );
                    },
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
