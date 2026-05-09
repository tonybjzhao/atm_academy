import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class RadioAudioSettings {
  final double voiceVolume;
  final bool warningsEnabled;
  final bool subtitlesEnabled;
  final bool replayAudioEnabled;

  const RadioAudioSettings({
    required this.voiceVolume,
    required this.warningsEnabled,
    required this.subtitlesEnabled,
    required this.replayAudioEnabled,
  });

  static const defaults = RadioAudioSettings(
    voiceVolume: 0.75,
    warningsEnabled: true,
    subtitlesEnabled: true,
    replayAudioEnabled: true,
  );

  RadioAudioSettings copyWith({
    double? voiceVolume,
    bool? warningsEnabled,
    bool? subtitlesEnabled,
    bool? replayAudioEnabled,
  }) {
    return RadioAudioSettings(
      voiceVolume: voiceVolume ?? this.voiceVolume,
      warningsEnabled: warningsEnabled ?? this.warningsEnabled,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      replayAudioEnabled: replayAudioEnabled ?? this.replayAudioEnabled,
    );
  }
}

class RadioAudioSettingsService {
  static const _kVoiceVolume = 'radio.voiceVolume';
  static const _kWarningsEnabled = 'radio.warningsEnabled';
  static const _kSubtitlesEnabled = 'radio.subtitlesEnabled';
  static const _kReplayAudioEnabled = 'radio.replayAudioEnabled';

  RadioAudioSettingsService._();
  static final RadioAudioSettingsService instance =
      RadioAudioSettingsService._();

  final ValueNotifier<RadioAudioSettings> settings =
      ValueNotifier<RadioAudioSettings>(RadioAudioSettings.defaults);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final volume = (prefs.getDouble(_kVoiceVolume) ??
            RadioAudioSettings.defaults.voiceVolume)
        .clamp(0.0, 1.0);
    settings.value = RadioAudioSettings(
      voiceVolume: volume,
      warningsEnabled: prefs.getBool(_kWarningsEnabled) ??
          RadioAudioSettings.defaults.warningsEnabled,
      subtitlesEnabled: prefs.getBool(_kSubtitlesEnabled) ??
          RadioAudioSettings.defaults.subtitlesEnabled,
      replayAudioEnabled: prefs.getBool(_kReplayAudioEnabled) ??
          RadioAudioSettings.defaults.replayAudioEnabled,
    );
    _loaded = true;
  }

  Future<void> update(RadioAudioSettings next) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = next.voiceVolume.clamp(0.0, 1.0);
    await prefs.setDouble(_kVoiceVolume, clamped);
    await prefs.setBool(_kWarningsEnabled, next.warningsEnabled);
    await prefs.setBool(_kSubtitlesEnabled, next.subtitlesEnabled);
    await prefs.setBool(_kReplayAudioEnabled, next.replayAudioEnabled);
    settings.value = next.copyWith(voiceVolume: clamped);
  }

  Future<void> setVoiceVolume(double value) async {
    await update(settings.value.copyWith(voiceVolume: value.clamp(0.0, 1.0)));
  }

  Future<void> setWarningsEnabled(bool enabled) async {
    await update(settings.value.copyWith(warningsEnabled: enabled));
  }

  Future<void> setSubtitlesEnabled(bool enabled) async {
    await update(settings.value.copyWith(subtitlesEnabled: enabled));
  }

  Future<void> setReplayAudioEnabled(bool enabled) async {
    await update(settings.value.copyWith(replayAudioEnabled: enabled));
  }
}
