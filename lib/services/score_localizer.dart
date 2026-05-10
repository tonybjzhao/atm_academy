import '../l10n/app_localizations.dart';
import '../models/score_penalty.dart';

/// Localizes score penalty and bonus titles for display in multiple languages.
class ScoreLocalizer {
  final AppLocalizations l10n;

  const ScoreLocalizer(this.l10n);

  String localizeScenarioTitle(String englishTitle) {
    switch (englishTitle) {
      case 'Crossing Traffic at Same Level':
        return l10n.scenarioTitleCrossingSameLevel;
      case 'Head-On Traffic — Altitude Solution':
        return l10n.scenarioTitleHeadOnAltitude;
      default:
        return englishTitle;
    }
  }

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

  String localizeSummary(String englishSummary) {
    final safeMatch = RegExp(
      r'^Good control\. (.+) maintained safe separation throughout\.$',
    ).firstMatch(englishSummary);
    if (safeMatch != null) {
      return l10n.scenarioSummaryGoodControl(safeMatch.group(1)!);
    }

    final losMatch = RegExp(
      r'^(.+) lost separation \(closest: (.+)\)\. Act earlier to prevent conflict from developing\.$',
    ).firstMatch(englishSummary);
    if (losMatch != null) {
      return l10n.scenarioSummaryLoss(losMatch.group(1)!, losMatch.group(2)!);
    }

    final warningMatch = RegExp(
      r'^(.+) entered the warning zone \((.+)\)\. Separation held, but the situation was close\.$',
    ).firstMatch(englishSummary);
    if (warningMatch != null) {
      return l10n.scenarioSummaryWarning(
        warningMatch.group(1)!,
        warningMatch.group(2)!,
      );
    }

    if (englishSummary ==
        'Conflict resolved but separation window was tight. Earlier action gives a safer margin.') {
      return l10n.scenarioSummaryTightWindow;
    }

    return englishSummary;
  }

  String localizeTip(String englishTip) {
    if (englishTip.startsWith('Issue commands earlier')) {
      return l10n.scenarioTipIssueEarlier;
    }
    if (englishTip
        .startsWith('Select the aircraft that is part of the conflict pair')) {
      return l10n.scenarioTipSelectConflictPair;
    }
    if (englishTip.startsWith('Check the projected path before commanding')) {
      return l10n.scenarioTipCheckProjectedPath;
    }
    if (englishTip.startsWith('After a loss of separation')) {
      return l10n.scenarioTipAfterLoss;
    }
    if (englishTip.startsWith('Avoid multiple rapid commands')) {
      return l10n.scenarioTipAvoidOvercontrol;
    }
    if (englishTip.startsWith('Try to resolve the conflict')) {
      return l10n.scenarioTipResolveEarlyBonus;
    }
    return englishTip;
  }

  /// Create localized copies of penalties with translated titles.
  List<ScorePenalty> localizePenalties(List<ScorePenalty> penalties) {
    return penalties
        .map((p) => ScorePenalty(
              timestampSeconds: p.timestampSeconds,
              type: p.type,
              pointsLost: p.pointsLost,
              title: localizePenaltyTitle(p.title),
              explanation: _localizePenaltyExplanation(p),
              recommendation: _localizePenaltyRecommendation(p),
            ))
        .toList();
  }

  /// Create localized copies of bonuses with translated titles.
  List<ScoreBonus> localizeBonuses(List<ScoreBonus> bonuses) {
    return bonuses
        .map((b) => ScoreBonus(
              title: localizeBonusTitle(b.title),
              pointsGained: b.pointsGained,
              explanation: _localizeBonusExplanation(b),
            ))
        .toList();
  }

  String _localizeBonusExplanation(ScoreBonus bonus) {
    final lower = bonus.title.toLowerCase();
    if (lower.contains('separation maintained')) {
      return l10n.scoreBonusSeparationMaintainedExplanation;
    }
    if (lower.contains('correct aircraft')) {
      return l10n.scoreBonusCorrectAircraftExplanation;
    }
    if (lower.contains('early')) {
      return l10n.scoreBonusEarlyActionExplanation;
    }
    return bonus.explanation;
  }

  String _localizePenaltyExplanation(ScorePenalty penalty) {
    switch (penalty.type) {
      case ScorePenaltyType.wrongAircraftSelected:
        final pair = _extractParenthesized(penalty.explanation);
        return pair == null
            ? l10n.scorePenaltyWrongAircraftExplanationGeneric
            : l10n.scorePenaltyWrongAircraftExplanation(pair);
      case ScorePenaltyType.lateVector:
        final time = _extractLateCommandTime(penalty.title) ?? '';
        return time.isEmpty
            ? penalty.explanation
            : l10n.scorePenaltyLateCommandExplanation(time);
      case ScorePenaltyType.ineffectiveCommand:
        return l10n.scorePenaltyIneffectiveExplanation;
      case ScorePenaltyType.excessiveHeadingChange:
        return l10n.scorePenaltyUnnecessaryExplanation;
      case ScorePenaltyType.noCommandIssued:
        return l10n.scorePenaltyNoCommandExplanation;
      case ScorePenaltyType.separationLoss:
      case ScorePenaltyType.conflictWarningUnresolved:
      case ScorePenaltyType.inefficientRoute:
      case ScorePenaltyType.unsafeAltitudeClearance:
        return penalty.explanation;
    }
  }

  String _localizePenaltyRecommendation(ScorePenalty penalty) {
    switch (penalty.type) {
      case ScorePenaltyType.wrongAircraftSelected:
        return l10n.scorePenaltyWrongAircraftRecommendation;
      case ScorePenaltyType.lateVector:
        return l10n.scorePenaltyLateCommandRecommendation;
      case ScorePenaltyType.ineffectiveCommand:
        return l10n.scorePenaltyIneffectiveRecommendation;
      case ScorePenaltyType.excessiveHeadingChange:
        return l10n.scorePenaltyUnnecessaryRecommendation;
      case ScorePenaltyType.noCommandIssued:
        return l10n.scorePenaltyNoCommandRecommendation;
      case ScorePenaltyType.separationLoss:
      case ScorePenaltyType.conflictWarningUnresolved:
      case ScorePenaltyType.inefficientRoute:
      case ScorePenaltyType.unsafeAltitudeClearance:
        return penalty.recommendation;
    }
  }

  String? _extractParenthesized(String text) {
    return RegExp(r'\(([^)]+)\)').firstMatch(text)?.group(1);
  }

  String? _extractLateCommandTime(String text) {
    return RegExp(r'\(([^)]+)\)').firstMatch(text)?.group(1);
  }
}
