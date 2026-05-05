import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_challenge_state.dart';

class DailyChallengeService {
  DailyChallengeService._();
  static final instance = DailyChallengeService._();

  static const _keyDate = 'daily_challenge_date';
  static const _keyQuizDone = 'daily_quiz_done';
  static const _keyRadarDone = 'daily_radar_done';
  static const _keyScore = 'daily_score';

  static const _quizPoints = 50;
  static const _radarPoints = 100;
  static const _completionBonus = 50;

  final ValueNotifier<DailyChallengeState> stateNotifier =
      ValueNotifier(DailyChallengeState.initial());

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    if ((prefs.getString(_keyDate) ?? '') != today) {
      await prefs.setString(_keyDate, today);
      await prefs.setBool(_keyQuizDone, false);
      await prefs.setBool(_keyRadarDone, false);
      await prefs.setInt(_keyScore, 0);
      stateNotifier.value = DailyChallengeState.initial();
      return;
    }

    stateNotifier.value = DailyChallengeState(
      quizDone: prefs.getBool(_keyQuizDone) ?? false,
      radarDone: prefs.getBool(_keyRadarDone) ?? false,
      score: prefs.getInt(_keyScore) ?? 0,
    );
  }

  Future<void> markQuizDone() async {
    if (stateNotifier.value.quizDone) return;
    final prefs = await SharedPreferences.getInstance();
    var newScore = stateNotifier.value.score + _quizPoints;
    if (stateNotifier.value.radarDone) newScore += _completionBonus;
    await prefs.setBool(_keyQuizDone, true);
    await prefs.setInt(_keyScore, newScore);
    stateNotifier.value = stateNotifier.value.copyWith(quizDone: true, score: newScore);
  }

  Future<void> markRadarDone() async {
    if (stateNotifier.value.radarDone) return;
    final prefs = await SharedPreferences.getInstance();
    var newScore = stateNotifier.value.score + _radarPoints;
    if (stateNotifier.value.quizDone) newScore += _completionBonus;
    await prefs.setBool(_keyRadarDone, true);
    await prefs.setInt(_keyScore, newScore);
    stateNotifier.value = stateNotifier.value.copyWith(radarDone: true, score: newScore);
  }
}
