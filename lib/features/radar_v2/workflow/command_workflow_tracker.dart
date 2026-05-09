import '../commands/controller_command.dart';
import '../models/aircraft_state.dart';
import '../models/simulation_event.dart';
import '../models/simulation_snapshot.dart';

enum CommandWorkflowStatus {
  sent,
  awaitingAcknowledgement,
  acknowledged,
  completed,
}

class CommandWorkflowEntry {
  final String id;
  final String aircraftId;
  final String callsign;
  final String commandType;
  final String label;
  final Duration issuedAt;
  final Duration? acknowledgedAt;
  final Duration? completedAt;
  final CommandWorkflowStatus status;
  final String? chainId;
  final double? targetHeadingDeg;
  final int? targetAltitudeFt;
  final double? targetSpeedKt;
  final String? targetDirectWaypointId;

  const CommandWorkflowEntry({
    required this.id,
    required this.aircraftId,
    required this.callsign,
    required this.commandType,
    required this.label,
    required this.issuedAt,
    required this.acknowledgedAt,
    required this.completedAt,
    required this.status,
    this.chainId,
    this.targetHeadingDeg,
    this.targetAltitudeFt,
    this.targetSpeedKt,
    this.targetDirectWaypointId,
  });

  CommandWorkflowEntry copyWith({
    Duration? acknowledgedAt,
    Duration? completedAt,
    CommandWorkflowStatus? status,
  }) {
    return CommandWorkflowEntry(
      id: id,
      aircraftId: aircraftId,
      callsign: callsign,
      commandType: commandType,
      label: label,
      issuedAt: issuedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      chainId: chainId,
      targetHeadingDeg: targetHeadingDeg,
      targetAltitudeFt: targetAltitudeFt,
      targetSpeedKt: targetSpeedKt,
      targetDirectWaypointId: targetDirectWaypointId,
    );
  }
}

class ReplayCommandInsight {
  final String aircraftId;
  final String commandType;
  final Duration issuedAt;
  final Duration acknowledgedAt;
  final Duration acknowledgementDelay;
  final bool delayed;
  final bool interrupted;
  final List<String> causes;
  final String? spacingImpact;

  const ReplayCommandInsight({
    required this.aircraftId,
    required this.commandType,
    required this.issuedAt,
    required this.acknowledgedAt,
    required this.acknowledgementDelay,
    required this.delayed,
    required this.interrupted,
    required this.causes,
    required this.spacingImpact,
  });
}

class CommandWorkflowTracker {
  final List<CommandWorkflowEntry> _entries = <CommandWorkflowEntry>[];

  List<CommandWorkflowEntry> get entries =>
      List<CommandWorkflowEntry>.unmodifiable(_entries);

  void clear() => _entries.clear();

  void onCommandSent({
    required ControllerCommand command,
    required AircraftState aircraft,
    required String label,
    String? chainId,
  }) {
    final id = '${command.aircraftId}:${command.runtimeType}:${command.issuedAt.inMilliseconds}:${_entries.length}';
    _entries.add(
      CommandWorkflowEntry(
        id: id,
        aircraftId: command.aircraftId,
        callsign: aircraft.callsign,
        commandType: _commandTypeFromCommand(command),
        label: label,
        issuedAt: command.issuedAt,
        acknowledgedAt: null,
        completedAt: null,
        status: CommandWorkflowStatus.sent,
        chainId: chainId,
        targetHeadingDeg: command is AssignHeading ? command.headingDeg : null,
        targetAltitudeFt:
            command is AssignAltitude ? command.altitudeFt : null,
        targetSpeedKt: command is AssignSpeed ? command.speedKt : null,
        targetDirectWaypointId:
            command is DirectToWaypoint ? command.waypointId : null,
      ),
    );
  }

  void onSnapshotTransition({
    required SimulationSnapshot previous,
    required SimulationSnapshot current,
  }) {
    if (current.events.length <= previous.events.length) {
      _updateAwaitingState();
      _updateCompletionState(current);
      return;
    }

    final newEvents = current.events.skip(previous.events.length);
    for (final event in newEvents) {
      if (event.type != 'commandAcknowledged' || event.aircraftId == null) {
        continue;
      }
      final token = _commandTypeFromLabel(event.label);
      final index = _entries.lastIndexWhere((entry) {
        if (entry.aircraftId != event.aircraftId) return false;
        if (entry.status == CommandWorkflowStatus.completed) return false;
        if (entry.commandType != token) return false;
        return event.elapsed >= entry.issuedAt;
      });
      if (index == -1) continue;
      final entry = _entries[index];
      _entries[index] = entry.copyWith(
        acknowledgedAt: event.elapsed,
        status: CommandWorkflowStatus.acknowledged,
      );
    }

    _updateAwaitingState();
    _updateCompletionState(current);
  }

  List<CommandWorkflowEntry> entriesForAircraft(String aircraftId) {
    return _entries
        .where((entry) => entry.aircraftId == aircraftId)
        .toList(growable: false)
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  List<CommandWorkflowEntry> activeRestrictionsForAircraft(String aircraftId) {
    return entriesForAircraft(aircraftId)
        .where((entry) =>
            entry.status != CommandWorkflowStatus.completed &&
            entry.commandType != 'hold')
        .toList(growable: false);
  }

  List<ReplayCommandInsight> replayInsights(List<SimulationEvent> events) {
    final issues = events
        .where((event) => event.type == 'commandIssued' && event.aircraftId != null)
        .toList(growable: false);
    final acks = events
        .where((event) => event.type == 'commandAcknowledged' && event.aircraftId != null)
        .toList(growable: false);

    final insights = <ReplayCommandInsight>[];
    for (final issue in issues) {
      final token = _commandTypeFromLabel(issue.label);
      final ack = acks.firstWhere(
        (candidate) {
          if (candidate.aircraftId != issue.aircraftId) return false;
          if (_commandTypeFromLabel(candidate.label) != token) return false;
          final delta = candidate.elapsed - issue.elapsed;
          return delta >= Duration.zero && delta <= const Duration(seconds: 20);
        },
        orElse: () => const SimulationEvent(
          elapsed: Duration.zero,
          type: '',
          label: '',
          aircraftId: null,
        ),
      );
      if (ack.type.isEmpty) continue;
      final delay = ack.elapsed - issue.elapsed;
      final interrupted = events.any((event) {
        if (event.elapsed <= issue.elapsed || event.elapsed >= ack.elapsed) {
          return false;
        }
        return event.type != 'commandIssued' && event.type != 'commandAcknowledged';
      });
      final contextEvents = events.where((event) {
        if (event.aircraftId != issue.aircraftId) return false;
        return event.elapsed >= issue.elapsed &&
            event.elapsed <= ack.elapsed + const Duration(seconds: 14);
      }).toList(growable: false);
      final causes = _causesForEvents(contextEvents);
      final spacingImpact = _spacingImpactForEvents(contextEvents, delay);
      insights.add(
        ReplayCommandInsight(
          aircraftId: issue.aircraftId!,
          commandType: token,
          issuedAt: issue.elapsed,
          acknowledgedAt: ack.elapsed,
          acknowledgementDelay: delay,
          delayed: delay >= const Duration(seconds: 4),
          interrupted: interrupted,
          causes: causes,
          spacingImpact: spacingImpact,
        ),
      );
    }
    return insights;
  }

  List<String> _causesForEvents(List<SimulationEvent> events) {
    final causes = <String>[];
    void add(String cause) {
      if (!causes.contains(cause)) {
        causes.add(cause);
      }
    }

    for (final event in events) {
      switch (event.type) {
        case 'pilotResponseDelay':
          add('pilot response delay');
        case 'pilotExecutionDelay':
          add('execution start lag');
        case 'pilotReadbackPartial':
          add('partial readback');
        case 'pilotReadbackConfirmDelay':
          add('delayed confirmation');
        case 'weatherInteraction':
        case 'weatherCompression':
        case 'weatherComplianceDelay':
          add('weather-driven deviation');
        case 'pilotLateCapture':
          add('late capture after acknowledgement');
        case 'pilotSpeedInstability':
          add('speed instability during follow-through');
      }
    }
    return causes;
  }

  String? _spacingImpactForEvents(
    List<SimulationEvent> events,
    Duration ackDelay,
  ) {
    final sawCompression = events.any((event) {
      return event.type == 'weatherCompression' ||
          event.label.toLowerCase().contains('spacing compressed');
    });
    final sawConflictPressure = events.any((event) {
      final normalizedType = event.type.toLowerCase();
      final normalizedLabel = event.label.toLowerCase();
      return normalizedType.contains('conflict') ||
          normalizedType.contains('separation') ||
          normalizedLabel.contains('conflict') ||
          normalizedLabel.contains('separation');
    });
    if (sawConflictPressure && ackDelay >= const Duration(seconds: 4)) {
      return 'Pilot delay overlapped with conflict/separation pressure.';
    }
    if (sawCompression) {
      return 'Spacing compressed during pilot response and execution.';
    }
    if (ackDelay >= const Duration(seconds: 6)) {
      return 'Long acknowledgement window reduced spacing recovery margin.';
    }
    return null;
  }

  void _updateAwaitingState() {
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.status == CommandWorkflowStatus.sent) {
        _entries[i] = entry.copyWith(
          status: CommandWorkflowStatus.awaitingAcknowledgement,
        );
      }
    }
  }

  void _updateCompletionState(SimulationSnapshot current) {
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.status == CommandWorkflowStatus.completed) continue;
      final aircraft = current.aircraftById(entry.aircraftId);
      if (aircraft == null || !aircraft.active) continue;
      if (!_isCommandComplete(entry, aircraft)) continue;
      if (entry.status == CommandWorkflowStatus.acknowledged) {
        _entries[i] = entry.copyWith(
          completedAt: current.elapsed,
          status: CommandWorkflowStatus.completed,
        );
      }
    }
  }

  bool _isCommandComplete(CommandWorkflowEntry entry, AircraftState aircraft) {
    switch (entry.commandType) {
      case 'heading':
        final assigned = aircraft.intent.assignedHeadingDeg;
        if (assigned == null || entry.targetHeadingDeg == null) return false;
        return _headingDeltaDeg(assigned, entry.targetHeadingDeg!) <= 3;
      case 'altitude':
        final assigned = aircraft.intent.assignedAltitudeFt;
        if (assigned == null || entry.targetAltitudeFt == null) return false;
        return (assigned - entry.targetAltitudeFt!).abs() <= 100;
      case 'speed':
        final assigned = aircraft.intent.assignedSpeedKt;
        if (assigned == null || entry.targetSpeedKt == null) return false;
        return (assigned - entry.targetSpeedKt!).abs() <= 5;
      case 'direct':
        return aircraft.intent.directToWaypointId == entry.targetDirectWaypointId;
      case 'hold':
        return aircraft.intent.hold || aircraft.intent.holdPatternId == null;
      default:
        return false;
    }
  }

  double _headingDeltaDeg(double a, double b) {
    final raw = (a - b).abs() % 360;
    return raw > 180 ? 360 - raw : raw;
  }

  String _commandTypeFromCommand(ControllerCommand command) {
    if (command is AssignHeading) return 'heading';
    if (command is AssignAltitude) return 'altitude';
    if (command is AssignSpeed) return 'speed';
    if (command is DirectToWaypoint) return 'direct';
    if (command is EnterHold || command is ExitHold) return 'hold';
    return 'other';
  }

  String _commandTypeFromLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('heading')) return 'heading';
    if (normalized.contains('altitude')) return 'altitude';
    if (normalized.contains('speed')) return 'speed';
    if (normalized.contains('direct')) return 'direct';
    if (normalized.contains('hold')) return 'hold';
    return 'other';
  }
}
