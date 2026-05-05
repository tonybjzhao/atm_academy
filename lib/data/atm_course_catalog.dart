import '../models/atm_lesson.dart';
import '../models/atm_quiz_question.dart';

const List<AtmLesson> atmCourseCatalog = [
  AtmLesson(
    id: 'atm_basics',
    level: AtmLevel.beginner,
    titleKey: 'lesson1Title',
    summaryKey: 'lesson1Summary',
    contentKeys: ['lesson1Content1', 'lesson1Content2', 'lesson1Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'atm_basics_q1',
        questionKey: 'lesson1Q1Question',
        optionKeys: ['lesson1Q1Option0', 'lesson1Q1Option1', 'lesson1Q1Option2'],
        correctIndex: 1,
        explanationKey: 'lesson1Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'atc_units',
    level: AtmLevel.beginner,
    titleKey: 'lesson2Title',
    summaryKey: 'lesson2Summary',
    contentKeys: ['lesson2Content1', 'lesson2Content2', 'lesson2Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'atc_units_q1',
        questionKey: 'lesson2Q1Question',
        optionKeys: ['lesson2Q1Option0', 'lesson2Q1Option1', 'lesson2Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson2Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'airport_basics',
    level: AtmLevel.beginner,
    titleKey: 'lesson3Title',
    summaryKey: 'lesson3Summary',
    contentKeys: ['lesson3Content1', 'lesson3Content2', 'lesson3Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'airport_basics_q1',
        questionKey: 'lesson3Q1Question',
        optionKeys: ['lesson3Q1Option0', 'lesson3Q1Option1', 'lesson3Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson3Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'flight_plan_basics',
    level: AtmLevel.intermediate,
    titleKey: 'lesson4Title',
    summaryKey: 'lesson4Summary',
    contentKeys: ['lesson4Content1', 'lesson4Content2', 'lesson4Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'flight_plan_basics_q1',
        questionKey: 'lesson4Q1Question',
        optionKeys: ['lesson4Q1Option0', 'lesson4Q1Option1', 'lesson4Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson4Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'separation_basics',
    level: AtmLevel.intermediate,
    titleKey: 'lesson5Title',
    summaryKey: 'lesson5Summary',
    contentKeys: ['lesson5Content1', 'lesson5Content2', 'lesson5Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'separation_basics_q1',
        questionKey: 'lesson5Q1Question',
        optionKeys: ['lesson5Q1Option0', 'lesson5Q1Option1', 'lesson5Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson5Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'sequencing_spacing',
    level: AtmLevel.intermediate,
    titleKey: 'lesson6Title',
    summaryKey: 'lesson6Summary',
    contentKeys: ['lesson6Content1', 'lesson6Content2', 'lesson6Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'sequencing_spacing_q1',
        questionKey: 'lesson6Q1Question',
        optionKeys: ['lesson6Q1Option0', 'lesson6Q1Option1', 'lesson6Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson6Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'weather_impact',
    level: AtmLevel.advanced,
    titleKey: 'lesson7Title',
    summaryKey: 'lesson7Summary',
    contentKeys: ['lesson7Content1', 'lesson7Content2', 'lesson7Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'weather_impact_q1',
        questionKey: 'lesson7Q1Question',
        optionKeys: ['lesson7Q1Option0', 'lesson7Q1Option1', 'lesson7Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson7Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'emergency_basics',
    level: AtmLevel.advanced,
    titleKey: 'lesson8Title',
    summaryKey: 'lesson8Summary',
    contentKeys: ['lesson8Content1', 'lesson8Content2', 'lesson8Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'emergency_basics_q1',
        questionKey: 'lesson8Q1Question',
        optionKeys: ['lesson8Q1Option0', 'lesson8Q1Option1', 'lesson8Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson8Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'atfcm_basics',
    level: AtmLevel.expert,
    titleKey: 'lesson9Title',
    summaryKey: 'lesson9Summary',
    contentKeys: ['lesson9Content1', 'lesson9Content2', 'lesson9Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'atfcm_basics_q1',
        questionKey: 'lesson9Q1Question',
        optionKeys: ['lesson9Q1Option0', 'lesson9Q1Option1', 'lesson9Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson9Q1Explanation',
      ),
    ],
  ),
  AtmLesson(
    id: 'human_factors',
    level: AtmLevel.expert,
    titleKey: 'lesson10Title',
    summaryKey: 'lesson10Summary',
    contentKeys: ['lesson10Content1', 'lesson10Content2', 'lesson10Content3'],
    quiz: [
      AtmQuizQuestion(
        id: 'human_factors_q1',
        questionKey: 'lesson10Q1Question',
        optionKeys: ['lesson10Q1Option0', 'lesson10Q1Option1', 'lesson10Q1Option2'],
        correctIndex: 0,
        explanationKey: 'lesson10Q1Explanation',
      ),
    ],
  ),
];
