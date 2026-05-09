import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../features/radar_v2/core/audio/workload_audio_state.dart';
import '../features/radar_v2/core/cognitive_load/cognitive_load_level.dart';

/// Flutter-side controller that drives workload audio based on [AudioWorkloadState].
///
/// Uses [AudioPlayer] from audioplayers package for reliable cross-platform
/// audio playback. Plays warning sounds and sweep cues with proper Android
/// audio initialization.
///
/// Usage:
/// ```dart
/// final audio = WorkloadAudioController();
/// await audio.initialize(); // call once at startup
/// audio.tick(snapshot.cognitiveLoad.currentLevel); // call each tick
/// audio.dispose();
/// ```
class WorkloadAudioController {
  final WorkloadAudioStateMachine _machine = WorkloadAudioStateMachine();
  late final AudioPlayer _player;
  Future<void> _playbackChain = Future<void>.value();
  bool _initialized = false;

  WorkloadAudioController() {
    _player = AudioPlayer();
  }

  /// Initialize audio player — must be called before tick() on Android.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {},
          ),
          android: AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            isSpeakerphoneOn: true,
          ),
        ),
      );
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      _initialized = true;
    } catch (e) {
      assert(() {
        print('WorkloadAudioController: Failed to initialize: $e');
        return true;
      }());
    }
  }

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
    _playAsset('audio/radio/conflict_warning.wav');
  }

  /// Resets to calm state (call on scenario restart).
  void reset() => _machine.reset();

  void dispose() {
    _player.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _onStateChanged(AudioWorkloadState from, AudioWorkloadState to) {
    final isEscalation = to.index > from.index;
    if (isEscalation && to == AudioWorkloadState.saturation) {
      // Saturation entry: play alert tone
      _playAsset('audio/radio/overload_peak_warning.wav');
    }
    // Future: trigger cross-fade on layered audio tracks here
  }

  void _playAsset(String assetPath) {
    if (!_initialized) return;
    _playbackChain = _playbackChain.then((_) => _playAssetInternal(assetPath));
  }

  Future<void> _playAssetInternal(String assetPath) async {
    try {
      // Reset before each cue to keep Android replaying the same asset reliably.
      await _player.stop();
      await _player.play(AssetSource(assetPath), volume: 1.0);
    } catch (e) {
      assert(() {
        print('WorkloadAudioController: Failed to play $assetPath: $e');
        return true;
      }());
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Ignore fallback failure.
      }
    }
  }
}
