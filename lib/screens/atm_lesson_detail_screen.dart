import 'package:flutter/material.dart';
import '../l10n/l10n_extensions.dart';
import '../l10n/l10n_key_resolver.dart';
import '../models/atm_lesson.dart';
import 'atm_quiz_screen.dart';

class AtmLessonDetailScreen extends StatefulWidget {
  final AtmLesson lesson;

  const AtmLessonDetailScreen({super.key, required this.lesson});

  @override
  State<AtmLessonDetailScreen> createState() => _AtmLessonDetailScreenState();
}

class _AtmLessonDetailScreenState extends State<AtmLessonDetailScreen> {
  int _page = 0;

  List<String> get _pages => widget.lesson.contentKeys;
  int get _total => _pages.length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(resolveKey(context, widget.lesson.titleKey)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_page + 1) / (_total + 1),
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.l10n.progressLabel}: ${_page + 1} / $_total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: Text(
                  resolveKey(context, _pages[_page]),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_page > 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _page--),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(context.l10n.btnPrevious),
                  )
                else
                  const SizedBox(),
                if (_page < _total - 1)
                  FilledButton.icon(
                    onPressed: () => setState(() => _page++),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(context.l10n.btnNext),
                  )
                else
                  FilledButton.icon(
                    onPressed: widget.lesson.quiz.isNotEmpty
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AtmQuizScreen(
                                  lesson: widget.lesson,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.quiz),
                    label: Text(context.l10n.btnStartLesson),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
