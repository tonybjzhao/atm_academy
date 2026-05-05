class AtmQuizQuestion {
  final String id;
  final String questionKey;
  final List<String> optionKeys;
  final int correctIndex;
  final String explanationKey;

  const AtmQuizQuestion({
    required this.id,
    required this.questionKey,
    required this.optionKeys,
    required this.correctIndex,
    required this.explanationKey,
  });
}
