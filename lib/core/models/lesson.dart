import 'localized_text.dart';
import 'quiz_question.dart';

enum AnimationType { radarSweep, runwayFlow, separationDemo, commsPulse, none }

enum LessonLevel { beginner, intermediate, advanced, expert }

class Lesson {
  final String id;
  final LocalizedText title;
  final LocalizedText summary;
  final List<LocalizedText> keyPoints;
  final AnimationType animationType;
  final LessonLevel level;
  final List<QuizQuestion> quiz;

  const Lesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.animationType,
    required this.level,
    required this.quiz,
  });
}
