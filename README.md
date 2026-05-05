# ATM Academy

A multilingual **Air Traffic Management learning + micro-simulation** app built with Flutter.

Designed for aviation enthusiasts, students, and ATM professionals who want to learn ATC concepts in an interactive, accessible way — on iOS and Android.

> **Safety notice:** This app is for general education only. It is not an operational ATC system and must not be used for real-world decision-making.

---

## Features

### Learning
- **10 structured lessons** across 4 levels — Beginner, Intermediate, Advanced, Expert
- Topics: What is ATM, Airspace Basics, Radar, Separation, Runway Operations, ATC Phraseology, Flight Phases, Conflict Awareness, Tower/Approach/En-route, Future ATM & Automation
- Animated teaching headers (radar sweep, runway flow, separation demo, comms pulse)
- Key points summary per lesson

### Quiz
- 3 questions per lesson with animated correct/incorrect feedback
- Explanation shown after each answer
- Score results screen

### Radar Simulation
- Live 2D radar with 4 aircraft tracks
- Rotating sweep line, range rings, conflict detection
- Tap to select an aircraft — issue heading, altitude, and speed commands
- Conflict alert when aircraft come too close

### Multilingual
- English, 中文 (Simplified Chinese), Français
- System default language support
- Switchable at runtime from the language settings screen
- Built on Flutter official i18n (flutter_localizations + ARB + gen_l10n)

### Other
- Contribute screen — invite co-workers to suggest lessons, quizzes, and scenarios
- Safety & compliance disclaimer
- Dark radar-style theme throughout

---

## Screenshots

> _Add screenshots here once available._

---

## Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Flutter | 3.x (stable) |
| Dart | 3.x |
| Xcode | 15+ (for iOS) |
| Android Studio / SDK | API 21+ (for Android) |

### Clone and run

```bash
git clone https://github.com/tonybjzhao/atm_academy.git
cd atm_academy
flutter pub get
flutter gen-l10n
flutter run
```

### Run on a specific device

```bash
# List available devices
flutter devices

# Run on iOS simulator
flutter run -d <device-id>

# Run on Android emulator
flutter run -d <emulator-id>
```

### Build for release

```bash
# iOS (requires Apple Developer account)
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

---

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── core/
│   ├── models/
│   │   ├── lesson.dart           # Lesson + AnimationType + LessonLevel
│   │   ├── localized_text.dart   # Trilingual string container (EN/ZH/FR)
│   │   ├── quiz_question.dart    # Quiz question model
│   │   └── aircraft.dart         # Aircraft state for radar sim
│   └── theme/
│       └── app_theme.dart        # Dark radar theme (Material 3)
├── data/
│   └── lessons_data.dart         # 10 lessons with inline EN/ZH/FR content
├── l10n/
│   ├── app_en.arb                # English strings
│   ├── app_zh.arb                # Chinese strings
│   ├── app_fr.arb                # French strings
│   └── l10n_extensions.dart      # context.l10n shorthand
├── screens/
│   ├── home_screen.dart
│   ├── lessons_screen.dart
│   ├── lesson_detail_screen.dart
│   ├── radar_simulation_screen.dart
│   ├── quiz_screen.dart
│   ├── contribute_screen.dart
│   ├── about_safety_screen.dart
│   └── language_settings_screen.dart
├── services/
│   └── language_service.dart     # Locale persistence (SharedPreferences)
└── widgets/
    ├── atm_card.dart
    ├── control_panel_light.dart
    ├── radar_sweep_animation.dart
    ├── runway_flow_animation.dart
    ├── separation_demo_animation.dart
    ├── comms_pulse_animation.dart
    └── radar_painter.dart
```

---

## Adding a New Language

1. Create `lib/l10n/app_XX.arb` (copy `app_en.arb` as template)
2. Add `Locale('XX')` to `supportedLocales` in `main.dart`
3. Add the language option to `language_settings_screen.dart`
4. Run `flutter gen-l10n`

---

## Contributing

Built by ATM engineers. Contributions from the aviation and ATM community are welcome.

**Ways to contribute:**
- Suggest a new lesson topic
- Improve or add quiz questions
- Design a radar simulation scenario
- Translate to a new language
- Report inaccuracies in ATM content

<!-- TODO: Replace with actual repo URL once published to app stores -->
**Repo:** https://github.com/tonybjzhao/atm_academy

<!-- TODO: Replace with team contact email -->
**Contact:** atm.academy@in5km.com

All contributions must use publicly available, generic ATM/ATC knowledge only. No proprietary, confidential, or restricted information.

---

## Compliance

- Content is based on publicly available ICAO, EUROCONTROL, and FAA materials
- No proprietary ATM system vendor information is included
- This app does not provide or imply official ATC training or certification
- For official ATC training, consult your national aviation authority or an approved training organisation

---

## License

<!-- TODO: Add licence file -->
To be determined.
