class DailyChallengeState {
  final bool quizDone;
  final bool radarDone;
  final int score;

  const DailyChallengeState({
    required this.quizDone,
    required this.radarDone,
    required this.score,
  });

  factory DailyChallengeState.initial() => const DailyChallengeState(
        quizDone: false,
        radarDone: false,
        score: 0,
      );

  bool get isComplete => quizDone && radarDone;

  int get progress => (quizDone ? 1 : 0) + (radarDone ? 1 : 0);

  String get rank {
    if (score >= 200) return 'Mission Complete';
    if (score >= 150) return 'Tower Ready';
    if (score >= 50) return 'Controller Trainee';
    return 'Cadet';
  }

  DailyChallengeState copyWith({bool? quizDone, bool? radarDone, int? score}) =>
      DailyChallengeState(
        quizDone: quizDone ?? this.quizDone,
        radarDone: radarDone ?? this.radarDone,
        score: score ?? this.score,
      );
}
