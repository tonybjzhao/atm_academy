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

class RadioAudioSelfTestResult {
  final bool cueOk;
  final bool voiceOk;
  final bool ttsAvailable;
  final String detail;

  const RadioAudioSelfTestResult({
    required this.cueOk,
    required this.voiceOk,
    required this.ttsAvailable,
    required this.detail,
  });

  bool get ok => cueOk || voiceOk;
}

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
  bool _ttsAvailable = false;
  bool _isPlaying = false;
  DateTime _lastPlaybackAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _queueTimer;

  Future<void> initialize() async {
    if (_initialized) return;
    await _settings.ensureLoaded();

    try {
      await _tts.setSharedInstance(true);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setQueueMode(1);
      }
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(1.0);
      await _tts.setVolume(_settings.settings.value.voiceVolume);
      _ttsAvailable = true;
      debugPrint('AUDIO_PROBE_RADIO tts init ok');
    } catch (e) {
      // Some Android devices have flaky TTS engines; keep SFX path working.
      _ttsAvailable = false;
      debugPrint('AUDIO_PROBE_RADIO tts init failed: $e');
    }
    final context = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {},
      ),
      android: AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
        isSpeakerphoneOn: true,
      ),
    );
    await _warningPlayer.setAudioContext(context);
    await _immediateCuePlayer.setAudioContext(context);
    await _warningPlayer.setReleaseMode(ReleaseMode.stop);
    await _warningPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _immediateCuePlayer.setReleaseMode(ReleaseMode.stop);
    await _immediateCuePlayer.setPlayerMode(PlayerMode.lowLatency);
    await _warningPlayer
        .setVolume(_warningVolumeFrom(_settings.settings.value));
    await _immediateCuePlayer.setVolume(1.0);

    _settings.settings.addListener(_onSettingsChanged);
    _initialized = true;
    debugPrint(
      'AUDIO_PROBE_RADIO init done tts=$_ttsAvailable volume=${_settings.settings.value.voiceVolume}',
    );
  }

  void _onSettingsChanged() {
    final s = _settings.settings.value;
    if (_ttsAvailable) {
      _tts.setVolume(s.voiceVolume);
    }
    _warningPlayer.setVolume(_warningVolumeFrom(s));
    _immediateCuePlayer.setVolume(1.0);
    if (!s.warningsEnabled) {
      unawaited(clearQueue(stopCurrent: true));
    }
    if (!s.subtitlesEnabled || !s.warningsEnabled) {
      subtitle.value = null;
    }
  }

  /// Play a cue immediately without waiting for queue/TTS state.
  /// This is used by interactive command taps to guarantee audible feedback.
  Future<bool> playImmediateCue(
    RadioWarningType type, {
    bool respectSettings = true,
  }) async {
    await initialize();
    if (respectSettings && !_settings.settings.value.warningsEnabled) {
      debugPrint('AUDIO_PROBE_RADIO cue skipped audio muted');
      return false;
    }
    final asset = _warningAsset[type];
    if (asset == null) {
      SystemSound.play(SystemSoundType.alert);
      return true;
    }
    try {
      await _immediateCuePlayer.stop().timeout(
            const Duration(milliseconds: 350),
            onTimeout: () {},
          );
      await _immediateCuePlayer
          .play(
            AssetSource(asset),
            volume: 1.0,
          )
          .timeout(const Duration(milliseconds: 900));
      debugPrint('AUDIO_PROBE_RADIO cue ok asset=$asset');
      return true;
    } catch (e) {
      debugPrint('AUDIO_PROBE_RADIO cue failed asset=$asset error=$e');
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Ignore fallback failure.
      }
      return false;
    }
  }

  Future<RadioAudioSelfTestResult> runSelfTest() async {
    await initialize();
    if (!_settings.settings.value.warningsEnabled) {
      await clearQueue(stopCurrent: true);
      return const RadioAudioSelfTestResult(
        cueOk: false,
        voiceOk: false,
        ttsAvailable: false,
        detail: 'audio muted',
      );
    }
    final cueOk = await playImmediateCue(RadioWarningType.conflict);
    var voiceOk = false;
    var detail = _ttsAvailable ? 'tts available' : 'tts unavailable';

    if (_ttsAvailable && _settings.settings.value.voiceVolume > 0) {
      try {
        await _applyVoiceProfile('QFA214');
        const text = 'QFA214 radio check';
        if (_settings.settings.value.subtitlesEnabled) {
          subtitle.value = text;
        }
        await _tts.speak(text).timeout(const Duration(seconds: 4));
        voiceOk = true;
        detail = 'voice spoken';
      } catch (e) {
        detail = 'voice failed: $e';
        debugPrint('AUDIO_PROBE_RADIO voice self-test failed: $e');
      } finally {
        subtitle.value = null;
      }
    } else if (_settings.settings.value.voiceVolume <= 0) {
      detail = 'voice volume is zero';
    }

    debugPrint(
      'AUDIO_PROBE_RADIO selfTest cue=$cueOk voice=$voiceOk tts=$_ttsAvailable detail=$detail',
    );
    return RadioAudioSelfTestResult(
      cueOk: cueOk,
      voiceOk: voiceOk,
      ttsAvailable: _ttsAvailable,
      detail: detail,
    );
  }

  Future<void> enqueuePilotAck({
    required String callsign,
    required String spokenText,
    Duration ackDelay = _defaultAckDelay,
    bool respectSettings = true,
  }) async {
    await initialize();
    final settings = _settings.settings.value;
    if ((respectSettings && !settings.warningsEnabled) ||
        settings.voiceVolume <= 0) {
      debugPrint(
        'AUDIO_PROBE_RADIO pilot ack skipped callsign=$callsign muted=${!settings.warningsEnabled} volume=${settings.voiceVolume}',
      );
      return;
    }
    final now = DateTime.now();
    final jitter = _voiceJitterFor(callsign);
    final item = _QueuedRadioItem(
      kind: _RadioItemKind.pilotAck,
      earliestPlayAt: now.add(ackDelay + jitter),
      callsign: callsign,
      text: spokenText,
    );
    _queue.add(item);
    debugPrint(
      'AUDIO_PROBE_RADIO pilot ack queued callsign=$callsign text=$spokenText',
    );
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
      if (_ttsAvailable) {
        await _tts.stop();
      }
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
      if (_ttsAvailable) {
        await _tts.stop();
      }
      await _warningPlayer.stop();
      _isPlaying = false;
      subtitle.value = null;
    }
  }

  Future<void> dispose() async {
    _queueTimer?.cancel();
    _settings.settings.removeListener(_onSettingsChanged);
    if (_ttsAvailable) {
      await _tts.stop();
    }
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
      await _speakWarning(item.warningType!);
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

    if (!_ttsAvailable) {
      // TTS unavailable: keep queue flowing and still provide an audible cue.
      await playImmediateCue(RadioWarningType.runwayPressure);
      _lastPlaybackAt = DateTime.now();
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
      debugPrint('AUDIO_PROBE_RADIO pilot voice start callsign=$callsign');
      await _tts.speak(text).timeout(estimated + const Duration(seconds: 1));
      debugPrint('AUDIO_PROBE_RADIO pilot voice ok callsign=$callsign');
    } catch (e) {
      // If TTS backend does not report completion consistently, continue queue.
      debugPrint(
        'AUDIO_PROBE_RADIO pilot voice failed callsign=$callsign error=$e',
      );
    } finally {
      subtitle.value = null;
      _lastPlaybackAt = DateTime.now();
      _isPlaying = false;
      _pumpQueue();
    }
  }

  Future<void> _applyVoiceProfile(String callsign) async {
    if (!_ttsAvailable) return;
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

  Future<void> _speakWarning(RadioWarningType type) async {
    if (!_ttsAvailable || _settings.settings.value.voiceVolume <= 0) return;
    final text = _warningText(type);
    try {
      await _applyVoiceProfile('RADIO');
      if (_settings.settings.value.subtitlesEnabled) {
        subtitle.value = text;
      }
      debugPrint('AUDIO_PROBE_RADIO warning voice start type=$type');
      await _tts
          .speak(text)
          .timeout(_estimateSpeechDuration(text) + const Duration(seconds: 1));
      debugPrint('AUDIO_PROBE_RADIO warning voice ok type=$type');
    } catch (e) {
      debugPrint('AUDIO_PROBE_RADIO warning voice failed type=$type error=$e');
    } finally {
      subtitle.value = null;
    }
  }

  String _warningText(RadioWarningType type) {
    switch (type) {
      case RadioWarningType.conflict:
        return 'Traffic alert. Check separation.';
      case RadioWarningType.runwayPressure:
        return 'Runway pressure building. Check arrival spacing.';
      case RadioWarningType.overloadPeak:
        return 'Workload critical. Prioritize active conflicts.';
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
