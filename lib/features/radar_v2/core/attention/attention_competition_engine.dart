import 'dart:math' as math;

import '../../models/simulation_event.dart';
import '../../models/simulation_snapshot.dart';
import '../alerts/alert_priority.dart';
import '../alerts/operational_alert.dart';
import '../cognitive_load/cognitive_load_state.dart';
import 'attention_focus_state.dart';
import 'ignored_alert_tracker.dart';

class AttentionCompetitionEngine {
  final IgnoredAlertTracker _ignoredAlertTracker;
  final Map<String, Duration> _focusStartedAt = <String, Duration>{};
  String? _lastFocusTarget;
  Duration _overloadDuration = Duration.zero;
  Duration? _lastElapsed;

  AttentionCompetitionEngine({
    IgnoredAlertTracker? ignoredAlertTracker,
  }) : _ignoredAlertTracker = ignoredAlertTracker ?? IgnoredAlertTracker();

  AttentionFocusState evaluate({
    required SimulationSnapshot snapshot,
    String? selectedAircraftId,
    String? selectedRunwayId,
    String? selectedAlertId,
    CognitiveLoadState? cognitiveLoad,
    Iterable<OperationalAlert>? operationalAlerts,
  }) {
    final alerts = operationalAlerts ?? snapshot.operationalAlerts;
    final load = cognitiveLoad ?? snapshot.cognitiveLoad;
    final focusTarget = _resolveFocusTarget(
      selectedAircraftId: selectedAircraftId,
      selectedRunwayId: selectedRunwayId,
      selectedAlertId: selectedAlertId,
      alerts: alerts,
      events: snapshot.events,
    );

    final elapsed = snapshot.elapsed;
    final delta =
        _lastElapsed == null ? Duration.zero : elapsed - _lastElapsed!;
    _lastElapsed = elapsed;
    if (load.isOverloaded) {
      _overloadDuration += delta.isNegative ? Duration.zero : delta;
    } else {
      _overloadDuration = Duration.zero;
    }

    if (focusTarget != null && focusTarget != _lastFocusTarget) {
      _focusStartedAt[focusTarget] = elapsed;
      _lastFocusTarget = focusTarget;
    }
    final focusDuration = focusTarget == null
        ? Duration.zero
        : elapsed - (_focusStartedAt[focusTarget] ?? elapsed);

    final ignoredAlerts = _ignoredAlertTracker.update(
      elapsed: elapsed,
      alerts: alerts,
      focusTarget: focusTarget,
      overloaded: load.isOverloaded,
    );
    final competingHighPriorityAlerts = alerts.where((alert) {
      return !alert.acknowledged &&
          _isHighPriority(alert) &&
          !_matchesFocus(alert, focusTarget);
    }).length;
    final focusedCommands = _recentFocusedCommandCount(
      snapshot.events,
      elapsed,
      focusTarget,
    );

    final risk = _riskLevel(
      focusDuration: focusDuration,
      ignoredAlerts: ignoredAlerts,
      competingHighPriorityAlerts: competingHighPriorityAlerts,
      focusedCommands: focusedCommands,
      overloaded: load.isOverloaded,
    );

    return AttentionFocusState(
      currentFocusTarget: focusTarget,
      focusDuration: focusDuration,
      ignoredAlerts: ignoredAlerts,
      competingHighPriorityAlertCount: competingHighPriorityAlerts,
      recentFocusedCommandCount: focusedCommands,
      overloadDuration: _overloadDuration,
      riskLevel: risk,
      reportLines: _reportLines(
        elapsed: elapsed,
        focusTarget: focusTarget,
        focusDuration: focusDuration,
        ignoredAlerts: ignoredAlerts,
        competingHighPriorityAlerts: competingHighPriorityAlerts,
        focusedCommands: focusedCommands,
        overloaded: load.isOverloaded,
      ),
    );
  }

  void reset() {
    _ignoredAlertTracker.reset();
    _focusStartedAt.clear();
    _lastFocusTarget = null;
    _lastElapsed = null;
    _overloadDuration = Duration.zero;
  }

  String? _resolveFocusTarget({
    required String? selectedAircraftId,
    required String? selectedRunwayId,
    required String? selectedAlertId,
    required Iterable<OperationalAlert> alerts,
    required List<SimulationEvent> events,
  }) {
    if (selectedAlertId != null) return 'alert:$selectedAlertId';
    if (selectedAircraftId != null) return 'aircraft:$selectedAircraftId';
    if (selectedRunwayId != null) return 'runway:$selectedRunwayId';
    for (final event in events.reversed) {
      if (event.type == 'commandIssued' && event.aircraftId != null) {
        return 'aircraft:${event.aircraftId}';
      }
    }
    if (alerts.isEmpty) return null;
    final top = alerts.first;
    if (top.relatedAircraftIds.isNotEmpty) {
      return 'aircraft:${top.relatedAircraftIds.first}';
    }
    if (top.relatedRunwayId != null) return 'runway:${top.relatedRunwayId}';
    return 'alert:${top.id}';
  }

  int _recentFocusedCommandCount(
    List<SimulationEvent> events,
    Duration elapsed,
    String? focusTarget,
  ) {
    if (focusTarget == null || !focusTarget.startsWith('aircraft:')) return 0;
    final aircraftId = focusTarget.substring('aircraft:'.length);
    return events.where((event) {
      return event.type == 'commandIssued' &&
          event.aircraftId == aircraftId &&
          elapsed - event.elapsed <= const Duration(seconds: 45);
    }).length;
  }

  AttentionRiskLevel _riskLevel({
    required Duration focusDuration,
    required List<IgnoredAlertSnapshot> ignoredAlerts,
    required int competingHighPriorityAlerts,
    required int focusedCommands,
    required bool overloaded,
  }) {
    final topIgnored = ignoredAlerts.isEmpty ? null : ignoredAlerts.first;
    if (topIgnored != null &&
        topIgnored.isCritical &&
        topIgnored.ignoredFor >= const Duration(seconds: 30)) {
      return AttentionRiskLevel.criticalFixation;
    }
    if (overloaded &&
        focusDuration >= const Duration(seconds: 30) &&
        competingHighPriorityAlerts > 0) {
      return AttentionRiskLevel.criticalFixation;
    }
    if (topIgnored != null &&
        topIgnored.ignoredFor >= const Duration(seconds: 15)) {
      return AttentionRiskLevel.tunnelVision;
    }
    if (focusedCommands >= 4 && competingHighPriorityAlerts > 0) {
      return AttentionRiskLevel.tunnelVision;
    }
    if (focusDuration >= const Duration(seconds: 20) &&
        competingHighPriorityAlerts > 0) {
      return AttentionRiskLevel.fixationRisk;
    }
    if (overloaded && competingHighPriorityAlerts >= 2) {
      return AttentionRiskLevel.fixationRisk;
    }
    return AttentionRiskLevel.normal;
  }

  List<String> _reportLines({
    required Duration elapsed,
    required String? focusTarget,
    required Duration focusDuration,
    required List<IgnoredAlertSnapshot> ignoredAlerts,
    required int competingHighPriorityAlerts,
    required int focusedCommands,
    required bool overloaded,
  }) {
    final lines = <String>[];
    final topIgnored = ignoredAlerts.isEmpty ? null : ignoredAlerts.first;
    if (topIgnored != null &&
        focusTarget != null &&
        focusDuration >= const Duration(seconds: 20)) {
      lines.add(
        'Tunnel vision detected: ${focusDuration.inSeconds}s focused on '
        '${_displayTarget(focusTarget)} while ${topIgnored.alertType} alert escalated.',
      );
    }
    if (topIgnored != null &&
        topIgnored.ignoredFor >= const Duration(seconds: 15)) {
      lines.add(
        'Critical alert ignored for ${topIgnored.ignoredFor.inSeconds}s.',
      );
    }
    if (overloaded) {
      lines.add(
        'Peak workload occurred at ${elapsed.inSeconds}s with '
        '$competingHighPriorityAlerts competing alerts.',
      );
    }
    if (focusedCommands >= 4) {
      lines.add(
        'Command burst focused on ${_displayTarget(focusTarget ?? 'unknown')}.',
      );
    }
    return List<String>.unmodifiable(lines.take(4));
  }

  bool _isHighPriority(OperationalAlert alert) {
    return alert.priority == AlertPriority.high ||
        alert.priority == AlertPriority.critical;
  }

  bool _matchesFocus(OperationalAlert alert, String? focusTarget) {
    if (focusTarget == null) return false;
    if (focusTarget == 'alert:${alert.id}') return true;
    if (alert.relatedRunwayId != null &&
        focusTarget == 'runway:${alert.relatedRunwayId}') {
      return true;
    }
    for (final aircraftId in alert.relatedAircraftIds) {
      if (focusTarget == 'aircraft:$aircraftId') return true;
    }
    return false;
  }

  String _displayTarget(String target) => target.replaceFirst(':', ' ');
}

class AttentionReplayAnalytics {
  final List<AttentionFocusState> states;

  const AttentionReplayAnalytics({required this.states});

  AttentionReplaySummary generate() {
    var overloadDuration = Duration.zero;
    AttentionFocusState? peak;
    IgnoredAlertSnapshot? longestIgnored;
    final fixationPeriods = <AttentionFocusState>[];
    final tunnelEpisodes = <AttentionFocusState>[];
    final commandBursts = <AttentionFocusState>[];
    final ignoredCritical = <IgnoredAlertSnapshot>[];

    for (final state in states) {
      overloadDuration += state.overloadDuration > Duration.zero
          ? const Duration(seconds: 1)
          : Duration.zero;
      if (peak == null ||
          state.competingHighPriorityAlertCount >
              peak.competingHighPriorityAlertCount) {
        peak = state;
      }
      if (state.focusDuration >= const Duration(seconds: 20)) {
        fixationPeriods.add(state);
      }
      if (state.riskLevel == AttentionRiskLevel.tunnelVision ||
          state.riskLevel == AttentionRiskLevel.criticalFixation) {
        tunnelEpisodes.add(state);
      }
      if (state.recentFocusedCommandCount >= 4) commandBursts.add(state);
      for (final alert in state.ignoredAlerts) {
        if (alert.isCritical) ignoredCritical.add(alert);
        if (longestIgnored == null ||
            alert.ignoredFor > longestIgnored.ignoredFor) {
          longestIgnored = alert;
        }
      }
    }

    final lines = <String>[];
    if (peak != null && peak.competingHighPriorityAlertCount > 0) {
      lines.add(
        'Peak workload had ${peak.competingHighPriorityAlertCount} active alerts.',
      );
    }
    if (longestIgnored != null) {
      lines.add(
        'Critical alert ignored for ${longestIgnored.ignoredFor.inSeconds}s.',
      );
    }
    if (tunnelEpisodes.isNotEmpty) {
      final episode = tunnelEpisodes.reduce(
        (a, b) => a.focusDuration > b.focusDuration ? a : b,
      );
      lines.add(
        'Tunnel vision detected: ${episode.focusDuration.inSeconds}s focused on '
        '${episode.currentFocusTarget ?? 'unknown'}.',
      );
    }

    return AttentionReplaySummary(
      peakOverloadMoment: peak,
      longestIgnoredAlert: longestIgnored,
      fixationPeriods: List.unmodifiable(fixationPeriods),
      tunnelVisionEpisodes: List.unmodifiable(tunnelEpisodes),
      commandBurstWindows: List.unmodifiable(commandBursts),
      ignoredCriticalAlerts: List.unmodifiable(ignoredCritical),
      overloadDuration: overloadDuration,
      reportLines: List.unmodifiable(lines),
    );
  }
}

class AttentionReplaySummary {
  final AttentionFocusState? peakOverloadMoment;
  final IgnoredAlertSnapshot? longestIgnoredAlert;
  final List<AttentionFocusState> fixationPeriods;
  final List<AttentionFocusState> tunnelVisionEpisodes;
  final List<AttentionFocusState> commandBurstWindows;
  final List<IgnoredAlertSnapshot> ignoredCriticalAlerts;
  final Duration overloadDuration;
  final List<String> reportLines;

  const AttentionReplaySummary({
    required this.peakOverloadMoment,
    required this.longestIgnoredAlert,
    required this.fixationPeriods,
    required this.tunnelVisionEpisodes,
    required this.commandBurstWindows,
    required this.ignoredCriticalAlerts,
    required this.overloadDuration,
    required this.reportLines,
  });

  int get cognitionRiskScore {
    final raw = tunnelVisionEpisodes.length * 18 +
        ignoredCriticalAlerts.length * 12 +
        commandBurstWindows.length * 5 +
        math.min(30, overloadDuration.inSeconds ~/ 4);
    return raw.clamp(0, 100).toInt();
  }
}
