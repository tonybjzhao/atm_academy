import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../data/lessons_data.dart';
import '../services/language_service.dart';
import '../widgets/control_panel_light.dart';
import 'about_safety_screen.dart';
import 'contribute_screen.dart';
import 'language_settings_screen.dart';
import 'lesson_detail_screen.dart';
import 'lessons_screen.dart';
import 'radar_simulation_screen.dart';

class HomeScreen extends StatelessWidget {
  final LanguageService languageService;
  final String languageCode;

  const HomeScreen({
    super.key,
    required this.languageService,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('ATM ACADEMY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutSafetyScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LanguageSettingsScreen(languageService: languageService),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ControlPanelLight(
                        status: LightStatus.blink,
                        color: AppTheme.primary,
                        size: 10,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SYSTEM ONLINE',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Air Traffic Management Learning Platform',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MODULES',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                AtmCard(
                  icon: Icons.school_outlined,
                  iconColor: AppTheme.secondary,
                  title: 'Learn ATM',
                  subtitle: '10 lessons · Beginner to Expert',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonsScreen(languageCode: languageCode),
                    ),
                  ),
                ),
                AtmCard(
                  icon: Icons.radar,
                  iconColor: AppTheme.primary,
                  title: 'Radar Sim',
                  subtitle: 'Live 2D radar simulation',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RadarSimulationScreen()),
                  ),
                ),
                AtmCard(
                  icon: Icons.flight_land_outlined,
                  iconColor: AppTheme.warning,
                  title: 'Runway Ops',
                  subtitle: 'Ground movement & sequencing',
                  onTap: () {
                    final runwayLesson = lessonsData.firstWhere(
                      (l) => l.id == 'runway_operations',
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(
                          lesson: runwayLesson,
                          languageCode: languageCode,
                        ),
                      ),
                    );
                  },
                ),
                AtmCard(
                  icon: Icons.quiz_outlined,
                  iconColor: Colors.purpleAccent,
                  title: 'Quiz',
                  subtitle: 'Test your knowledge',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonsScreen(
                        languageCode: languageCode,
                        quizMode: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Contribute full-width card
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContributeScreen()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: Colors.tealAccent, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contribute',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Built by ATM engineers — join us',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Local AtmCard widget re-used inline (same visual as widgets/atm_card.dart)
class AtmCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AtmCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
