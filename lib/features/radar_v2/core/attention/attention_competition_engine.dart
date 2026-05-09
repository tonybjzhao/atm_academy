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
  final Map<String, Duration> _aircraftLastScannedAt = <String, Duration>{};
  final List<Duration> _fixationWindowStarts = <Duration>[];
  String? _lastFocusTarget;
  Duration? _scanBlindSince;
  Duration _overloadDuration = Duration.zero;
  Duration? _lastElapsed;
  bool _fixationWindowActive = false;

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
    final activeInterrupts =
        _activeInterrupts(snapshot, elapsed: elapsed).toList(growable: false);
    final delayedAwarenessMoments = snapshot.events
        .where((event) => event.type == 'attentionDelayedRecognition')
        .length;

    final attentionBudget = _attentionBudget(
      load,
      competingHighPriorityAlerts: competingHighPriorityAlerts,
      ignoredAlerts: ignoredAlerts,
      focusDuration: focusDuration,
      activeInterruptCount: activeInterrupts.length,
    );
    final neglect = _observeNeglect(
      snapshot: snapshot,
      elapsed: elapsed,
      focusTarget: focusTarget,
      alerts: alerts,
      attentionBudget: attentionBudget,
    );
    final scanBlindDuration = _scanBlindDuration(
      elapsed: elapsed,
      scannedAircraftCount: neglect.scannedAircraftCount,
      activeAircraftCount: neglect.activeAircraftCount,
      competingHighPriorityAlerts: competingHighPriorityAlerts,
    );
    final fixationWindows = _fixationWindowCount(
      elapsed: elapsed,
      focusDuration: focusDuration,
      competingHighPriorityAlerts: competingHighPriorityAlerts,
    );
    final missedSecondaryProblems = _missedSecondaryProblems(
      alerts: alerts,
      focusTarget: focusTarget,
      focusDuration: focusDuration,
    );

    final risk = _riskLevel(
      focusDuration: focusDuration,
      ignoredAlerts: ignoredAlerts,
      competingHighPriorityAlerts: competingHighPriorityAlerts,
      focusedCommands: focusedCommands,
      overloaded: load.isOverloaded,
      attentionBudget: attentionBudget,
      scanCoverageQuality: neglect.scanCoverageQuality,
      longestNeglect: neglect.longestNeglect,
      scanBlindDuration: scanBlindDuration,
      missedSecondaryProblems: missedSecondaryProblems,
      delayedAwarenessMoments: delayedAwarenessMoments,
    );

    return AttentionFocusState(
      currentFocusTarget: focusTarget,
      focusDuration: focusDuration,
      ignoredAlerts: ignoredAlerts,
      competingHighPriorityAlertCount: competingHighPriorityAlerts,
      recentFocusedCommandCount: focusedCommands,
      overloadDuration: _overloadDuration,
      attentionBudget: attentionBudget,
      scanCoverageQuality: neglect.scanCoverageQuality,
      neglectedAircraftIds: neglect.neglectedAircraftIds,
      averageNeglect: neglect.averageNeglect,
      longestNeglect: neglect.longestNeglect,
      scanBlindDuration: scanBlindDuration,
      fixationWindowCount: fixationWindows,
      delayedAwarenessMoments: delayedAwarenessMoments,
      missedSecondaryProblems: missedSecondaryProblems,
      activeInterrupts: activeInterrupts,
      riskLevel: risk,
      reportLines: _reportLines(
        elapsed: elapsed,
        focusTarget: focusTarget,
        focusDuration: focusDuration,
        ignoredAlerts: ignoredAlerts,
        competingHighPriorityAlerts: competingHighPriorityAlerts,
        focusedCommands: focusedCommands,
        overloaded: load.isOverloaded,
        attentionBudget: attentionBudget,
        neglect: neglect,
        scanBlindDuration: scanBlindDuration,
        fixationWindowCount: fixationWindows,
        delayedAwarenessMoments: delayedAwarenessMoments,
        activeInterrupts: activeInterrupts,
        missedSecondaryProblems: missedSecondaryProblems,
      ),
    );
  }

  void reset() {
    _ignoredAlertTracker.reset();
    _focusStartedAt.clear();
    _aircraftLastScannedAt.clear();
    _fixationWindowStarts.clear();
    _lastFocusTarget = null;
    _lastElapsed = null;
    _scanBlindSince = null;
    _overloadDuration = Duration.zero;
    _fixationWindowActive = false;
  }

  double _attentionBudget(
    CognitiveLoadState load, {
    required int competingHighPriorityAlerts,
    required List<IgnoredAlertSnapshot> ignoredAlerts,
    required Duration focusDuration,
    required int activeInterruptCount,
  }) {
    final loadWeight = (load.totalLoadScore / 10).clamp(0.0, 1.0) * 0.32;
    final competitionWeight =
        (competingHighPriorityAlerts / 3).clamp(0.0, 1.0) * 0.22;
    final ignoredWeight =
        (ignoredAlerts.where((alert) => alert.isCritical).length / 2)
                .clamp(0.0, 1.0) *
            0.16;
    final fixationWeight =
        (focusDuration.inSeconds / 45).clamp(0.0, 1.0) * 0.18;
    final interruptWeight =
        (activeInterruptCount / 3).clamp(0.0, 1.0) * 0.12;
    final consumed =
        (loadWeight + competitionWeight + ignoredWeight + fixationWeight + interruptWeight)
            .clamp(0.0, 1.0);
    return (1.0 - consumed).clamp(0.0, 1.0);
  }

  _NeglectSummary _observeNeglect({
    required SimulationSnapshot snapshot,
    required Duration elapsed,
    required String? focusTarget,
    required Iterable<OperationalAlert> alerts,
    required double attentionBudget,
  }) {
    final activeIds = snapshot.aircraft
        .where((aircraft) => aircraft.active)
        .map((aircraft) => aircraft.id)
        .toSet();
    _aircraftLastScannedAt.removeWhere((id, _) => !activeIds.contains(id));

    final scannedIds = _scannedAircraftIds(
      focusTarget: focusTarget,
      alerts: alerts,
    );
    for (final id in scannedIds) {
      if (activeIds.contains(id)) {
        _aircraftLastScannedAt[id] = elapsed;
      }
    }
    for (final id in activeIds) {
      _aircraftLastScannedAt.putIfAbsent(id, () => elapsed);
    }

    if (activeIds.isEmpty) {
      return const _NeglectSummary(
        neglectedAircraftIds: [],
        averageNeglect: Duration.zero,
        longestNeglect: Duration.zero,
        scanCoverageQuality: 1.0,
        activeAircraftCount: 0,
        scannedAircraftCount: 0,
      );
    }

    final neglectByAircraft = <String, Duration>{};
    var totalNeglectMs = 0;
    Duration longest = Duration.zero;
    for (final id in activeIds) {
      final neglect = elapsed - (_aircraftLastScannedAt[id] ?? elapsed);
      neglectByAircraft[id] = neglect;
      totalNeglectMs += math.max(0, neglect.inMilliseconds);
      if (neglect > longest) longest = neglect;
    }

    final dynamicThresholdSeconds =
        (30 - (1.0 - attentionBudget) * 16).clamp(14.0, 30.0);
    final neglected = neglectByAircraft.entries
        .where((entry) => entry.value.inSeconds >= dynamicThresholdSeconds)
        .map((entry) => entry.key)
        .toList(growable: false)
      ..sort();

    final average =
        Duration(milliseconds: (totalNeglectMs / activeIds.length).round());
    final weightedNeglectRatio = neglectByAircraft.values
            .map((duration) => (duration.inSeconds / 60).clamp(0.0, 1.0))
            .fold<double>(0.0, (sum, ratio) => sum + ratio) /
        activeIds.length;
    final coverage =
        (1.0 - weightedNeglectRatio * 0.65 - (1.0 - attentionBudget) * 0.35)
            .clamp(0.0, 1.0);

    return _NeglectSummary(
      neglectedAircraftIds: List.unmodifiable(neglected),
      averageNeglect: average,
      longestNeglect: longest,
      scanCoverageQuality: coverage,
      activeAircraftCount: activeIds.length,
      scannedAircraftCount: scannedIds.length,
    );
  }

  Set<String> _scannedAircraftIds({
    required String? focusTarget,
    required Iterable<OperationalAlert> alerts,
  }) {
    final scanned = <String>{};
    if (focusTarget == null) return scanned;
    if (focusTarget.startsWith('aircraft:')) {
      scanned.add(focusTarget.substring('aircraft:'.length));
      return scanned;
    }
    if (focusTarget.startsWith('alert:')) {
      final id = focusTarget.substring('alert:'.length);
      for (final alert in alerts) {
        if (alert.id == id) {
          scanned.addAll(alert.relatedAircraftIds);
          break;
        }
      }
      return scanned;
    }
    if (focusTarget.startsWith('runway:')) {
      final runwayId = focusTarget.substring('runway:'.length);
      for (final alert in alerts) {
        if (alert.relatedRunwayId == runwayId) {
          scanned.addAll(alert.relatedAircraftIds);
        }
      }
    }
    return scanned;
  }

  Duration _scanBlindDuration({
    required Duration elapsed,
    required int scannedAircraftCount,
    required int activeAircraftCount,
    required int competingHighPriorityAlerts,
  }) {
    final blindCondition =
        scannedAircraftCount == 0 && (activeAircraftCount >= 4 || competingHighPriorityAlerts > 0);
    if (blindCondition) {
      _scanBlindSince ??= elapsed;
      return elapsed - (_scanBlindSince ?? elapsed);
    }
    _scanBlindSince = null;
    return Duration.zero;
  }

  int _fixationWindowCount({
    required Duration elapsed,
    required Duration focusDuration,
    required int competingHighPriorityAlerts,
  }) {
    final fixationNow =
        focusDuration >= const Duration(seconds: 20) && competingHighPriorityAlerts > 0;
    if (fixationNow && !_fixationWindowActive) {
      _fixationWindowStarts.add(elapsed);
      _fixationWindowActive = true;
    } else if (!fixationNow) {
      _fixationWindowActive = false;
    }
    _fixationWindowStarts.removeWhere(
      (start) => elapsed - start > const Duration(minutes: 3),
    );
    return _fixationWindowStarts.length;
  }

  int _missedSecondaryProblems({
    required Iterable<OperationalAlert> alerts,
    required String? focusTarget,
    required Duration focusDuration,
  }) {
    if (focusTarget == null || focusDuration < const Duration(seconds: 18)) {
      return 0;
    }
    final criticalActive = alerts.where((alert) {
      return !alert.acknowledged && alert.priority == AlertPriority.critical;
    }).isNotEmpty;
    if (!criticalActive) return 0;
    return alerts.where((alert) {
      final secondary =
          alert.priority == AlertPriority.low || alert.priority == AlertPriority.medium;
      return secondary && !alert.acknowledged && !_matchesFocus(alert, focusTarget);
    }).length;
  }

  Set<String> _activeInterrupts(
    SimulationSnapshot snapshot, {
    required Duration elapsed,
  }) {
    final interrupts = <String>{};
    for (final id in snapshot.activeDistractions) {
      interrupts.add(_normalizeInterruptType(id));
    }
    for (final event in snapshot.events.reversed) {
      if (event.type != 'attentionInterrupt') continue;
      if (elapsed - event.elapsed > const Duration(seconds: 45)) break;
      interrupts.add(_normalizeInterruptType(event.label));
    }
    return interrupts;
  }

  String _normalizeInterruptType(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('radio') || value.contains('chatter')) {
      return 'radio chatter';
    }
    if (value.contains('runway')) return 'runway change';
    if (value.contains('weather')) return 'weather update';
    if (value.contains('emergency') || value.contains('engine')) {
      return 'emergency distraction';
    }
    return 'operational interrupt';
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
    required double attentionBudget,
    required double scanCoverageQuality,
    required Duration longestNeglect,
    required Duration scanBlindDuration,
    required int missedSecondaryProblems,
    required int delayedAwarenessMoments,
  }) {
    final topIgnored = ignoredAlerts.isEmpty ? null : ignoredAlerts.first;
    if (topIgnored != null &&
        topIgnored.isCritical &&
        topIgnored.ignoredFor >= const Duration(seconds: 30)) {
      return AttentionRiskLevel.criticalFixation;
    }
    if (scanBlindDuration >= const Duration(seconds: 32) ||
        (delayedAwarenessMoments >= 2 &&
            longestNeglect >= const Duration(seconds: 28))) {
      return AttentionRiskLevel.criticalFixation;
    }
    if (overloaded &&
        focusDuration >= const Duration(seconds: 30) &&
        competingHighPriorityAlerts > 0) {
      return AttentionRiskLevel.criticalFixation;
    }
    if (scanCoverageQuality <= 0.48 ||
        longestNeglect >= const Duration(seconds: 40) ||
        missedSecondaryProblems >= 2) {
      return AttentionRiskLevel.tunnelVision;
    }
    if (topIgnored != null &&
        topIgnored.ignoredFor >= const Duration(seconds: 15)) {
      return AttentionRiskLevel.tunnelVision;
    }
    if (focusedCommands >= 4 && competingHighPriorityAlerts > 0) {
      return AttentionRiskLevel.tunnelVision;
    }
    if (attentionBudget <= 0.55 ||
        scanBlindDuration >= const Duration(seconds: 14) ||
        longestNeglect >= const Duration(seconds: 25)) {
      return AttentionRiskLevel.fixationRisk;
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
    required double attentionBudget,
    required _NeglectSummary neglect,
    required Duration scanBlindDuration,
    required int fixationWindowCount,
    required int delayedAwarenessMoments,
    required List<String> activeInterrupts,
    required int missedSecondaryProblems,
  }) {
    final lines = <String>[];
    final topIgnored = ignoredAlerts.isEmpty ? null : ignoredAlerts.first;
    if (attentionBudget < 0.62) {
      lines.add(
        'Attention budget reduced to ${(attentionBudget * 100).round()}% under current load.',
      );
    }
    if (neglect.neglectedAircraftIds.isNotEmpty) {
      final examples = neglect.neglectedAircraftIds.take(2).join(', ');
      lines.add(
        'Neglect building on ${neglect.neglectedAircraftIds.length} track(s): '
        '$examples (max ${neglect.longestNeglect.inSeconds}s unseen).',
      );
    }
    if (scanBlindDuration >= const Duration(seconds: 12)) {
      lines.add(
        'Scan blind period lasted ${scanBlindDuration.inSeconds}s.',
      );
    }
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
    if (fixationWindowCount > 0) {
      lines.add('Fixation windows observed: $fixationWindowCount.');
    }
    if (missedSecondaryProblems > 0) {
      lines.add('Secondary issues likely missed under priority competition.');
    }
    if (activeInterrupts.isNotEmpty) {
      lines.add('Attention interrupts active: ${activeInterrupts.join(', ')}.');
    }
    if (delayedAwarenessMoments > 0) {
      lines.add('Delayed awareness moments recorded: $delayedAwarenessMoments.');
    }
    return List<String>.unmodifiable(lines.take(5));
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
    var maxNeglect = Duration.zero;
    var peakBlind = Duration.zero;
    var delayedAwareness = 0;
    var missedSecondary = 0;

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
      if (state.longestNeglect > maxNeglect) {
        maxNeglect = state.longestNeglect;
      }
      if (state.scanBlindDuration > peakBlind) {
        peakBlind = state.scanBlindDuration;
      }
      delayedAwareness = math.max(delayedAwareness, state.delayedAwarenessMoments);
      missedSecondary = math.max(missedSecondary, state.missedSecondaryProblems);
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
    if (maxNeglect >= const Duration(seconds: 25)) {
      lines.add('Longest neglected track went unseen for ${maxNeglect.inSeconds}s.');
    }
    if (peakBlind >= const Duration(seconds: 12)) {
      lines.add('Scan blind period peaked at ${peakBlind.inSeconds}s.');
    }
    if (delayedAwareness > 0) {
      lines.add('Delayed awareness moments: $delayedAwareness.');
    }
    if (missedSecondary > 0) {
      lines.add('Missed secondary issues during priority competition: $missedSecondary.');
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

class _NeglectSummary {
  final List<String> neglectedAircraftIds;
  final Duration averageNeglect;
  final Duration longestNeglect;
  final double scanCoverageQuality;
  final int activeAircraftCount;
  final int scannedAircraftCount;

  const _NeglectSummary({
    required this.neglectedAircraftIds,
    required this.averageNeglect,
    required this.longestNeglect,
    required this.scanCoverageQuality,
    required this.activeAircraftCount,
    required this.scannedAircraftCount,
  });
}
