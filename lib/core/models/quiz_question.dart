import 'localized_text.dart';

class QuizQuestion {
  final LocalizedText question;
  final List<LocalizedText> options;
  final int correctIndex;
  final LocalizedText explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
