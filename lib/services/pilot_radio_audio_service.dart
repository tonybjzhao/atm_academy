import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'radio_audio_settings_service.dart';

enum RadioWarningType { conflict, runwayPressure, overloadPeak }

enum _RadioItemKind { pilotAck, warning }

class _QueuedRadioItem {
  final _RadioItemKind kind;
  final DateTime earliestPlayAt;
  final String? callsign;
  final String? text;
  final RadioWarningType? warningType;
  final bool interrupt;

  const _QueuedRadioItem({
    required this.kind,
    required this.earliestPlayAt,
    this.callsign,
    this.text,
    this.warningType,
    this.interrupt = false,
  });
}

class PilotRadioAudioService {
  PilotRadioAudioService._();
  static final PilotRadioAudioService instance = PilotRadioAudioService._();

  static const Duration _cadenceGap = Duration(milliseconds: 280);
  static const Duration _defaultAckDelay = Duration(milliseconds: 320);

  final RadioAudioSettingsService _settings =
      RadioAudioSettingsService.instance;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _warningPlayer = AudioPlayer(playerId: 'radio_warning_sfx');
  final AudioPlayer _immediateCuePlayer =
      AudioPlayer(playerId: 'radio_immediate_cue');
  final ListQueue<_QueuedRadioItem> _queue = ListQueue<_QueuedRadioItem>();
  final ValueNotifier<String?> subtitle = ValueNotifier<String?>(null);

  static const Map<RadioWarningType, String> _warningAsset = {
    RadioWarningType.conflict: 'audio/radio/conflict_warning.wav',
    RadioWarningType.runwayPressure: 'audio/radio/runway_pressure_warning.wav',
    RadioWarningType.overloadPeak: 'audio/radio/overload_peak_warning.wav',
  };

  bool _initialized = false;
  bool _isPlaying = false;
  DateTime _lastPlaybackAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _queueTimer;

  Future<void> initialize() async {
    if (_initialized) return;
    await _settings.ensureLoaded();

    await _tts.setSharedInstance(true);
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(_settings.settings.value.voiceVolume);
    final context = AudioContext(
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
    );
    await _warningPlayer.setAudioContext(context);
    await _immediateCuePlayer.setAudioContext(context);
    await _warningPlayer.setReleaseMode(ReleaseMode.stop);
    await _warningPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _immediateCuePlayer.setReleaseMode(ReleaseMode.stop);
    await _immediateCuePlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _warningPlayer
        .setVolume(_warningVolumeFrom(_settings.settings.value));
    await _immediateCuePlayer
        .setVolume(_warningVolumeFrom(_settings.settings.value));

    _settings.settings.addListener(_onSettingsChanged);
    _initialized = true;
  }

  void _onSettingsChanged() {
    final s = _settings.settings.value;
    _tts.setVolume(s.voiceVolume);
    _warningPlayer.setVolume(_warningVolumeFrom(s));
    _immediateCuePlayer.setVolume(_warningVolumeFrom(s));
    if (!s.subtitlesEnabled) {
      subtitle.value = null;
    }
  }

  /// Play a cue immediately without waiting for queue/TTS state.
  /// This is used by interactive command taps to guarantee audible feedback.
  Future<bool> playImmediateCue(RadioWarningType type) async {
    await initialize();
    final asset = _warningAsset[type];
    if (asset == null) {
      SystemSound.play(SystemSoundType.alert);
      return true;
    }
    try {
      await _immediateCuePlayer.stop();
      await _immediateCuePlayer.play(
        AssetSource(asset),
        volume: _warningVolumeFrom(_settings.settings.value),
      );
      return true;
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
      return false;
    }
  }

  Future<void> enqueuePilotAck({
    required String callsign,
    required String spokenText,
    Duration ackDelay = _defaultAckDelay,
  }) async {
    await initialize();
    final now = DateTime.now();
    final jitter = _voiceJitterFor(callsign);
    final item = _QueuedRadioItem(
      kind: _RadioItemKind.pilotAck,
      earliestPlayAt: now.add(ackDelay + jitter),
      callsign: callsign,
      text: spokenText,
    );
    _queue.add(item);
    _schedulePump();
  }

  Future<void> enqueueWarning(
    RadioWarningType type, {
    bool interrupt = false,
    Duration delay = Duration.zero,
  }) async {
    await initialize();
    if (!_settings.settings.value.warningsEnabled) return;

    final item = _QueuedRadioItem(
      kind: _RadioItemKind.warning,
      earliestPlayAt: DateTime.now().add(delay),
      warningType: type,
      interrupt: interrupt,
    );

    if (interrupt) {
      _queue.removeWhere((e) => e.kind == _RadioItemKind.pilotAck);
      _queue.addFirst(item);
      await _tts.stop();
      subtitle.value = null;
      _isPlaying = false;
    } else {
      _queue.add(item);
    }

    _schedulePump();
  }

  Future<void> clearQueue({bool stopCurrent = false}) async {
    _queue.clear();
    _queueTimer?.cancel();
    if (stopCurrent) {
      await _tts.stop();
      await _warningPlayer.stop();
      _isPlaying = false;
      subtitle.value = null;
    }
  }

  Future<void> dispose() async {
    _queueTimer?.cancel();
    _settings.settings.removeListener(_onSettingsChanged);
    await _tts.stop();
    await _warningPlayer.stop();
    await _warningPlayer.dispose();
    await _immediateCuePlayer.stop();
    await _immediateCuePlayer.dispose();
    subtitle.dispose();
  }

  void _schedulePump() {
    _queueTimer?.cancel();
    _pumpQueue();
  }

  void _pumpQueue() {
    if (_isPlaying || _queue.isEmpty) return;
    final now = DateTime.now();
    final earliest = _queue.first.earliestPlayAt;
    final cadenceReady = now.isAfter(_lastPlaybackAt.add(_cadenceGap));

    if (now.isBefore(earliest) || !cadenceReady) {
      final waitA = earliest.difference(now);
      final waitB = _lastPlaybackAt.add(_cadenceGap).difference(now);
      final wait = Duration(
          milliseconds:
              max(20, max(waitA.inMilliseconds, waitB.inMilliseconds)));
      _queueTimer = Timer(wait, _pumpQueue);
      return;
    }

    final next = _queue.removeFirst();
    _play(next);
  }

  Future<void> _play(_QueuedRadioItem item) async {
    _isPlaying = true;
    if (item.kind == _RadioItemKind.warning) {
      await _playWarning(item.warningType!);
      _lastPlaybackAt = DateTime.now();
      _isPlaying = false;
      _pumpQueue();
      return;
    }

    final text = item.text ?? '';
    final callsign = item.callsign ?? '';
    if (text.isEmpty) {
      _isPlaying = false;
      _pumpQueue();
      return;
    }

    await _applyVoiceProfile(callsign);
    if (_settings.settings.value.subtitlesEnabled) {
      subtitle.value = text;
    }

    try {
      final estimated = _estimateSpeechDuration(text);
      await _tts.speak(text).timeout(estimated + const Duration(seconds: 1));
    } catch (_) {
      // If TTS backend does not report completion consistently, continue queue.
    } finally {
      subtitle.value = null;
      _lastPlaybackAt = DateTime.now();
      _isPlaying = false;
      _pumpQueue();
    }
  }

  Future<void> _applyVoiceProfile(String callsign) async {
    final seed = callsign.hashCode.abs() % 3;
    switch (seed) {
      case 0:
        await _tts.setPitch(0.92);
        await _tts.setSpeechRate(0.44);
        break;
      case 1:
        await _tts.setPitch(1.00);
        await _tts.setSpeechRate(0.47);
        break;
      default:
        await _tts.setPitch(1.08);
        await _tts.setSpeechRate(0.50);
        break;
    }
    await _tts.setVolume(_settings.settings.value.voiceVolume);
  }

  Future<void> _playWarning(RadioWarningType type) async {
    if (!_settings.settings.value.warningsEnabled) return;
    final asset = _warningAsset[type];
    if (asset == null) {
      SystemSound.play(SystemSoundType.alert);
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<void> sub;
    sub = _warningPlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      sub.cancel();
    });

    try {
      await _warningPlayer.play(
        AssetSource(asset),
        volume: _warningVolumeFrom(_settings.settings.value),
      );
      await completer.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    } finally {
      await sub.cancel();
    }
  }

  double _warningVolumeFrom(RadioAudioSettings s) {
    return (0.22 + (s.voiceVolume * 0.55)).clamp(0.0, 1.0);
  }

  Duration _voiceJitterFor(String callsign) {
    final ms = 50 + (callsign.hashCode.abs() % 170);
    return Duration(milliseconds: ms);
  }

  Duration _estimateSpeechDuration(String text) {
    final words =
        text.trim().isEmpty ? 1 : text.trim().split(RegExp(r'\s+')).length;
    final ms = 260 + (words * 320);
    return Duration(milliseconds: ms.clamp(500, 7000));
  }
}
