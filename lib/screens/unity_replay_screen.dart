// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/replay_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Feature flag.  Set to true ONLY after:
//   1. flutter_unity_widget added to pubspec.yaml
//   2. Unity project built for iOS/Android and exported
//   3. Exported files placed in ios/UnityFramework & android/unityLibrary
// See unity/SETUP.md for the full integration guide.
// ─────────────────────────────────────────────────────────────────────────────
const bool kUnityEnabled = false;

class UnityReplayScreen extends StatelessWidget {
  final ScenarioReplayData replayData;

  const UnityReplayScreen({super.key, required this.replayData});

  @override
  Widget build(BuildContext context) {
    return kUnityEnabled
        ? _UnityView(replayData: replayData)
        : _PlaceholderView(replayData: replayData);
  }
}

// ── Live Unity view ───────────────────────────────────────────────────────────
// Uncomment this class and the flutter_unity_widget import once the Unity
// project is built and kUnityEnabled is set to true.
//
// import 'package:flutter_unity_widget/flutter_unity_widget.dart';
//
// class _UnityView extends StatefulWidget {
//   final ScenarioReplayData replayData;
//   const _UnityView({required this.replayData});
//   @override State<_UnityView> createState() => _UnityViewState();
// }
//
// class _UnityViewState extends State<_UnityView> {
//   UnityWidgetController? _controller;
//
//   @override
//   Widget build(BuildContext context) {
//     final l10n = AppLocalizations.of(context)!;
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text(l10n.unityReplayTitle),
//         backgroundColor: Colors.black,
//         foregroundColor: AppTheme.primary,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: UnityWidget(
//         onUnityCreated: (controller) {
//           _controller = controller;
//           // Send scenario data to Unity after widget is ready
//           Future.delayed(const Duration(milliseconds: 500), () {
//             _controller?.postMessage(
//               'ScenarioReplayManager',  // Unity GameObject name
//               'LoadReplayData',         // Unity method name
//               widget.replayData.toJson(),
//             );
//           });
//         },
//         onUnityMessage: (message) {
//           // Unity sends 'REPLAY_COMPLETE' when done
//           if (message == 'REPLAY_COMPLETE' && mounted) {
//             Navigator.pop(context);
//           }
//         },
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
// }

// Stub that satisfies the type reference when kUnityEnabled is false.
class _UnityView extends StatelessWidget {
  final ScenarioReplayData replayData;
  const _UnityView({required this.replayData});
  @override
  Widget build(BuildContext context) => _PlaceholderView(replayData: replayData);
}

// ── Placeholder view (shown until Unity is integrated) ────────────────────────
class _PlaceholderView extends StatelessWidget {
  final ScenarioReplayData replayData;
  const _PlaceholderView({required this.replayData});

  Color _ratingColor() {
    switch (replayData.ratingKey) {
      case 'ratingExcellent': return AppTheme.primary;
      case 'ratingSafe':      return Colors.greenAccent;
      case 'ratingNeedsImprovement': return AppTheme.warning;
      default: return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.unityReplayTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Radar-style placeholder circle
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF050F0A),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rings
                  for (final r in [0.33, 0.66, 1.0])
                    Container(
                      width: 260 * r,
                      height: 260 * r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  // Aircraft blips
                  for (int i = 0; i < replayData.finalAircraft.length; i++)
                    _AircraftBlip(
                      state: replayData.finalAircraft[i],
                      radarRadius: 130,
                    ),
                  // Centre label
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.view_in_ar_outlined,
                          color: AppTheme.textSecondary, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        l10n.unityReplayComingSoon,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Scenario summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replayData.scenarioTitle,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow('Score', '${replayData.score} / 120', _ratingColor()),
                  _SummaryRow(
                    'Min separation',
                    '${replayData.minHorizDist.toStringAsFixed(0)} px',
                    replayData.hadLOS ? AppTheme.danger : AppTheme.primary,
                  ),
                  _SummaryRow(
                    'Loss of separation',
                    replayData.hadLOS ? 'YES' : 'No',
                    replayData.hadLOS ? AppTheme.danger : AppTheme.primary,
                  ),
                  const SizedBox(height: 8),
                  // Aircraft list
                  const Divider(color: AppTheme.borderColor, height: 1),
                  const SizedBox(height: 8),
                  for (final a in replayData.finalAircraft)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.flight,
                              size: 13,
                              color: a.wasConflicting
                                  ? AppTheme.danger
                                  : a.wasSelected
                                      ? Colors.yellowAccent
                                      : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${a.callsign}  FL${a.altitude}  '
                            'HDG ${a.heading.toInt()}°',
                            style: TextStyle(
                              color: a.wasSelected
                                  ? Colors.yellowAccent
                                  : AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (a.wasSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.yellowAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('selected',
                                  style: TextStyle(
                                      color: Colors.yellowAccent, fontSize: 9)),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 15),
                label: Text(l10n.unityReplayBack),
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AircraftBlip extends StatelessWidget {
  final AircraftReplayState state;
  final double radarRadius;
  const _AircraftBlip({required this.state, required this.radarRadius});

  @override
  Widget build(BuildContext context) {
    // Map scenario coords (0..370 x 0..430) to radar circle (-1..1)
    final nx = (state.x / 370.0) * 2 - 1; // -1..1
    final ny = (state.y / 430.0) * 2 - 1;
    final px = nx * radarRadius;
    final py = ny * radarRadius;

    final color = state.wasConflicting
        ? AppTheme.danger
        : state.wasSelected
            ? Colors.yellowAccent
            : AppTheme.primary;

    return Positioned(
      left: radarRadius + px - 4,
      top: radarRadius + py - 4,
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          Text(state.callsign,
              style: TextStyle(color: color, fontSize: 7, height: 1.1)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SummaryRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
