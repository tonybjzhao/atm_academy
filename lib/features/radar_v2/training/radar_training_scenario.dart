enum RadarTrainingDifficulty {
  cadet,
  approach,
  supervisor,
}

class RadarTrainingScenario {
  final String id;
  final String title;
  final RadarTrainingDifficulty difficulty;
  final Duration estimatedTime;
  final String learningGoal;
  final String objective;
  final String trafficSituation;
  final String expectedTechnique;
  final List<String> riskFactors;
  final List<String> successCriteria;
  final String assetPath;
  final String scenarioName;

  const RadarTrainingScenario({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.estimatedTime,
    required this.learningGoal,
    required this.objective,
    required this.trafficSituation,
    required this.expectedTechnique,
    required this.riskFactors,
    required this.successCriteria,
    required this.assetPath,
    required this.scenarioName,
  });

  String get difficultyLabel => switch (difficulty) {
        RadarTrainingDifficulty.cadet => 'Cadet',
        RadarTrainingDifficulty.approach => 'Approach',
        RadarTrainingDifficulty.supervisor => 'Supervisor',
      };

  String get estimatedTimeLabel => '${estimatedTime.inMinutes} min';
}
