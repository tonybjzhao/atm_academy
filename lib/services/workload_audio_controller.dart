import 'package:flutter/services.dart';

import '../features/radar_v2/core/audio/workload_audio_state.dart';
import '../features/radar_v2/core/cognitive_load/cognitive_load_level.dart';

/// Flutter-side controller that drives workload audio based on [AudioWorkloadState].
///
/// Currently uses only [SystemSound] for one-shot alerts (no external audio
/// package needed). When audio assets are added in a future sprint, this class
/// gains a proper multi-layer playback implementation without changing the
/// state-machine contract.
///
/// Usage:
/// ```dart
/// final audio = WorkloadAudioController();
/// audio.tick(snapshot.cognitiveLoad.currentLevel); // call each tick
/// audio.dispose();
/// ```
class WorkloadAudioController {
  final WorkloadAudioStateMachine _machine = WorkloadAudioStateMachine();

  AudioWorkloadState get currentState => _machine.currentState;
  AudioLayerMix get currentMix => _machine.currentMix;

  /// Advances the audio state machine and plays any state-transition effects.
  ///
  /// Call once per rendered simulation tick.
  void tick(CognitiveLoadLevel loadLevel) {
    final previous = _machine.currentState;
    final next = _machine.tick(loadLevel);

    if (next != previous) {
      _onStateChanged(previous, next);
    }
  }

  /// Plays a one-shot alert chime for a newly registered critical alert.
  /// Safe to call from the UI tick loop.
  void playCriticalAlertCue() {
    // SystemSound.play can be extended to a custom asset when audioplayers
    // is added.  For now it plays the system alert tone.
    SystemSound.play(SystemSoundType.alert);
  }

  /// Resets to calm state (call on scenario restart).
  void reset() => _machine.reset();

  /// No-op for now — reserved for future audio engine teardown.
  void dispose() {}

  // ── Private ───────────────────────────────────────────────────────────────

  void _onStateChanged(AudioWorkloadState from, AudioWorkloadState to) {
    final isEscalation = to.index > from.index;
    if (isEscalation && to == AudioWorkloadState.saturation) {
      // Saturation entry: play alert tone
      SystemSound.play(SystemSoundType.alert);
    }
    // Future: trigger cross-fade on layered audio tracks here
  }
}
