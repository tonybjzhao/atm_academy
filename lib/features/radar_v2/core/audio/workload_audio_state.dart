import '../cognitive_load/cognitive_load_level.dart';

/// The four workload-driven audio states.
///
/// Each state maps to a distinct layered audio texture:
/// - [calm]       Quiet room ambience, low radio chatter frequency
/// - [busy]       Increased radio density, occasional static bursts
/// - [overload]   Tension pulse underlayer, rapid radio cuts
/// - [saturation] Warning texture, persistent high-frequency urgency tone
enum AudioWorkloadState {
  calm,
  busy,
  overload,
  saturation;

  /// Maps directly from the simulation's cognitive load level.
  static AudioWorkloadState fromLoadLevel(CognitiveLoadLevel level) =>
      switch (level) {
        CognitiveLoadLevel.calm => calm,
        CognitiveLoadLevel.busy => busy,
        CognitiveLoadLevel.overloaded => overload,
        CognitiveLoadLevel.saturated => saturation,
      };

  /// Human-readable label for debug display.
  String get label => switch (this) {
        calm => 'calm',
        busy => 'busy',
        overload => 'overload',
        saturation => 'saturation',
      };
}

/// Descriptor for the audio mix at a given workload state.
///
/// Values are normalised gains [0.0–1.0] for each audio layer.
/// The audio backend reads these each tick to cross-fade between layers.
class AudioLayerMix {
  /// Background ambience gain (e.g. room tone, HVAC hum).
  final double ambienceGain;

  /// Radio chatter density gain (VHF radio texture layer).
  final double radioGain;

  /// Tension underlay gain (low-frequency pulse, rising urgency).
  final double tensionGain;

  /// Warning/saturation texture gain (persistent high-freq urgency layer).
  final double warningGain;

  /// Master cross-fade time in seconds when transitioning to this mix.
  final double crossfadeSeconds;

  const AudioLayerMix({
    required this.ambienceGain,
    required this.radioGain,
    required this.tensionGain,
    required this.warningGain,
    required this.crossfadeSeconds,
  });

  static const calm = AudioLayerMix(
    ambienceGain: 0.6,
    radioGain: 0.15,
    tensionGain: 0.0,
    warningGain: 0.0,
    crossfadeSeconds: 3.0,
  );

  static const busy = AudioLayerMix(
    ambienceGain: 0.4,
    radioGain: 0.5,
    tensionGain: 0.1,
    warningGain: 0.0,
    crossfadeSeconds: 2.5,
  );

  static const overload = AudioLayerMix(
    ambienceGain: 0.2,
    radioGain: 0.7,
    tensionGain: 0.55,
    warningGain: 0.15,
    crossfadeSeconds: 1.5,
  );

  static const saturation = AudioLayerMix(
    ambienceGain: 0.1,
    radioGain: 0.85,
    tensionGain: 0.8,
    warningGain: 0.7,
    crossfadeSeconds: 0.8,
  );

  /// Returns the canonical [AudioLayerMix] for a given [AudioWorkloadState].
  static AudioLayerMix forState(AudioWorkloadState state) => switch (state) {
        AudioWorkloadState.calm => calm,
        AudioWorkloadState.busy => busy,
        AudioWorkloadState.overload => overload,
        AudioWorkloadState.saturation => saturation,
      };

  /// Linearly interpolates between two mixes. Used for smooth transitions.
  static AudioLayerMix lerp(AudioLayerMix a, AudioLayerMix b, double t) {
    double l(double av, double bv) => av + (bv - av) * t;
    return AudioLayerMix(
      ambienceGain: l(a.ambienceGain, b.ambienceGain),
      radioGain: l(a.radioGain, b.radioGain),
      tensionGain: l(a.tensionGain, b.tensionGain),
      warningGain: l(a.warningGain, b.warningGain),
      crossfadeSeconds: l(a.crossfadeSeconds, b.crossfadeSeconds),
    );
  }
}

/// Pure-Dart state machine that tracks the current workload audio state and
/// manages hysteresis so states don't flicker.
///
/// This class has no Flutter or audio-player dependencies — it only produces
/// [AudioLayerMix] values. The actual audio playback is handled separately by
/// [WorkloadAudioController] (in the UI layer).
class WorkloadAudioStateMachine {
  /// Ticks a state must be held before an upgrade is confirmed (prevents
  /// flickering from momentary load spikes).
  static const int _hysteresisTicksUp = 3;

  /// Ticks before a downgrade (allow the system to relax slowly).
  static const int _hysteresisTicksDown = 8;

  AudioWorkloadState _currentState = AudioWorkloadState.calm;
  AudioWorkloadState _pendingState = AudioWorkloadState.calm;
  int _pendingTicks = 0;

  AudioWorkloadState get currentState => _currentState;

  /// Returns the current [AudioLayerMix] for this tick.
  AudioLayerMix get currentMix => AudioLayerMix.forState(_currentState);

  /// Advances the state machine from the latest cognitive load level.
  /// Call once per simulation tick.
  ///
  /// Returns the (possibly unchanged) [AudioWorkloadState].
  AudioWorkloadState tick(CognitiveLoadLevel loadLevel) {
    final target = AudioWorkloadState.fromLoadLevel(loadLevel);

    if (target == _currentState) {
      _pendingTicks = 0;
      _pendingState = _currentState;
      return _currentState;
    }

    if (target != _pendingState) {
      _pendingState = target;
      _pendingTicks = 0;
    } else {
      _pendingTicks++;
    }

    final isUpgrade = target.index > _currentState.index;
    final threshold = isUpgrade ? _hysteresisTicksUp : _hysteresisTicksDown;

    if (_pendingTicks >= threshold) {
      _currentState = target;
      _pendingTicks = 0;
    }

    return _currentState;
  }

  /// Resets to calm (call on scenario restart).
  void reset() {
    _currentState = AudioWorkloadState.calm;
    _pendingState = AudioWorkloadState.calm;
    _pendingTicks = 0;
  }
}
