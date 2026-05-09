import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/replay_event.dart';
import '../models/scenario_result.dart';

/// Horizontal timeline showing replay progress, event markers, and a scrubber.
/// Exposes [progressNotifier] so [RadarReplayView] can stay in sync.
class ReplayTimeline extends StatelessWidget {
  final DetailedScenarioResult result;
  final ValueNotifier<double> progressNotifier; // 0→1
  final bool isPlaying;
  final int speedMultiplier; // 1 | 2 | 4
  final VoidCallback onPlayPause;
  final VoidCallback onCycleSpeed;

  const ReplayTimeline({
    super.key,
    required this.result,
    required this.progressNotifier,
    required this.isPlaying,
    required this.speedMultiplier,
    required this.onPlayPause,
    required this.onCycleSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (_, t, __) => Column(
        children: [
          // ── Marker bar ────────────────────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track background
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Progress fill
                  Positioned(
                    top: 10,
                    left: 0,
                    width: w * t,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Event markers
                  for (final e in result.replayEvents)
                    _EventMarker(
                      event: e,
                      totalDuration: result.totalDurationSeconds,
                      trackWidth: w,
                    ),
                  // Playhead
                  Positioned(
                    top: 4,
                    left: (w * t - 6).clamp(0, w - 12),
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) {
                        final frac =
                            ((d.localPosition.dx + w * t) / w).clamp(0.0, 1.0);
                        progressNotifier.value = frac;
                      },
                      child: Container(
                        width: 12,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),

          // ── Controls row ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Play / Pause button
              _CtrlBtn(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppTheme.primary,
                onTap: onPlayPause,
              ),

              // Time display
              Text(
                '${(t * result.totalDurationSeconds).toStringAsFixed(1)} / '
                '${result.totalDurationSeconds.toStringAsFixed(0)} s',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10),
              ),

              // Speed selector
              GestureDetector(
                onTap: onCycleSpeed,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    '${speedMultiplier}×',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Legend ────────────────────────────────────────────────────────
          Row(
            children: [
              _LegendDot(
                  color: const Color(0xFFFF1744),
                  label: l10n.replayLegendClosestApproach),
              const SizedBox(width: 12),
              _LegendDot(
                  color: Colors.yellowAccent,
                  label: l10n.replayLegendYourAction),
              const SizedBox(width: 12),
              _LegendDot(
                  color: const Color(0xFF00E676),
                  label: l10n.scoreRowResolvedEarly),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Event marker on the timeline bar ──────────────────────────────────────────

class _EventMarker extends StatelessWidget {
  final ReplayEvent event;
  final double totalDuration;
  final double trackWidth;

  const _EventMarker({
    required this.event,
    required this.totalDuration,
    required this.trackWidth,
  });

  Color get _color {
    switch (event.eventType) {
      case ReplayEventType.separationLoss:
        return AppTheme.danger;
      case ReplayEventType.conflictWarning:
        return AppTheme.warning;
      case ReplayEventType.userVector:
      case ReplayEventType.userAltitudeChange:
      case ReplayEventType.userSpeedChange:
        return Colors.yellowAccent;
      case ReplayEventType.recovered:
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frac = (event.timestampSeconds / totalDuration).clamp(0.0, 1.0);
    return Positioned(
      top: 6,
      left: (trackWidth * frac - 5).clamp(0, trackWidth - 10),
      child: Tooltip(
        message: event.label ?? event.eventType.name,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
            border: Border.all(color: AppTheme.background, width: 1),
          ),
        ),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CtrlBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        ],
      );
}
