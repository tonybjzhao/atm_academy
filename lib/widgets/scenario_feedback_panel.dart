import 'package:flutter/material.dart';
import '../core/models/scenario.dart';
import '../core/models/scenario_result.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/replay_data.dart';
import '../models/scenario_result.dart' as detailed;
import '../screens/scenario_result_screen.dart';
import '../screens/unity_replay_screen.dart';

class ScenarioFeedbackPanel extends StatelessWidget {
  final ScenarioResult result;
  final Scenario scenario;
  final String languageCode;
  final ScenarioReplayData? replayData;
  final detailed.DetailedScenarioResult? detailedResult;
  final int? scoreDelta; // positive = improved vs last attempt
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final VoidCallback onDone;

  const ScenarioFeedbackPanel({
    super.key,
    required this.result,
    required this.scenario,
    required this.languageCode,
    required this.replayData,
    this.detailedResult,
    this.scoreDelta,
    required this.onRetry,
    required this.onNext,
    required this.onDone,
  });

  Color _ratingColor() {
    switch (result.rating) {
      case ScenarioRating.excellent:
        return AppTheme.primary;
      case ScenarioRating.safe:
        return Colors.greenAccent;
      case ScenarioRating.needsImprovement:
        return AppTheme.warning;
      case ScenarioRating.unsafe:
        return AppTheme.danger;
    }
  }

  IconData _ratingIcon() {
    switch (result.rating) {
      case ScenarioRating.excellent:
        return Icons.stars_rounded;
      case ScenarioRating.safe:
        return Icons.verified;
      case ScenarioRating.needsImprovement:
        return Icons.school_outlined;
      case ScenarioRating.unsafe:
        return Icons.cancel_outlined;
    }
  }

  String _ratingLabel(AppLocalizations l10n) {
    switch (result.rating) {
      case ScenarioRating.excellent:
        return l10n.ratingExcellent;
      case ScenarioRating.safe:
        return l10n.ratingSafe;
      case ScenarioRating.needsImprovement:
        return l10n.ratingNeedsImprovement;
      case ScenarioRating.unsafe:
        return l10n.ratingUnsafe;
    }
  }

  String _localizedWhatHappened(AppLocalizations l10n) {
    final pairStr = result.conflictPair.join(' & ');
    final sepStr = '${result.minHorizontalDistancePx.toStringAsFixed(0)} px';
    final vertStr = '${result.minVerticalDistanceFt} ft';

    final parts = <String>[];
    if (result.hadLOS) {
      parts.add(l10n.scenarioWhatHappenedLoss(pairStr, sepStr, vertStr));
    } else if (result.warningReached) {
      parts.add(l10n.scenarioWhatHappenedWarning(pairStr, sepStr, vertStr));
    } else {
      parts.add(l10n.scenarioWhatHappenedSafe(sepStr, vertStr));
    }

    if (result.reactionTimeSec <= 0) {
      parts.add(l10n.scenarioWhatHappenedNoCommand);
    } else {
      parts.add(
          l10n.scenarioWhatHappenedFirstCommand(result.reactionTimeSec.toStringAsFixed(1)));
      if (result.goodCommands > 0) {
        parts.add(l10n.scenarioWhatHappenedEffectiveCommands(result.goodCommands));
      }
      if (result.badCommands > 0) {
        parts.add(l10n.scenarioWhatHappenedIneffectiveCommands(result.badCommands));
      }
    }
    return parts.join(' ');
  }

  List<String> _localizedPenalties(AppLocalizations l10n) {
    final lines = <String>[];
    if (result.hadLOS) {
      lines.add('${l10n.scorePenaltyLossOfSeparation}: -60');
    } else if (result.warningReached) {
      lines.add('${l10n.scorePenaltyWarningZone}: -25');
    }

    if (result.reactionTimeSec <= 0) {
      lines.add('${l10n.scorePenaltyNoCommand}: -30');
    } else {
      if (result.reactionTimeSec > 12) {
        lines.add('${l10n.scenarioPenaltyLateCommand(result.reactionTimeSec.toStringAsFixed(0))}: -20');
      } else if (result.reactionTimeSec > 8) {
        lines.add('${l10n.scenarioPenaltyLateCommand(result.reactionTimeSec.toStringAsFixed(0))}: -10');
      }
      if (!result.selectedAircraftCorrect) {
        lines.add('${l10n.scorePenaltyWrongAircraft}: -20');
      }
    }

    if (result.badCommands > 0) {
      lines.add('${l10n.scorePenaltyIneffective}: -${result.badCommands * 25}');
    }
    final overControl = result.neutralCommands > 1 ? result.neutralCommands - 1 : 0;
    if (overControl > 0) {
      lines.add('${l10n.scorePenaltyUnnecessary}: -${overControl * 10}');
    }

    return lines.isEmpty ? <String>[l10n.scenarioNoPenalties] : lines;
  }

  List<String> _localizedBonuses(AppLocalizations l10n) {
    final lines = <String>[];
    if (result.separationMaintained) {
      lines.add('${l10n.scoreBonusSeparationMaintained}: +10');
    }
    if (result.reactionTimeSec > 0 && result.selectedAircraftCorrect) {
      lines.add('${l10n.scoreBonusCorrectAircraft}: +10');
    }
    if (result.reactionTimeSec > 0 && result.goodCommands > 0 && result.reactionTimeSec < 5) {
      lines.add('${l10n.scoreBonusEarlyAction}: +10');
    }
    return lines.isEmpty ? <String>[l10n.scenarioNoBonuses] : lines;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _ratingColor();
    final localizedPenalties = _localizedPenalties(l10n);
    final localizedBonuses = _localizedBonuses(l10n);

    return Container(
      color: AppTheme.background.withValues(alpha: 0.94),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
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
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),

              const SizedBox(height: 16),

              // ── Score ─────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${result.score}',
                      style: TextStyle(
                          color: color,
                          fontSize: 42,
                          fontWeight: FontWeight.w900),
                    ),
                    Text(
                      ' / 120',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 20),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            (result.hadLOS ? AppTheme.danger : AppTheme.primary)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (result.hadLOS
                                  ? AppTheme.danger
                                  : AppTheme.primary)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        result.hadLOS
                            ? l10n.scenarioLOSResult
                            : l10n.scenarioSafeResult,
                        style: TextStyle(
                          color: result.hadLOS
                              ? AppTheme.danger
                              : AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Conflict metrics ──────────────────────────────────────────
              // ── Improvement banner ─────────────────────────────────────────
              if (scoreDelta != null) _ImprovementBanner(delta: scoreDelta!),
              if (scoreDelta != null) const SizedBox(height: 10),

              Container(
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
                    _metricRow(
                        l10n.scenarioConflictPair,
                        result.conflictPair.join(' & '),
                        result.hadLOS ? AppTheme.danger : AppTheme.warning),
                    _metricRow(
                        l10n.scenarioMinHorizSep,
                        '${result.minHorizontalDistancePx.toStringAsFixed(0)} px '
                        '(${l10n.scenarioThresholdPx(60)})',
                        result.hadLOS ? AppTheme.danger : AppTheme.primary),
                    _metricRow(
                        l10n.scenarioMinVertSep,
                        '${result.minVerticalDistanceFt} ft '
                        '(${l10n.scenarioThresholdFt(1000)})',
                        result.hadLOS ? AppTheme.danger : AppTheme.primary),
                    _metricRow(
                        l10n.scenarioReactionTime,
                        result.reactionTimeSec == 0
                            ? l10n.scenarioNoCommandIssued
                            : '${result.reactionTimeSec.toStringAsFixed(1)} s',
                        result.reactionTimeSec > 8
                            ? AppTheme.warning
                            : AppTheme.textSecondary),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── What happened ─────────────────────────────────────────────
              _Section(
                icon: Icons.info_outline,
                color: AppTheme.secondary,
                title: l10n.scenarioWhatHappened,
                child: Text(
                  _localizedWhatHappened(l10n),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.55),
                ),
              ),

              const SizedBox(height: 12),

              // ── Penalty breakdown ─────────────────────────────────────────
              _Section(
                icon: Icons.remove_circle_outline,
                color: AppTheme.danger,
                title: l10n.scenarioPenalties,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: localizedPenalties
                      .map((s) => _breakdownLine(s, AppTheme.danger))
                      .toList(),
                ),
              ),

              const SizedBox(height: 12),

              // ── Bonus breakdown ───────────────────────────────────────────
              _Section(
                icon: Icons.add_circle_outline,
                color: AppTheme.primary,
                title: l10n.scenarioBonuses,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: localizedBonuses
                      .map((s) => _breakdownLine(s, AppTheme.primary))
                      .toList(),
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
              // Full Debrief — animated replay + detailed explanation
              if (detailedResult != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics_outlined, size: 15),
                    label: Text(l10n.scenarioViewFullDebrief),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScenarioResultScreen(
                          result: detailedResult!,
                          onRetry: onRetry,
                          onNextScenario: onNext,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: AppTheme.background,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              // 3D Replay button (shows placeholder until Unity is integrated)
              if (replayData != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.view_in_ar_outlined, size: 15),
                    label: Text(l10n.watchReplay3d),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UnityReplayScreen(replayData: replayData!),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: BorderSide(
                          color: AppTheme.secondary.withValues(alpha: 0.5)),
                    ),
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
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, Color valueColor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11))),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _breakdownLine(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(color: color, fontSize: 11)),
            Expanded(
                child: Text(text,
                    style: TextStyle(color: color, fontSize: 11, height: 1.4))),
          ],
        ),
      );
}

// ── Improvement banner ─────────────────────────────────────────────────────────

class _ImprovementBanner extends StatelessWidget {
  final int delta; // positive = better, negative = worse

  const _ImprovementBanner({required this.delta});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final improved = delta > 0;
    final same = delta == 0;
    final color = improved
        ? AppTheme.primary
        : same
            ? AppTheme.textSecondary
            : AppTheme.danger;
    final icon = improved
        ? Icons.trending_up
        : same
            ? Icons.trending_flat
            : Icons.trending_down;
    final text = improved
        ? l10n.scenarioImprovedVsLastAttempt(delta)
        : same
            ? l10n.scenarioSameScoreAsLastAttempt
            : l10n.scenarioLowerThanLastAttempt(-delta);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section widget ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}
