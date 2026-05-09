import '../l10n/app_localizations.dart';
import '../models/score_penalty.dart';

/// Localizes score penalty and bonus titles for display in multiple languages.
class ScoreLocalizer {
  final AppLocalizations l10n;

  const ScoreLocalizer(this.l10n);

  /// Translate a penalty title based on its content.
  String localizePenaltyTitle(String englishTitle) {
    final lower = englishTitle.toLowerCase();
    
    if (lower.contains('loss of separation')) {
      return l10n.scorePenaltyLossOfSeparation;
    } else if (lower.contains('warning zone')) {
      return l10n.scorePenaltyWarningZone;
    } else if (lower.contains('no command')) {
      return l10n.scorePenaltyNoCommand;
    } else if (lower.contains('late command')) {
      return l10n.scorePenaltyLateCommand;
    } else if (lower.contains('wrong aircraft')) {
      return l10n.scorePenaltyWrongAircraft;
    } else if (lower.contains('ineffective')) {
      return l10n.scorePenaltyIneffective;
    } else if (lower.contains('unnecessary')) {
      return l10n.scorePenaltyUnnecessary;
    }
    
    // Fallback: return original
    return englishTitle;
  }

  /// Translate a bonus title based on its content.
  String localizeBonusTitle(String englishTitle) {
    final lower = englishTitle.toLowerCase();
    
    if (lower.contains('separation maintained')) {
      return l10n.scoreBonusSeparationMaintained;
    } else if (lower.contains('correct aircraft')) {
      return l10n.scoreBonusCorrectAircraft;
    } else if (lower.contains('early')) {
      return l10n.scoreBonusEarlyAction;
    }
    
    // Fallback: return original
    return englishTitle;
  }

  /// Create localized copies of penalties with translated titles.
  List<ScorePenalty> localizePenalties(List<ScorePenalty> penalties) {
    return penalties
        .map((p) => ScorePenalty(
              timestampSeconds: p.timestampSeconds,
              type: p.type,
              pointsLost: p.pointsLost,
              title: localizePenaltyTitle(p.title),
              explanation: p.explanation,
              recommendation: p.recommendation,
            ))
        .toList();
  }

  /// Create localized copies of bonuses with translated titles.
  List<ScoreBonus> localizeBonuses(List<ScoreBonus> bonuses) {
    return bonuses
        .map((b) => ScoreBonus(
              title: localizeBonusTitle(b.title),
              pointsGained: b.pointsGained,
              explanation: b.explanation,
            ))
        .toList();
  }
}
