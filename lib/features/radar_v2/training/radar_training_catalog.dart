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

  // Optional challenge variants; intentionally not shown in the default
  // beginner-focused beta scenario list.
  static const List<RadarTrainingScenario> challengeScenarios = [
    RadarTrainingScenario(
      id: 'beginner_crossing_conflict_challenge',
      title: 'Crossing Arrivals Challenge',
      difficulty: RadarTrainingDifficulty.approach,
      estimatedTime: Duration(minutes: 4),
      learningGoal: 'Higher attention pressure under familiar geometry',
      objective:
          'Resolve the same crossing pattern with tighter attention tolerance and quicker subtle-conflict detection penalties.',
      trafficSituation:
          'Identical crossing-arrivals layout with reduced awareness support and faster tunnel-risk emergence.',
      expectedTechnique:
          'Use the same early vector logic, but maintain broader scan discipline throughout recovery.',
      riskFactors: [
        'Subtle conflicts are deferred less forgivingly',
        'Attention drift escalates faster under load',
        'Command bursts increase surprise risk sooner',
      ],
      successCriteria: [
        'No separation loss',
        'Keep scan imbalance low during merge pressure',
        'Recover without tunnel-vision escalation',
      ],
      assetPath:
          'assets/scenarios/v2/melbourne/crossing_arrivals_challenge.json',
      scenarioName: 'Crossing Arrivals Challenge',
    ),
    RadarTrainingScenario(
      id: 'overtaking_traffic_challenge',
      title: 'Overtaking Traffic Challenge',
      difficulty: RadarTrainingDifficulty.supervisor,
      estimatedTime: Duration(minutes: 4),
      learningGoal: 'Closure-rate control under stronger attention decay',
      objective:
          'Prevent overtake-driven loss while handling crossing pressure with reduced awareness support.',
      trafficSituation:
          'Same overtake geometry with higher workload pressure and lower peripheral awareness tolerance.',
      expectedTechnique:
          'Anticipate closure early, then rebalance attention before secondary threats emerge.',
      riskFactors: [
        'Closure threats become salient later under fixation',
        'Secondary streams are easier to neglect',
        'Late recovery requires larger corrective vectors',
      ],
      successCriteria: [
        'No separation loss',
        'No sustained scan blind periods',
        'Keep command timing proactive, not reactive',
      ],
      assetPath:
          'assets/scenarios/v2/melbourne/overtaking_traffic_challenge.json',
      scenarioName: 'Overtaking Traffic Challenge',
    ),
    RadarTrainingScenario(
      id: 'false_recovery_tunnel_vision_challenge',
      title: 'False Recovery Challenge',
      difficulty: RadarTrainingDifficulty.supervisor,
      estimatedTime: Duration(minutes: 5),
      learningGoal: 'Resist fixation during deceptive stability windows',
      objective:
          'Sustain broad scan discipline through false recovery under stronger cognitive pressure.',
      trafficSituation:
          'The same false-recovery sequence with lower awareness support and longer subtle-conflict delay penalties.',
      expectedTechnique:
          'Resolve early threat, then immediately redistribute scan across quieter aircraft.',
      riskFactors: [
        'False calm invites premature task closure',
        'Interruptions amplify fixation probability',
        'Late rediscovery cascades into runway pressure',
      ],
      successCriteria: [
        'No separation loss',
        'Limit delayed-awareness moments',
        'Avoid critical fixation state',
      ],
      assetPath:
          'assets/scenarios/v2/melbourne/false_recovery_tunnel_vision_challenge.json',
      scenarioName: 'False Recovery Challenge',
    ),
    RadarTrainingScenario(
      id: 'melbourne_storm_arrival_rush_challenge',
      title: 'Melbourne Storm Arrival Rush Challenge',
      difficulty: RadarTrainingDifficulty.supervisor,
      estimatedTime: Duration(minutes: 6),
      learningGoal:
          'Advanced multi-stressor management with minimal awareness support',
      objective:
          'Hold spacing and runway flow through the storm compression with challenge-level attention pressure.',
      trafficSituation:
          'Same storm topology and traffic ecology, but with sharper attention competition and lower confidence retention.',
      expectedTechnique:
          'Prioritize hidden threats early, then continuously rebalance scan under storm and runway pressure.',
      riskFactors: [
        'Salient-weather fixation can mask quieter conflicts',
        'Surprise risk rises quickly during synchronized stressors',
        'Late rediscovery shrinks recovery geometry',
        'Runway pressure compounds during overload windows',
      ],
      successCriteria: [
        'No separation loss',
        'Maintain stable arrival spacing through reroutes',
        'Avoid ignored critical alert chains',
        'Recover workload before collapse threshold',
      ],
      assetPath:
          'assets/scenarios/v2/melbourne/storm_arrival_rush_challenge.json',
      scenarioName: 'Melbourne Storm Arrival Rush Challenge',
    ),
  ];

  static const List<RadarTrainingScenario> allScenarios = [
    ...scenarios,
    ...challengeScenarios,
  ];

  static RadarTrainingScenario byId(String id) {
    return allScenarios.firstWhere((scenario) => scenario.id == id);
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

  static Map<String, String> get allScenarioAssets => {
        for (final scenario in allScenarios)
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
