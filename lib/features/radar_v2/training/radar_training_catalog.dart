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
      id: 'arrival_spacing_under_weather',
      title: 'Arrival Spacing Under Weather',
      difficulty: RadarTrainingDifficulty.approach,
      estimatedTime: Duration(minutes: 4),
      learningGoal: 'Sequencing and workload management',
      objective: 'Manage arrival spacing during weather-driven compression.',
      trafficSituation:
          'A faster jet closes on slower traffic while weather and runway pressure compress the flow.',
      expectedTechnique:
          'Slow or vector the faster aircraft early, then protect the merge point.',
      riskFactors: [
        'Low visibility increases runway occupancy time',
        'Closure rate is more important than current distance',
        'Weather can make spacing appear stable before it tightens',
      ],
      successCriteria: [
        'Maintain final spacing',
        'Avoid weather penetration',
        'Keep workload below sustained overload',
      ],
      assetPath: 'assets/scenarios/v2/melbourne/overtaking_traffic.json',
      scenarioName: 'Overtaking Traffic',
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

  static Map<String, String> get scenarioAssets => {
        for (final scenario in scenarios)
          scenario.scenarioName: scenario.assetPath,
      };
}
