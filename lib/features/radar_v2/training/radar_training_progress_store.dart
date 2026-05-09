import 'package:shared_preferences/shared_preferences.dart';

class RadarTrainingProgress {
  final int bestScore;
  final String bestGrade;
  final int completedCount;

  const RadarTrainingProgress({
    this.bestScore = 0,
    this.bestGrade = '-',
    this.completedCount = 0,
  });

  int get stars => starsForScore(bestScore);

  static int starsForScore(int score) {
    if (score >= 90) return 3;
    if (score >= 75) return 2;
    if (score > 0) return 1;
    return 0;
  }
}

class RadarTrainingProgressStore {
  static String _scoreKey(String scenarioId) =>
      'radar_beta_best_score_$scenarioId';
  static String _gradeKey(String scenarioId) =>
      'radar_beta_best_grade_$scenarioId';
  static String _completedKey(String scenarioId) =>
      'radar_beta_completed_$scenarioId';
  static const String _seenOnboardingKey = 'radar_beta_onboarding_seen';

  const RadarTrainingProgressStore();

  Future<RadarTrainingProgress> load(String scenarioId) async {
    final prefs = await SharedPreferences.getInstance();
    return RadarTrainingProgress(
      bestScore: prefs.getInt(_scoreKey(scenarioId)) ?? 0,
      bestGrade: prefs.getString(_gradeKey(scenarioId)) ?? '-',
      completedCount: prefs.getInt(_completedKey(scenarioId)) ?? 0,
    );
  }

  Future<void> saveResult({
    required String scenarioId,
    required int score,
    required String grade,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_scoreKey(scenarioId)) ?? 0;
    if (score > best) {
      await prefs.setInt(_scoreKey(scenarioId), score);
      await prefs.setString(_gradeKey(scenarioId), grade);
    }
    final completed = prefs.getInt(_completedKey(scenarioId)) ?? 0;
    await prefs.setInt(_completedKey(scenarioId), completed + 1);
  }

  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenOnboardingKey) ?? false);
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
  }
}
