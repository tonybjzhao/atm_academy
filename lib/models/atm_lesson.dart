import 'atm_quiz_question.dart';

enum AtmLevel { beginner, intermediate, advanced, expert }

class AtmLesson {
  final String id;
  final AtmLevel level;
  final String titleKey;
  final String summaryKey;
  final List<String> contentKeys;
  final List<AtmQuizQuestion> quiz;

  const AtmLesson({
    required this.id,
    required this.level,
    required this.titleKey,
    required this.summaryKey,
    required this.contentKeys,
    required this.quiz,
  });
}
