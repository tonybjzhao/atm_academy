import '../../../l10n/app_localizations.dart';
import 'radar_training_scenario.dart';

class RadarTrainingCatalog {
  static const List<RadarTrainingScenario> scenarios = [
    RadarTrainingScenario(
      id: 'beginner_crossing_conflict',
      title: 'Beginner Crossing Conflict',
      difficulty: RadarTrainingDifficulty.cadet,
      estimatedTime: Duration(minutes: 4),
      learningGoal: 'Basic heading and speed commands',
      objective:
          'Resolve a same-level crossing conflict before it becomes urgent.',
      trafficSituation:
          'Two arrivals converge near the centre of the sector with a lower third aircraft entering later.',
      expectedTechnique:
          'Issue an early heading vector, then use speed only if the closure rate remains high.',
      riskFactors: [
        'Late turns create a short time-to-loss window',
        'The lower arrival can draw attention away from the real conflict',
        'Unnecessary altitude changes reduce command efficiency',
      ],
      successCriteria: [
        'No separation loss',
        'Resolve the first conflict before the urgent phase',
        'Keep commands precise and minimal',
      ],
      assetPath: 'assets/scenarios/v2/melbourne/crossing_arrivals.json',
      scenarioName: 'Crossing Arrivals',
    ),
    RadarTrainingScenario(
      id: 'melbourne_storm_arrival_rush',
      title: 'Melbourne Storm Arrival Rush',
      difficulty: RadarTrainingDifficulty.supervisor,
      estimatedTime: Duration(minutes: 6),
      learningGoal:
          'Arrival compression, weather pressure, runway timing, and attention control',
      objective:
          'Manage arrival compression, weather deviation, runway pressure, and attention traps without losing situational awareness.',
      trafficSituation:
          'A calm Melbourne arrival stream compresses as storm cells force reroutes, a departure creates runway pressure, and a quiet conflict develops away from the salient aircraft.',
      expectedTechnique:
          'Use early speed control, vector weather-affected traffic decisively, then return to a broad scan before the overload window.',
      riskFactors: [
        'Storm cells narrow vector options and compress final spacing',
        'QFA214 can pull attention away from the quieter crossing threat',
        'Runway occupancy and departure timing reduce recovery margin',
        'Several weak stressors align near the overload window',
      ],
      successCriteria: [
        'No separation loss',
        'Maintain final approach spacing through the storm reroute',
        'Avoid weather penetration and ignored critical alerts',
        'Recover the sector after the overload moment',
      ],
      assetPath: 'assets/scenarios/v2/melbourne/storm_arrival_rush.json',
      scenarioName: 'Melbourne Storm Arrival Rush',
    ),
    RadarTrainingScenario(
      id: 'false_recovery_tunnel_vision',
      title: 'False Recovery / Tunnel Vision',
      difficulty: RadarTrainingDifficulty.supervisor,
      estimatedTime: Duration(minutes: 5),
      learningGoal: 'Mental model drift and attention management',
      objective:
          'Recognize false recovery and keep scanning while pressure appears to ease.',
      trafficSituation:
          'Weather deviation and delayed arrivals create a quiet period before spacing compresses again.',
      expectedTechnique:
          'Keep a broad scan, protect runway flow, and avoid over-focusing on the first conflict.',
      riskFactors: [
        'False stability reduces perceived threat',
        'Low-priority distractions compete with emerging conflicts',
        'Runway and merge pressure can recover visually before it is actually safe',
      ],
      successCriteria: [
        'Respond before expectation drift becomes critical',
        'Avoid ignored critical alerts',
        'Complete with no separation loss',
      ],
      assetPath:
          'assets/scenarios/v2/melbourne/false_recovery_tunnel_vision.json',
      scenarioName: 'False Recovery',
    ),
  ];

  static RadarTrainingScenario byId(String id) {
    return scenarios.firstWhere((scenario) => scenario.id == id);
  }

  static RadarTrainingScenario byIdLocalized(
    String id,
    AppLocalizations l10n,
  ) {
    return _localizedScenario(byId(id), l10n);
  }

  static List<RadarTrainingScenario> localizedScenarios(AppLocalizations l10n) {
    return scenarios.map((scenario) => _localizedScenario(scenario, l10n)).toList();
  }

  static Map<String, String> get scenarioAssets => {
        for (final scenario in scenarios)
          scenario.scenarioName: scenario.assetPath,
      };

  static RadarTrainingScenario _localizedScenario(
    RadarTrainingScenario scenario,
    AppLocalizations l10n,
  ) {
    switch (scenario.id) {
      case 'beginner_crossing_conflict':
        return RadarTrainingScenario(
          id: scenario.id,
          title: l10n.radarTrainingScenarioBeginnerTitle,
          difficulty: scenario.difficulty,
          estimatedTime: scenario.estimatedTime,
          learningGoal: l10n.radarTrainingScenarioBeginnerLearningGoal,
          objective: l10n.radarTrainingScenarioBeginnerObjective,
          trafficSituation: l10n.radarTrainingScenarioBeginnerTraffic,
          expectedTechnique: l10n.radarTrainingScenarioBeginnerTechnique,
          riskFactors: [
            l10n.radarTrainingScenarioBeginnerRisk1,
            l10n.radarTrainingScenarioBeginnerRisk2,
            l10n.radarTrainingScenarioBeginnerRisk3,
          ],
          successCriteria: [
            l10n.radarTrainingScenarioBeginnerSuccess1,
            l10n.radarTrainingScenarioBeginnerSuccess2,
            l10n.radarTrainingScenarioBeginnerSuccess3,
          ],
          assetPath: scenario.assetPath,
          scenarioName: scenario.scenarioName,
        );
      case 'melbourne_storm_arrival_rush':
        return RadarTrainingScenario(
          id: scenario.id,
          title: l10n.radarTrainingScenarioStormTitle,
          difficulty: scenario.difficulty,
          estimatedTime: scenario.estimatedTime,
          learningGoal: l10n.radarTrainingScenarioStormLearningGoal,
          objective: l10n.radarTrainingScenarioStormObjective,
          trafficSituation: l10n.radarTrainingScenarioStormTraffic,
          expectedTechnique: l10n.radarTrainingScenarioStormTechnique,
          riskFactors: [
            l10n.radarTrainingScenarioStormRisk1,
            l10n.radarTrainingScenarioStormRisk2,
            l10n.radarTrainingScenarioStormRisk3,
            l10n.radarTrainingScenarioStormRisk4,
          ],
          successCriteria: [
            l10n.radarTrainingScenarioStormSuccess1,
            l10n.radarTrainingScenarioStormSuccess2,
            l10n.radarTrainingScenarioStormSuccess3,
            l10n.radarTrainingScenarioStormSuccess4,
          ],
          assetPath: scenario.assetPath,
          scenarioName: scenario.scenarioName,
        );
      case 'false_recovery_tunnel_vision':
        return RadarTrainingScenario(
          id: scenario.id,
          title: l10n.radarTrainingScenarioTunnelTitle,
          difficulty: scenario.difficulty,
          estimatedTime: scenario.estimatedTime,
          learningGoal: l10n.radarTrainingScenarioTunnelLearningGoal,
          objective: l10n.radarTrainingScenarioTunnelObjective,
          trafficSituation: l10n.radarTrainingScenarioTunnelTraffic,
          expectedTechnique: l10n.radarTrainingScenarioTunnelTechnique,
          riskFactors: [
            l10n.radarTrainingScenarioTunnelRisk1,
            l10n.radarTrainingScenarioTunnelRisk2,
            l10n.radarTrainingScenarioTunnelRisk3,
          ],
          successCriteria: [
            l10n.radarTrainingScenarioTunnelSuccess1,
            l10n.radarTrainingScenarioTunnelSuccess2,
            l10n.radarTrainingScenarioTunnelSuccess3,
          ],
          assetPath: scenario.assetPath,
          scenarioName: scenario.scenarioName,
        );
      default:
        return scenario;
    }
  }
}
