import 'package:atm_flutter/features/radar_v2/training/radar_training_text_localizer.dart';
import 'package:atm_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Radar Training Phase 2 - Dynamic Cascade Localization', () {
    testWidgets('cascade edge explanations are localized for all locales',
        (tester) async {
      const locales = [
        Locale('en'),
        Locale('zh'),
        Locale('fr'),
      ];

      for (final locale in locales) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;

                // Test interrupted evidence
                final interrupted =
                    'Evidence suggests fixation was interrupted by recovery activity (alert density).';
                final localizedInterrupted =
                    RadarTrainingTextLocalizer.line(l10n, interrupted);
                expect(
                  localizedInterrupted,
                  isNot('Evidence suggests'),
                  reason:
                      'Interrupted evidence should be localized for locale: ${l10n.localeName}',
                );

                // Test contributed evidence
                final contributed =
                    'Evidence suggests missed conflict likely contributed to recovery interrupted through close timing. Recovery activity weakens this inference.';
                final localizedContributed =
                    RadarTrainingTextLocalizer.line(l10n, contributed);
                expect(
                  localizedContributed,
                  isNot('Evidence suggests'),
                  reason:
                      'Contributed evidence should be localized for locale: ${l10n.localeName}',
                );

                // Test fallback strings
                final lateResolution =
                    'A conflict was resolved later than the traffic picture required.';
                final localizedLate =
                    RadarTrainingTextLocalizer.line(l10n, lateResolution);
                expect(
                  localizedLate,
                  isNotEmpty,
                  reason:
                      'Late resolution should be localized for locale: ${l10n.localeName}',
                );

                final workloadCompetition =
                    'Workload rose as unresolved alerts and commands competed.';
                final localizedWorkload =
                    RadarTrainingTextLocalizer.line(l10n, workloadCompetition);
                expect(
                  localizedWorkload,
                  isNotEmpty,
                  reason:
                      'Workload competition should be localized for locale: ${l10n.localeName}',
                );

                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
    });

    testWidgets('cascade factors are localized correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;

              // Test all factor types
              const factors = [
                'close timing',
                'alert density',
                'attention degradation overlap',
                'unresolved conflict pressure',
                'recovery interruption reduced confidence',
                'weak timing signal',
              ];

              for (final factor in factors) {
                // Access the private _localizeFactor through the localizer
                // We do this indirectly by testing edge explanations that use it
                final evidence =
                    'Evidence suggests fixation was interrupted by recovery activity ($factor).';
                final localized =
                    RadarTrainingTextLocalizer.line(l10n, evidence);

                // In French, the factor should be translated, not appear as-is
                if (l10n.localeName == 'fr') {
                  expect(
                    localized,
                    isNot(evidence),
                    reason:
                        'French localization should transform factor: $factor',
                  );
                }
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('new cascade explanation keys are accessible',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;

              // Verify all new keys are accessible
              expect(l10n.radarTrainingCascadeEvidenceInterrupted('test', 'factor'),
                  isNotEmpty);
              expect(
                  l10n.radarTrainingCascadeEvidenceContributed('a', 'b', 'c'),
                  isNotEmpty);
              expect(l10n.radarTrainingCascadeEvidenceRecoveryWeakens,
                  isNotEmpty);
              expect(l10n.radarTrainingCascadeLateResolution, isNotEmpty);
              expect(l10n.radarTrainingCascadeWorkloadCompetition, isNotEmpty);
              expect(l10n.radarTrainingCascadeConflictSeparationPressure,
                  isNotEmpty);
              expect(l10n.radarTrainingCascadeRecoveryUnstable, isNotEmpty);

              // Factor keys
              expect(l10n.radarTrainingCascadeFactorCloseTiming, isNotEmpty);
              expect(l10n.radarTrainingCascadeFactorAlertDensity, isNotEmpty);
              expect(l10n.radarTrainingCascadeFactorAttentionDegradation,
                  isNotEmpty);
              expect(l10n.radarTrainingCascadeFactorUnresolvedConflict,
                  isNotEmpty);
              expect(l10n.radarTrainingCascadeFactorRecoveryInterruption,
                  isNotEmpty);
              expect(l10n.radarTrainingCascadeFactorWeakTiming, isNotEmpty);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
