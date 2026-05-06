import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/replay_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Feature flag — flip to true ONLY after:
//   1. Unity project built for iOS/Android and exported
//   2. iOS:     exported framework placed in ios/UnityFramework/
//   3. Android: exported project placed in android/unityLibrary/
//   4. Native podfile/gradle wired per flutter_unity_widget docs
// See unity/SETUP.md for the full step-by-step guide.
// ─────────────────────────────────────────────────────────────────────────────
const bool kUnityEnabled = false;

class UnityReplayScreen extends StatelessWidget {
  final ScenarioReplayData replayData;

  const UnityReplayScreen({super.key, required this.replayData});

  @override
  Widget build(BuildContext context) {
    return kUnityEnabled
        ? _UnityReplayView(replayData: replayData)
        : _PlaceholderView(replayData: replayData);
  }
}

// ── Live Unity view ───────────────────────────────────────────────────────────
// Active when kUnityEnabled = true and native libraries are present.

class _UnityReplayView extends StatefulWidget {
  final ScenarioReplayData replayData;
  const _UnityReplayView({required this.replayData});

  @override
  State<_UnityReplayView> createState() => _UnityReplayViewState();
}

class _UnityReplayViewState extends State<_UnityReplayView> {
  UnityWidgetController? _controller;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () {
            _controller?.dispose();
            Navigator.pop(context);
          },
        ),
        title: Text(
          l10n.unityReplayTitle,
          style: const TextStyle(color: AppTheme.primary, fontSize: 14, letterSpacing: 0.8),
        ),
      ),
      body: UnityWidget(
        onUnityCreated: _onUnityCreated,
        onUnityMessage: _onUnityMessage,
        onUnitySceneLoaded: (_) {
          // Scene loaded — send data if not already sent
          if (!_sent) _sendReplayData();
        },
        useAndroidViewSurface: true,
        fullscreen: false,
      ),
    );
  }

  void _onUnityCreated(UnityWidgetController controller) {
    _controller = controller;
    // Small delay to ensure scene is fully initialised before sending data
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_sent) _sendReplayData();
    });
  }

  void _sendReplayData() {
    _sent = true;
    // postMessage sends a plain string — Unity receives it as the json param
    // in ScenarioReplayManager.LoadReplayData(string json).
    _controller?.postMessage(
      'ScenarioReplayManager', // Unity GameObject name (must match exactly)
      'LoadReplayData',        // Method on ScenarioReplayManager.cs
      widget.replayData.toJson(),
    );
  }

  void _onUnityMessage(dynamic message) {
    if (message?.toString() == 'REPLAY_COMPLETE' && mounted) {
      _controller?.dispose();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// ── Placeholder view ──────────────────────────────────────────────────────────
// Shown when kUnityEnabled = false.  Displays scenario summary on a dark
// radar-style screen so the screen is never empty.

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
            // Radar-style circle with aircraft blips
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
                  for (final a in replayData.finalAircraft)
                    _AircraftBlip(state: a, radarRadius: 130),
                  // "Coming soon" label at bottom of circle
                  Positioned(
                    bottom: 32,
                    child: Column(
                      children: [
                        const Icon(Icons.view_in_ar_outlined,
                            color: AppTheme.textSecondary, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          l10n.unityReplayComingSoon,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Scenario summary
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
                  _Row('Score', '${replayData.score} / 120', _ratingColor()),
                  _Row('Min separation',
                      '${replayData.minHorizDist.toStringAsFixed(0)} px',
                      replayData.hadLOS ? AppTheme.danger : AppTheme.primary),
                  _Row('Loss of separation',
                      replayData.hadLOS ? 'YES' : 'No',
                      replayData.hadLOS ? AppTheme.danger : AppTheme.primary),
                  const SizedBox(height: 8),
                  const Divider(color: AppTheme.borderColor, height: 1),
                  const SizedBox(height: 8),
                  for (final a in replayData.finalAircraft)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.flight,
                              size: 12,
                              color: a.wasConflicting
                                  ? AppTheme.danger
                                  : a.wasSelected
                                      ? Colors.yellowAccent
                                      : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${a.callsign}  FL${a.altitude}  HDG ${a.heading.toInt()}°',
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
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.yellowAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('selected',
                                  style: TextStyle(color: Colors.yellowAccent, fontSize: 9)),
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
    final nx = (state.x / 370.0) * 2 - 1;
    final ny = (state.y / 430.0) * 2 - 1;
    final color = state.wasConflicting
        ? AppTheme.danger
        : state.wasSelected
            ? Colors.yellowAccent
            : AppTheme.primary;

    return Positioned(
      left: radarRadius + nx * radarRadius - 4,
      top:  radarRadius + ny * radarRadius - 4,
      child: Column(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          Text(state.callsign,
              style: TextStyle(color: color, fontSize: 7, height: 1.1)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _Row(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
