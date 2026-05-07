import 'package:flutter/material.dart';
import '../core/models/lesson.dart';
import '../core/models/quiz_question.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../l10n/lesson_l10n.dart';
import '../services/daily_challenge_service.dart';

class QuizScreen extends StatefulWidget {
  final Lesson lesson;
  final String languageCode;

  const QuizScreen({
    super.key,
    required this.lesson,
    required this.languageCode,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int? _selectedOption;
  int _score = 0;
  bool _finished = false;

  List<QuizQuestion> get _quiz => widget.lesson.quiz;
  QuizQuestion get _current => _quiz[_currentIndex];

  void _selectOption(int index) {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = index;
      if (index == _current.correctIndex) _score++;
    });
  }

  void _advance() {
    if (_currentIndex < _quiz.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
      });
    } else {
      DailyChallengeService.instance.markQuizDone();
      setState(() => _finished = true);
    }
  }

  void _reset() {
    setState(() {
      _currentIndex = 0;
      _selectedOption = null;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.lesson.localizedTitle(context)} ${AppLocalizations.of(context)!.quizAppBarSuffix}'),
      ),
      body: _finished ? _buildResults() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final answered = _selectedOption != null;
    final isCorrect = answered && _selectedOption == _current.correctIndex;

    return Column(
      children: [
        LinearProgressIndicator(
          value: _currentIndex / _quiz.length,
          minHeight: 3,
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.quizQuestionProgress(_currentIndex + 1, _quiz.length),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    localizedQuizQuestion(context, widget.lesson.id, _currentIndex),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...() {
                  final options = localizedQuizOptions(context, widget.lesson.id, _currentIndex);
                  if (options.isNotEmpty) {
                    return List.generate(options.length, (i) => _buildOption(i, options[i]));
                  }
                  return List.generate(
                    _current.options.length,
                    (i) => _buildOption(i, _current.options[i].en),
                  );
                }(),
                if (answered) ...[
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.greenAccent.withValues(alpha: 0.1)
                          : Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.greenAccent.withValues(alpha: 0.5)
                            : Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect ? AppLocalizations.of(context)!.quizCorrectLabel : AppLocalizations.of(context)!.quizIncorrectLabel,
                              style: TextStyle(
                                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizedQuizExplanation(context, widget.lesson.id, _currentIndex),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _advance,
                      child: Text(
                        _currentIndex < _quiz.length - 1
                            ? AppLocalizations.of(context)!.quizNextQuestion
                            : AppLocalizations.of(context)!.quizSeeResults,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(int index, String text) {
    final answered = _selectedOption != null;
    final isSelected = _selectedOption == index;
    final isCorrect = index == _current.correctIndex;

    Color bgColor = AppTheme.surface;
    Color borderColor = AppTheme.borderColor;

    if (answered) {
      if (isCorrect) {
        bgColor = Colors.greenAccent.withValues(alpha: 0.08);
        borderColor = Colors.greenAccent.withValues(alpha: 0.5);
      } else if (isSelected) {
        bgColor = Colors.redAccent.withValues(alpha: 0.08);
        borderColor = Colors.redAccent.withValues(alpha: 0.5);
      }
    }

    Color dotColor = AppTheme.borderColor;
    if (answered && isCorrect) dotColor = Colors.greenAccent;
    if (answered && isSelected && !isCorrect) dotColor = Colors.redAccent;

    return GestureDetector(
      onTap: answered ? null : () => _selectOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 1.5),
              ),
              child: answered && (isCorrect || isSelected)
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: answered && isCorrect
                      ? Colors.greenAccent
                      : answered && isSelected
                          ? Colors.redAccent
                          : AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final isPerfect = _score == _quiz.length;
    final isGood = _score >= (_quiz.length * 0.6).ceil();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPerfect ? Icons.stars_rounded : Icons.school_outlined,
              size: 72,
              color: isPerfect ? AppTheme.warning : AppTheme.secondary,
            ),
            const SizedBox(height: 20),
            Text(
              '$_score / ${_quiz.length}',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPerfect
                  ? AppLocalizations.of(context)!.quizPerfectScore
                  : isGood
                      ? AppLocalizations.of(context)!.quizGoodWork
                      : AppLocalizations.of(context)!.quizKeepPracticing,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reset,
                child: Text(AppLocalizations.of(context)!.quizTryAgain),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                child: Text(AppLocalizations.of(context)!.quizBackToLesson),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
