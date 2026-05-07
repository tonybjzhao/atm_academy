import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/projected_outcome.dart';
import '../models/scenario_result.dart';
import '../models/score_penalty.dart';

/// Scrollable panel showing the complete score breakdown:
/// penalties (why points were lost) and bonuses (why points were gained),
/// followed by improvement tips.
class ScoreExplanationPanel extends StatelessWidget {
  final DetailedScenarioResult result;

  const ScoreExplanationPanel({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Score summary ─────────────────────────────────────────────────
          _ScoreHeader(result: result),
          const SizedBox(height: 14),

          // ── Why you lost points ───────────────────────────────────────────
          if (result.penalties.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.remove_circle_outline,
              color: AppTheme.danger,
              text: 'Why You Lost Points',
            ),
            const SizedBox(height: 8),
            ...result.penalties.asMap().entries.map((e) {
              final projected = e.key < result.projectedOutcomes.length
                  ? result.projectedOutcomes[e.key]
                  : null;
              return _PenaltyCard(penalty: e.value, projected: projected);
            }),
            const SizedBox(height: 12),
          ],

          // ── What you did well ─────────────────────────────────────────────
          if (result.bonuses.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.add_circle_outline,
              color: AppTheme.primary,
              text: 'What You Did Well',
            ),
            const SizedBox(height: 8),
            ...result.bonuses.map((b) => _BonusCard(bonus: b)),
            const SizedBox(height: 12),
          ],

          // ── Improvement tips ──────────────────────────────────────────────
          if (result.improvementTips.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.lightbulb_outline,
              color: AppTheme.secondary,
              text: 'How to Improve',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.improvementTips
                    .map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ',
                                  style: TextStyle(
                                      color: AppTheme.secondary, fontSize: 13)),
                              Expanded(
                                child: Text(tip,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        height: 1.5)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Score summary header ───────────────────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  final DetailedScenarioResult result;
  const _ScoreHeader({required this.result});

  Color _gradeColor() {
    switch (result.grade) {
      case ScenarioGrade.excellent:      return AppTheme.primary;
      case ScenarioGrade.good:           return Colors.greenAccent;
      case ScenarioGrade.needsPractice:  return AppTheme.warning;
      case ScenarioGrade.reviewRequired: return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              color: color.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Text(
                '${result.finalScore}',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.grade.label,
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                Text('${result.finalScore} / ${result.maxScore} pts',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(result.summaryText,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _SectionTitle({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      );
}

// ── Penalty card ───────────────────────────────────────────────────────────────

class _PenaltyCard extends StatefulWidget {
  final ScorePenalty     penalty;
  final ProjectedOutcome? projected;
  const _PenaltyCard({required this.penalty, this.projected});

  @override
  State<_PenaltyCard> createState() => _PenaltyCardState();
}

class _PenaltyCardState extends State<_PenaltyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.penalty;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '−${p.pointsLost}',
                    style: const TextStyle(
                        color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                if (p.timestampSeconds > 0)
                  Text('${p.timestampSeconds.toStringAsFixed(1)}s',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary, size: 16),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(p.explanation,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward, color: AppTheme.secondary, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(p.recommendation,
                        style: const TextStyle(
                            color: AppTheme.secondary, fontSize: 11,
                            fontStyle: FontStyle.italic, height: 1.4)),
                  ),
                ],
              ),

              // ── Better Alternative ────────────────────────────────────────
              if (widget.projected != null) ...[
                const SizedBox(height: 10),
                _BetterAlternative(outcome: widget.projected!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Better Alternative card ────────────────────────────────────────────────────

class _BetterAlternative extends StatelessWidget {
  final ProjectedOutcome outcome;
  const _BetterAlternative({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final resolved = outcome.projectedConflictResolved;
    final sepColor = resolved ? AppTheme.primary : AppTheme.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.lightbulb, color: AppTheme.primary, size: 12),
            const SizedBox(width: 5),
            const Text(
              'BETTER ALTERNATIVE',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ]),
          const SizedBox(height: 6),

          // Action label
          Text(
            outcome.alternativeAction,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

          // Explanation
          Text(
            outcome.explanation,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),

          // Projected result pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sepColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sepColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      resolved ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                      color: sepColor, size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Projected: ${outcome.projectedSeparation.toStringAsFixed(0)} px  '
                      '${resolved ? "✓ Safe" : "⚠ Still tight"}',
                      style: TextStyle(
                        color: sepColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Coaching insight
          Text(
            outcome.insightText,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 10,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bonus card ─────────────────────────────────────────────────────────────────

class _BonusCard extends StatelessWidget {
  final ScoreBonus bonus;
  const _BonusCard({required this.bonus});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '+${bonus.pointsGained}',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bonus.title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(bonus.explanation,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}
