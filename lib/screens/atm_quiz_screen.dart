import 'package:flutter/material.dart';
import '../l10n/l10n_extensions.dart';
import '../l10n/l10n_key_resolver.dart';
import '../models/atm_lesson.dart';
import '../models/atm_quiz_question.dart';

class AtmQuizScreen extends StatefulWidget {
  final AtmLesson lesson;

  const AtmQuizScreen({super.key, required this.lesson});

  @override
  State<AtmQuizScreen> createState() => _AtmQuizScreenState();
}

class _AtmQuizScreenState extends State<AtmQuizScreen> {
  int _questionIndex = 0;
  int? _selectedOption;
  bool _answered = false;

  AtmQuizQuestion get _currentQuestion =>
      widget.lesson.quiz[_questionIndex];

  bool get _isLastQuestion =>
      _questionIndex >= widget.lesson.quiz.length - 1;

  bool get _isCorrect =>
      _selectedOption == _currentQuestion.correctIndex;

  void _checkAnswer() {
    if (_selectedOption == null) return;
    setState(() => _answered = true);
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      Navigator.pop(context);
    } else {
      setState(() {
        _questionIndex++;
        _selectedOption = null;
        _answered = false;
      });
    }
  }

  void _tryAgain() {
    setState(() {
      _selectedOption = null;
      _answered = false;
    });
  }

  Color _optionColor(int index) {
    if (!_answered) return Colors.transparent;
    if (index == _currentQuestion.correctIndex) {
      return Colors.green.withValues(alpha: 0.15);
    }
    if (index == _selectedOption) {
      return Colors.red.withValues(alpha: 0.15);
    }
    return Colors.transparent;
  }

  Widget? _optionTrailing(int index) {
    if (!_answered) return null;
    if (index == _currentQuestion.correctIndex) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (index == _selectedOption) {
      return const Icon(Icons.cancel, color: Colors.red);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = _currentQuestion;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.quizTitle),
            Text(
              resolveKey(context, widget.lesson.titleKey),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress
            LinearProgressIndicator(
              value: (_questionIndex + 1) / widget.lesson.quiz.length,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '${_questionIndex + 1} / ${widget.lesson.quiz.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            // Question
            Text(
              resolveKey(context, question.questionKey),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Options
            Expanded(
              child: RadioGroup<int>(
                groupValue: _selectedOption,
                onChanged: (val) {
                  if (!_answered) setState(() => _selectedOption = val);
                },
                child: ListView.builder(
                  itemCount: question.optionKeys.length,
                  itemBuilder: (context, index) {
                    final optionText =
                        resolveKey(context, question.optionKeys[index]);
                    final trailing = _optionTrailing(index);

                    return Card(
                      color: _optionColor(index),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Radio<int>(value: index),
                        title: Text(optionText),
                        trailing: trailing,
                        onTap: _answered
                            ? null
                            : () =>
                                setState(() => _selectedOption = index),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Feedback after answering
            if (_answered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isCorrect
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isCorrect ? Colors.green : Colors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCorrect
                          ? context.l10n.quizCorrect
                          : context.l10n.quizIncorrect,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isCorrect ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.l10n.quizExplanation}: '
                      '${resolveKey(context, question.explanationKey)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isCorrect)
                    OutlinedButton.icon(
                      onPressed: _tryAgain,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.btnTryAgain),
                    )
                  else
                    const SizedBox(),
                  FilledButton.icon(
                    onPressed: _nextQuestion,
                    icon: Icon(
                        _isLastQuestion ? Icons.check : Icons.arrow_forward),
                    label: Text(_isLastQuestion
                        ? context.l10n.btnContinue
                        : context.l10n.btnNext),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedOption != null ? _checkAnswer : null,
                  child: Text(context.l10n.btnCheckAnswer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
