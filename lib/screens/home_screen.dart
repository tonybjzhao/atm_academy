import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/daily_challenge_state.dart';
import '../services/daily_challenge_service.dart';
import '../services/language_service.dart';
import '../widgets/control_panel_light.dart';
import 'about_safety_screen.dart';
import 'contribute_screen.dart';
import 'language_settings_screen.dart';
import 'lessons_screen.dart';
import 'radar_simulation_screen.dart';
import 'scenario_training_screen.dart';

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
        title: Text(AppLocalizations.of(context)!.homeAppBarTitle),
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
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
                      Text(
                        AppLocalizations.of(context)!.systemOnline,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.systemSubtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<DailyChallengeState>(
              valueListenable: DailyChallengeService.instance.stateNotifier,
              builder: (context, state, _) => _DailyChallengeCard(
                state: state,
                languageCode: languageCode,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.modulesSection,
              style: const TextStyle(
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
                  title: AppLocalizations.of(context)!.homeCardLearnAtm,
                  subtitle: AppLocalizations.of(context)!.homeCardLearnAtmSub,
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
                  title: AppLocalizations.of(context)!.homeCardRadarSim,
                  subtitle: AppLocalizations.of(context)!.homeCardRadarSimSub,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RadarSimulationScreen()),
                  ),
                ),
                AtmCard(
                  icon: Icons.flag_outlined,
                  iconColor: AppTheme.warning,
                  title: AppLocalizations.of(context)!.homeCardScenarioTraining,
                  subtitle: AppLocalizations.of(context)!.homeCardScenarioTrainingSub,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScenarioTrainingScreen(),
                    ),
                  ),
                ),
                AtmCard(
                  icon: Icons.quiz_outlined,
                  iconColor: Colors.purpleAccent,
                  title: AppLocalizations.of(context)!.quizTitle,
                  subtitle: AppLocalizations.of(context)!.homeCardQuizSub,
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
            _RecommendedPath(languageCode: languageCode),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BottomCard(
                    icon: Icons.people_outline,
                    color: Colors.tealAccent,
                    title: AppLocalizations.of(context)!.homeContribute,
                    subtitle: AppLocalizations.of(context)!.homeContributeSub,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ContributeScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BottomCard(
                    icon: Icons.shield_outlined,
                    color: AppTheme.warning,
                    title: AppLocalizations.of(context)!.homeAboutSafety,
                    subtitle: AppLocalizations.of(context)!.homeAboutSafetySub,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AboutSafetyScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Recommended Path ─────────────────────────────────────────────────────────

class _RecommendedPath extends StatelessWidget {
  final String languageCode;
  const _RecommendedPath({required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeRecommendedPath,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PathStep(
                  icon: Icons.school_outlined,
                  label: l10n.homePathLearn,
                  color: AppTheme.secondary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LessonsScreen(languageCode: languageCode))),
                ),
                const _PathArrow(),
                _PathStep(
                  icon: Icons.radar,
                  label: l10n.homePathRadarPractice,
                  color: AppTheme.primary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RadarSimulationScreen())),
                ),
                const _PathArrow(),
                _PathStep(
                  icon: Icons.flag_outlined,
                  label: l10n.homePathGuidedScenario,
                  color: AppTheme.warning,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ScenarioTrainingScreen())),
                ),
                const _PathArrow(),
                _PathStep(
                  icon: Icons.quiz_outlined,
                  label: l10n.homePathQuiz,
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LessonsScreen(languageCode: languageCode, quizMode: true))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PathStep({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PathArrow extends StatelessWidget {
  const _PathArrow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.borderColor),
      );
}

// ─── Bottom row cards ────────────────────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.borderColor, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Challenge card ──────────────────────────────────────────────────

class _DailyChallengeCard extends StatelessWidget {
  final DailyChallengeState state;
  final String languageCode;

  const _DailyChallengeCard({required this.state, required this.languageCode});

  String _localizedRank(BuildContext context, String rank) {
    final l10n = AppLocalizations.of(context)!;
    switch (rank) {
      case 'Mission Complete': return l10n.rankMissionComplete;
      case 'Tower Ready':      return l10n.rankTowerReady;
      case 'Controller Trainee': return l10n.rankControllerTrainee;
      default:                 return l10n.rankCadet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isComplete
              ? AppTheme.primary.withValues(alpha: 0.6)
              : AppTheme.warning.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ControlPanelLight(
                    status: state.isComplete ? LightStatus.on : LightStatus.blink,
                    color: state.isComplete ? AppTheme.primary : AppTheme.warning,
                    size: 9,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.dailyChallengeTitle,
                    style: TextStyle(
                      color: state.isComplete ? AppTheme.primary : AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  '${state.progress}/2',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.dailyChallengeSubtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          // Task rows
          _TaskRow(
            label: AppLocalizations.of(context)!.dailyChallengeTaskQuiz,
            points: '+50 pts',
            done: state.quizDone,
          ),
          const SizedBox(height: 8),
          _TaskRow(
            label: AppLocalizations.of(context)!.dailyChallengeTaskRadar,
            points: '+100 pts',
            done: state.radarDone,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.borderColor, height: 1),
          ),
          // Score + rank row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.dailyChallengeScoreLabel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${state.score}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(
                          text: ' / 200',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.of(context)!.dailyChallengeRankLabel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _localizedRank(context, state.rank),
                    style: TextStyle(
                      color: state.isComplete ? AppTheme.primary : AppTheme.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // CTA button
          SizedBox(
            width: double.infinity,
            child: state.isComplete
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: Text(AppLocalizations.of(context)!.dailyChallengeCompletedToday),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                    ),
                  )
                : !state.quizDone
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.quiz_outlined, size: 16),
                        label: Text(AppLocalizations.of(context)!.dailyChallengeStartQuiz),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LessonsScreen(
                              languageCode: languageCode,
                              quizMode: true,
                            ),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.radar, size: 16),
                        label: Text(AppLocalizations.of(context)!.dailyChallengeStartRadar),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RadarSimulationScreen(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          foregroundColor: AppTheme.background,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final String label;
  final String points;
  final bool done;

  const _TaskRow({required this.label, required this.points, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppTheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: done ? AppTheme.primary : AppTheme.borderColor,
              width: 1.5,
            ),
          ),
          child: done
              ? const Icon(Icons.check, size: 11, color: AppTheme.primary)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done ? AppTheme.textSecondary : AppTheme.textPrimary,
              fontSize: 13,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          points,
          style: TextStyle(
            color: done ? AppTheme.textSecondary : AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Module card ────────────────────────────────────────────────────────────

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
