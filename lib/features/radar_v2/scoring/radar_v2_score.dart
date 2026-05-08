import '../commands/controller_command.dart';
import '../models/simulation_snapshot.dart';

class RadarV2ScoreSnapshot {
  final int score;
  final int commandCount;
  final int separationLossCount;
  final int lateResolutionCount;
  final int lastDelta;
  final String? lastReason;
  final List<String> penalties;

  const RadarV2ScoreSnapshot({
    required this.score,
    required this.commandCount,
    required this.separationLossCount,
    required this.lateResolutionCount,
    required this.lastDelta,
    required this.lastReason,
    required this.penalties,
  });

  String get grade {
    if (score >= 90) return 'A';
    if (score >= 75) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }
}

class RadarV2ScoreTracker {
  final Set<String> _separationLossKeys = <String>{};
  final Set<String> _lateConflictKeys = <String>{};
  int _score = 100;
  int _commandCount = 0;
  int _altitudeCommandCount = 0;
  int _lastDelta = 0;
  String? _lastReason;
  final List<String> _penalties = <String>[];

  RadarV2ScoreSnapshot get snapshot => RadarV2ScoreSnapshot(
        score: _score.clamp(0, 100),
        commandCount: _commandCount,
        separationLossCount: _separationLossKeys.length,
        lateResolutionCount: _lateConflictKeys.length,
        lastDelta: _lastDelta,
        lastReason: _lastReason,
        penalties: List<String>.unmodifiable(_penalties),
      );

  void recordCommand(ControllerCommand command, SimulationSnapshot snapshot) {
    _commandCount += 1;

    if (_commandCount > 8) {
      _penalize(1, 'Excessive command load');
    }

    if (command is AssignAltitude) {
      _altitudeCommandCount += 1;
      final involvedInAlert = snapshot.separation.any((result) {
        final involved = result.aircraftAId == command.aircraftId ||
            result.aircraftBId == command.aircraftId;
        return involved &&
            (result.isLossOfSeparation || result.isPredictedConflict);
      });
      if (!involvedInAlert || _altitudeCommandCount > 3) {
        _penalize(3, 'Unnecessary altitude change');
      }
    }
  }

  void observe(SimulationSnapshot snapshot) {
    for (final result in snapshot.separation) {
      final key = _pairKey(result.aircraftAId, result.aircraftBId);
      if (result.isLossOfSeparation && _separationLossKeys.add(key)) {
        _penalize(25, 'Separation loss');
      }
      if (result.isPredictedConflict &&
          (result.timeToConflict?.inSeconds ?? 999) <= 45 &&
          _lateConflictKeys.add(key)) {
        _penalize(5, 'Late resolution');
      }
    }
  }

  void _penalize(int points, String reason) {
    _score -= points;
    _lastDelta = -points;
    _lastReason = reason;
    _penalties.add('-$points $reason');
    if (_penalties.length > 5) {
      _penalties.removeAt(0);
    }
  }

  String _pairKey(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}:${ids[1]}';
  }
}
