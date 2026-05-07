import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radar_level_config.dart';

class ProgressionService {
  ProgressionService._();
  static final instance = ProgressionService._();

  static const _keyLevel = 'prog_current_level';
  static const _keyXp    = 'prog_total_xp';
  static String _keyBest(int lvl) => 'prog_best_score_$lvl';

  // Reactive notifiers so UI rebuilds when values change
  final ValueNotifier<int> levelNotifier = ValueNotifier(1);
  final ValueNotifier<int> xpNotifier    = ValueNotifier(0);

  int get currentLevel => levelNotifier.value;
  int get totalXp      => xpNotifier.value;

  /// XP thresholds: Cadet / Trainee / Controller / Senior / Tower Master
  String get rankKey {
    if (totalXp >= 2000) return 'progRankMaster';
    if (totalXp >= 1000) return 'progRankSenior';
    if (totalXp >=  500) return 'progRankController';
    if (totalXp >=  200) return 'progRankTrainee';
    return 'progRankCadet';
  }

  int getBestScore(int level) => _bestScores[level] ?? 0;

  final Map<int, int> _bestScores = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    levelNotifier.value = p.getInt(_keyLevel) ?? 1;
    xpNotifier.value    = p.getInt(_keyXp)    ?? 0;
    for (int i = 1; i <= RadarLevelConfig.maxLevel; i++) {
      final b = p.getInt(_keyBest(i));
      if (b != null) _bestScores[i] = b;
    }
  }

  /// Call on scenario success.  Returns XP awarded.
  Future<int> completeLevel(int level, int score) async {
    final p = await SharedPreferences.getInstance();

    // Best score
    if (score > (_bestScores[level] ?? 0)) {
      _bestScores[level] = score;
      await p.setInt(_keyBest(level), score);
    }

    // XP: base 100 per level completed + 50 bonus for score ≥ 100
    final xp = 100 + (score >= 100 ? 50 : 0);
    xpNotifier.value = xpNotifier.value + xp;
    await p.setInt(_keyXp, xpNotifier.value);

    // Advance level
    if (level >= levelNotifier.value && levelNotifier.value < RadarLevelConfig.maxLevel) {
      levelNotifier.value = level + 1;
      await p.setInt(_keyLevel, levelNotifier.value);
    }

    return xp;
  }

  /// Call on scenario failure — small participation XP.
  Future<void> awardParticipationXp() async {
    final p = await SharedPreferences.getInstance();
    xpNotifier.value += 10;
    await p.setInt(_keyXp, xpNotifier.value);
  }

  // ── Per-scenario score history (for improvement tracking) ─────────────────
  static String _keyScenarioScore(String scenarioId) =>
      'scenario_last_score_$scenarioId';

  /// Returns the score from the previous attempt, or null if first play.
  Future<int?> getLastScenarioScore(String scenarioId) async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_keyScenarioScore(scenarioId));
    return v;
  }

  /// Saves this attempt's score. Returns the delta vs last attempt
  /// (positive = improvement, negative = regression, null = first play).
  Future<int?> saveScenarioScore(String scenarioId, int score) async {
    final p    = await SharedPreferences.getInstance();
    final last = p.getInt(_keyScenarioScore(scenarioId));
    await p.setInt(_keyScenarioScore(scenarioId), score);
    return last != null ? score - last : null;
  }

  /// Static helper: XP needed for each rank boundary.
  static const Map<String, int> rankThresholds = {
    'progRankCadet':      0,
    'progRankTrainee':  200,
    'progRankController': 500,
    'progRankSenior':  1000,
    'progRankMaster':  2000,
  };
}
