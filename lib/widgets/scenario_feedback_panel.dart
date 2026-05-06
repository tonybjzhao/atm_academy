import 'package:flutter/material.dart';
import '../core/models/scenario.dart';
import '../core/models/scenario_result.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class ScenarioFeedbackPanel extends StatelessWidget {
  final ScenarioResult result;
  final Scenario scenario;
  final String languageCode;
  final VoidCallback onRetry;
  final VoidCallback? onNext; // null if last scenario
  final VoidCallback onDone;

  const ScenarioFeedbackPanel({
    super.key,
    required this.result,
    required this.scenario,
    required this.languageCode,
    required this.onRetry,
    required this.onNext,
    required this.onDone,
  });

  Color _ratingColor() {
    switch (result.rating) {
      case ScenarioRating.excellent:        return AppTheme.primary;
      case ScenarioRating.safe:             return Colors.greenAccent;
      case ScenarioRating.needsImprovement: return AppTheme.warning;
      case ScenarioRating.unsafe:           return AppTheme.danger;
    }
  }

  IconData _ratingIcon() {
    switch (result.rating) {
      case ScenarioRating.excellent:        return Icons.stars_rounded;
      case ScenarioRating.safe:             return Icons.verified;
      case ScenarioRating.needsImprovement: return Icons.school_outlined;
      case ScenarioRating.unsafe:           return Icons.cancel_outlined;
    }
  }

  String _ratingLabel(AppLocalizations l10n) {
    switch (result.rating) {
      case ScenarioRating.excellent:        return l10n.ratingExcellent;
      case ScenarioRating.safe:             return l10n.ratingSafe;
      case ScenarioRating.needsImprovement: return l10n.ratingNeedsImprovement;
      case ScenarioRating.unsafe:           return l10n.ratingUnsafe;
    }
  }

  String _mainFeedback() {
    if (result.hadLOS) return scenario.feedback.los.of(languageCode);
    if (result.levelAtFirstCommand.index >= AlertLevel.warning.index) {
      return scenario.feedback.late.of(languageCode);
    }
    if (result.rating == ScenarioRating.excellent ||
        result.rating == ScenarioRating.safe) {
      return scenario.feedback.success.of(languageCode);
    }
    return scenario.feedback.wrong.of(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _ratingColor();

    return Container(
      color: AppTheme.background.withValues(alpha: 0.94),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_ratingIcon(), size: 68, color: color),
              const SizedBox(height: 12),
              Text(
                _ratingLabel(l10n),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.scenarioResult,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),

              const SizedBox(height: 16),
              // Score + breakdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      '${result.score} / 120',
                      style: TextStyle(
                        color: color,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _scoreRow('✓ Good commands',   '+${result.goodCommands * 5}',
                        result.goodCommands > 0 ? AppTheme.primary : AppTheme.textSecondary),
                    _scoreRow('✗ Bad commands',    '-${result.badCommands * 10}',
                        result.badCommands > 0 ? AppTheme.danger : AppTheme.textSecondary),
                    if (result.hadLOS)
                      _scoreRow('⚠ Loss of separation', '-50', AppTheme.danger),
                    if (result.resolvedInFirstHalf)
                      _scoreRow('⏱ Resolved early', '+20', AppTheme.primary),
                    if (result.separationMaintained)
                      _scoreRow('✓ Separation maintained', '+10', AppTheme.primary),
                    if (result.levelAtFirstCommand.index >= AlertLevel.warning.index)
                      _scoreRow('⚠ Late first action', '-30', AppTheme.warning),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Why feedback
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: AppTheme.secondary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          l10n.scenarioWhatHappened,
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mainFeedback(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              if (onNext != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: Text(l10n.scenarioNext),
                    onPressed: onNext,
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 15),
                  label: Text(l10n.scenarioRetry),
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onDone,
                child: Text(l10n.scenarioDone,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
