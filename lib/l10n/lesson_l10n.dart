import 'package:flutter/widgets.dart';
import '../core/models/lesson.dart';
import 'app_localizations.dart';

extension LessonL10n on Lesson {
  String localizedTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case 'what_is_atm':
        return l10n.whatIsAtmTitle;
      case 'airspace_basics':
        return l10n.airspaceBasicsTitle;
      case 'radar_basics':
        return l10n.radarBasicsTitle;
      case 'separation_basics':
        return l10n.separationBasicsTitle;
      case 'runway_operations':
        return l10n.runwayOperationsTitle;
      case 'atc_phraseology':
        return l10n.atcPhraseologyTitle;
      case 'flight_phases':
        return l10n.flightPhasesTitle;
      case 'conflict_awareness':
        return l10n.conflictAwarenessTitle;
      case 'tower_approach_enroute':
        return l10n.towerApproachEnrouteTitle;
      case 'future_atm':
        return l10n.futureAtmTitle;
      default:
        return title.en;
    }
  }

  String localizedSummary(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case 'what_is_atm':
        return l10n.whatIsAtmSummary;
      case 'airspace_basics':
        return l10n.airspaceBasicsSummary;
      case 'radar_basics':
        return l10n.radarBasicsSummary;
      case 'separation_basics':
        return l10n.separationBasicsSummary;
      case 'runway_operations':
        return l10n.runwayOperationsSummary;
      case 'atc_phraseology':
        return l10n.atcPhraseologySummary;
      case 'flight_phases':
        return l10n.flightPhasesSummary;
      case 'conflict_awareness':
        return l10n.conflictAwarenessSummary;
      case 'tower_approach_enroute':
        return l10n.towerApproachEnrouteSummary;
      case 'future_atm':
        return l10n.futureAtmSummary;
      default:
        return summary.en;
    }
  }

  List<String> localizedKeyPoints(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case 'what_is_atm':
        return [l10n.whatIsAtmPoint1, l10n.whatIsAtmPoint2, l10n.whatIsAtmPoint3];
      case 'airspace_basics':
        return [l10n.airspaceBasicsPoint1, l10n.airspaceBasicsPoint2, l10n.airspaceBasicsPoint3];
      case 'radar_basics':
        return [l10n.radarBasicsPoint1, l10n.radarBasicsPoint2, l10n.radarBasicsPoint3];
      case 'separation_basics':
        return [l10n.separationBasicsPoint1, l10n.separationBasicsPoint2, l10n.separationBasicsPoint3];
      case 'runway_operations':
        return [l10n.runwayOperationsPoint1, l10n.runwayOperationsPoint2, l10n.runwayOperationsPoint3];
      case 'atc_phraseology':
        return [l10n.atcPhraseologyPoint1, l10n.atcPhraseologyPoint2, l10n.atcPhraseologyPoint3];
      case 'flight_phases':
        return [l10n.flightPhasesPoint1, l10n.flightPhasesPoint2, l10n.flightPhasesPoint3];
      case 'conflict_awareness':
        return [l10n.conflictAwarenessPoint1, l10n.conflictAwarenessPoint2, l10n.conflictAwarenessPoint3];
      case 'tower_approach_enroute':
        return [l10n.towerApproachEnroutePoint1, l10n.towerApproachEnroutePoint2, l10n.towerApproachEnroutePoint3];
      case 'future_atm':
        return [l10n.futureAtmPoint1, l10n.futureAtmPoint2, l10n.futureAtmPoint3];
      default:
        return keyPoints.map((p) => p.en).toList();
    }
  }
}

String localizedQuizQuestion(BuildContext context, String lessonId, int qIndex) {
  final l10n = AppLocalizations.of(context)!;
  final q = qIndex + 1;
  switch (lessonId) {
    case 'what_is_atm':
      return q == 1
          ? l10n.whatIsAtmQ1Question
          : q == 2
              ? l10n.whatIsAtmQ2Question
              : l10n.whatIsAtmQ3Question;
    case 'airspace_basics':
      return q == 1
          ? l10n.airspaceBasicsQ1Question
          : q == 2
              ? l10n.airspaceBasicsQ2Question
              : l10n.airspaceBasicsQ3Question;
    case 'radar_basics':
      return q == 1
          ? l10n.radarBasicsQ1Question
          : q == 2
              ? l10n.radarBasicsQ2Question
              : l10n.radarBasicsQ3Question;
    case 'separation_basics':
      return q == 1
          ? l10n.separationBasicsQ1Question
          : q == 2
              ? l10n.separationBasicsQ2Question
              : l10n.separationBasicsQ3Question;
    case 'runway_operations':
      return q == 1
          ? l10n.runwayOperationsQ1Question
          : q == 2
              ? l10n.runwayOperationsQ2Question
              : l10n.runwayOperationsQ3Question;
    case 'atc_phraseology':
      return q == 1
          ? l10n.atcPhraseologyQ1Question
          : q == 2
              ? l10n.atcPhraseologyQ2Question
              : l10n.atcPhraseologyQ3Question;
    case 'flight_phases':
      return q == 1
          ? l10n.flightPhasesQ1Question
          : q == 2
              ? l10n.flightPhasesQ2Question
              : l10n.flightPhasesQ3Question;
    case 'conflict_awareness':
      return q == 1
          ? l10n.conflictAwarenessQ1Question
          : q == 2
              ? l10n.conflictAwarenessQ2Question
              : l10n.conflictAwarenessQ3Question;
    case 'tower_approach_enroute':
      return q == 1
          ? l10n.towerApproachEnrouteQ1Question
          : q == 2
              ? l10n.towerApproachEnrouteQ2Question
              : l10n.towerApproachEnrouteQ3Question;
    case 'future_atm':
      return q == 1
          ? l10n.futureAtmQ1Question
          : q == 2
              ? l10n.futureAtmQ2Question
              : l10n.futureAtmQ3Question;
    default:
      return '';
  }
}

List<String> localizedQuizOptions(BuildContext context, String lessonId, int qIndex) {
  final l10n = AppLocalizations.of(context)!;
  final q = qIndex + 1;
  switch (lessonId) {
    case 'what_is_atm':
      return q == 1
          ? [l10n.whatIsAtmQ1O0, l10n.whatIsAtmQ1O1, l10n.whatIsAtmQ1O2]
          : q == 2
              ? [l10n.whatIsAtmQ2O0, l10n.whatIsAtmQ2O1, l10n.whatIsAtmQ2O2]
              : [l10n.whatIsAtmQ3O0, l10n.whatIsAtmQ3O1, l10n.whatIsAtmQ3O2];
    case 'airspace_basics':
      return q == 1
          ? [l10n.airspaceBasicsQ1O0, l10n.airspaceBasicsQ1O1, l10n.airspaceBasicsQ1O2]
          : q == 2
              ? [l10n.airspaceBasicsQ2O0, l10n.airspaceBasicsQ2O1, l10n.airspaceBasicsQ2O2]
              : [l10n.airspaceBasicsQ3O0, l10n.airspaceBasicsQ3O1, l10n.airspaceBasicsQ3O2];
    case 'radar_basics':
      return q == 1
          ? [l10n.radarBasicsQ1O0, l10n.radarBasicsQ1O1, l10n.radarBasicsQ1O2]
          : q == 2
              ? [l10n.radarBasicsQ2O0, l10n.radarBasicsQ2O1, l10n.radarBasicsQ2O2]
              : [l10n.radarBasicsQ3O0, l10n.radarBasicsQ3O1, l10n.radarBasicsQ3O2];
    case 'separation_basics':
      return q == 1
          ? [l10n.separationBasicsQ1O0, l10n.separationBasicsQ1O1, l10n.separationBasicsQ1O2]
          : q == 2
              ? [l10n.separationBasicsQ2O0, l10n.separationBasicsQ2O1, l10n.separationBasicsQ2O2]
              : [l10n.separationBasicsQ3O0, l10n.separationBasicsQ3O1, l10n.separationBasicsQ3O2];
    case 'runway_operations':
      return q == 1
          ? [l10n.runwayOperationsQ1O0, l10n.runwayOperationsQ1O1, l10n.runwayOperationsQ1O2]
          : q == 2
              ? [l10n.runwayOperationsQ2O0, l10n.runwayOperationsQ2O1, l10n.runwayOperationsQ2O2]
              : [l10n.runwayOperationsQ3O0, l10n.runwayOperationsQ3O1, l10n.runwayOperationsQ3O2];
    case 'atc_phraseology':
      return q == 1
          ? [l10n.atcPhraseologyQ1O0, l10n.atcPhraseologyQ1O1, l10n.atcPhraseologyQ1O2]
          : q == 2
              ? [l10n.atcPhraseologyQ2O0, l10n.atcPhraseologyQ2O1, l10n.atcPhraseologyQ2O2]
              : [l10n.atcPhraseologyQ3O0, l10n.atcPhraseologyQ3O1, l10n.atcPhraseologyQ3O2];
    case 'flight_phases':
      return q == 1
          ? [l10n.flightPhasesQ1O0, l10n.flightPhasesQ1O1, l10n.flightPhasesQ1O2]
          : q == 2
              ? [l10n.flightPhasesQ2O0, l10n.flightPhasesQ2O1, l10n.flightPhasesQ2O2]
              : [l10n.flightPhasesQ3O0, l10n.flightPhasesQ3O1, l10n.flightPhasesQ3O2];
    case 'conflict_awareness':
      return q == 1
          ? [l10n.conflictAwarenessQ1O0, l10n.conflictAwarenessQ1O1, l10n.conflictAwarenessQ1O2]
          : q == 2
              ? [l10n.conflictAwarenessQ2O0, l10n.conflictAwarenessQ2O1, l10n.conflictAwarenessQ2O2]
              : [l10n.conflictAwarenessQ3O0, l10n.conflictAwarenessQ3O1, l10n.conflictAwarenessQ3O2];
    case 'tower_approach_enroute':
      return q == 1
          ? [l10n.towerApproachEnrouteQ1O0, l10n.towerApproachEnrouteQ1O1, l10n.towerApproachEnrouteQ1O2]
          : q == 2
              ? [l10n.towerApproachEnrouteQ2O0, l10n.towerApproachEnrouteQ2O1, l10n.towerApproachEnrouteQ2O2]
              : [l10n.towerApproachEnrouteQ3O0, l10n.towerApproachEnrouteQ3O1, l10n.towerApproachEnrouteQ3O2];
    case 'future_atm':
      return q == 1
          ? [l10n.futureAtmQ1O0, l10n.futureAtmQ1O1, l10n.futureAtmQ1O2]
          : q == 2
              ? [l10n.futureAtmQ2O0, l10n.futureAtmQ2O1, l10n.futureAtmQ2O2]
              : [l10n.futureAtmQ3O0, l10n.futureAtmQ3O1, l10n.futureAtmQ3O2];
    default:
      return [];
  }
}

String localizedQuizExplanation(BuildContext context, String lessonId, int qIndex) {
  final l10n = AppLocalizations.of(context)!;
  final q = qIndex + 1;
  switch (lessonId) {
    case 'what_is_atm':
      return q == 1
          ? l10n.whatIsAtmQ1Explanation
          : q == 2
              ? l10n.whatIsAtmQ2Explanation
              : l10n.whatIsAtmQ3Explanation;
    case 'airspace_basics':
      return q == 1
          ? l10n.airspaceBasicsQ1Explanation
          : q == 2
              ? l10n.airspaceBasicsQ2Explanation
              : l10n.airspaceBasicsQ3Explanation;
    case 'radar_basics':
      return q == 1
          ? l10n.radarBasicsQ1Explanation
          : q == 2
              ? l10n.radarBasicsQ2Explanation
              : l10n.radarBasicsQ3Explanation;
    case 'separation_basics':
      return q == 1
          ? l10n.separationBasicsQ1Explanation
          : q == 2
              ? l10n.separationBasicsQ2Explanation
              : l10n.separationBasicsQ3Explanation;
    case 'runway_operations':
      return q == 1
          ? l10n.runwayOperationsQ1Explanation
          : q == 2
              ? l10n.runwayOperationsQ2Explanation
              : l10n.runwayOperationsQ3Explanation;
    case 'atc_phraseology':
      return q == 1
          ? l10n.atcPhraseologyQ1Explanation
          : q == 2
              ? l10n.atcPhraseologyQ2Explanation
              : l10n.atcPhraseologyQ3Explanation;
    case 'flight_phases':
      return q == 1
          ? l10n.flightPhasesQ1Explanation
          : q == 2
              ? l10n.flightPhasesQ2Explanation
              : l10n.flightPhasesQ3Explanation;
    case 'conflict_awareness':
      return q == 1
          ? l10n.conflictAwarenessQ1Explanation
          : q == 2
              ? l10n.conflictAwarenessQ2Explanation
              : l10n.conflictAwarenessQ3Explanation;
    case 'tower_approach_enroute':
      return q == 1
          ? l10n.towerApproachEnrouteQ1Explanation
          : q == 2
              ? l10n.towerApproachEnrouteQ2Explanation
              : l10n.towerApproachEnrouteQ3Explanation;
    case 'future_atm':
      return q == 1
          ? l10n.futureAtmQ1Explanation
          : q == 2
              ? l10n.futureAtmQ2Explanation
              : l10n.futureAtmQ3Explanation;
    default:
      return '';
  }
}
