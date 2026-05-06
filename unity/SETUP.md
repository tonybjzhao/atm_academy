# Unity ATM Replay — Setup Guide

## Overview

The `ATMReplay` Unity project provides a lightweight 3D scenario replay viewer.
Flutter remains the source of truth for all game logic, lessons, and scoring.
Unity only handles visual replay — it receives data from Flutter and returns control when done.

## Prerequisites

| Tool | Version |
|---|---|
| Unity Editor | 2022.3 LTS (recommended) |
| flutter_unity_widget | 2022.2.1+ |
| TextMeshPro | included (via manifest.json) |

---

## Step 1 — Open the Unity project

1. Open Unity Hub → Add project from disk → select `unity/ATMReplay`
2. Unity will import packages automatically (TextMeshPro prompt — click "Import TMP Essentials")

---

## Step 2 — Create the scene

Create a new scene `Assets/Scenes/ReplayScene.unity`:

### Camera
- Select Main Camera → Add Component → `ReplayCameraController`
- Set Look Target to the ScenarioReplayManager GameObject (below)

### ScenarioReplayManager
- Create empty GameObject named exactly **`ScenarioReplayManager`** (must match the name in Flutter's postMessage call)
- Add Component → `ScenarioReplayManager`
- Assign `aircraftPrefab` and `pathRendererPrefab` (see Step 3)

### Camera (cinematic orbit)
- Select Main Camera → Add Component → `CinematicReplayCamera`
- Set **Target** to the ScenarioReplayManager GameObject (drag into Inspector)
- Recommended Inspector values:
  - Orbit Radius: 10  |  Orbit Height: 5  |  Orbit Speed: 14
  - Zoom In Radius: 7  |  Intro Duration: 1.8
  - Outro Start Pct: 0.75  |  Outro End Radius: 11
- `BeginReplay()` is called automatically by ScenarioReplayManager — no extra wiring needed

### Radar floor
- `RadarFloor` is spawned **automatically at runtime** by ScenarioReplayManager.Awake()
  so no manual scene object is required.
- To customise ring colours or count, add a `RadarFloor` component to any
  empty GameObject *before* play and ScenarioReplayManager will skip auto-spawn.

### Environment
- Add a Directional Light (set intensity 0.6, angle ~45°)
- Skybox: Window → Rendering → Lighting → Environment → set Skybox to a dark
  solid colour (e.g. `Color(0.02, 0.04, 0.06)`) for the radar night look

---

## Step 3 — Create prefabs

### AircraftPrefab
1. Create → 3D Object → Cylinder (or import a simple aircraft .fbx)
2. Scale: (0.2, 0.05, 0.4)
3. Add Component → `AircraftController`
4. Create a child empty named "Label" → add TextMeshPro - World component
5. Assign `modelTransform` and `labelText` in Inspector
6. Save as `Assets/Prefabs/AircraftPrefab.prefab`

### PathRendererPrefab
1. Create empty GameObject
2. Add Component → `PathRenderer`
3. Add a LineRenderer (PathRenderer will configure it at runtime)
4. Create a simple unlit material with vertex colour support
5. Save as `Assets/Prefabs/PathRendererPrefab.prefab`

---

## Step 4 — flutter_unity_widget integration

### pubspec.yaml
```yaml
dependencies:
  flutter_unity_widget: ^2022.2.1
```

### Flutter
In `lib/screens/unity_replay_screen.dart`:
1. Set `const bool kUnityEnabled = true;`
2. Uncomment the `_UnityView` class (remove the stub at the bottom)
3. Uncomment `import 'package:flutter_unity_widget/flutter_unity_widget.dart';`

### iOS
Export Unity project: File → Build Settings → iOS → Export
Copy exported folder to `ios/UnityFramework/`
Follow flutter_unity_widget iOS integration guide:
https://pub.dev/packages/flutter_unity_widget#ios-1

### Android
Export Unity project: File → Build Settings → Android → Export Project
Copy exported folder to `android/unityLibrary/`
Follow flutter_unity_widget Android integration guide:
https://pub.dev/packages/flutter_unity_widget#android-1

---

## Step 5 — Test

Run Flutter, complete a scenario, tap "Watch 3D Replay".

The Flutter side sends:
```
controller.postMessage(
  "ScenarioReplayManager",   // matches the Unity GameObject name exactly
  "LoadReplayData",          // method on ScenarioReplayManager
  replayData.toJson()        // JSON payload
)
```

Unity receives the JSON, spawns aircraft, plays 6-second replay, then sends:
```
SendMessageUpwards("OnUnityMessage", "REPLAY_COMPLETE")
```

Flutter receives `REPLAY_COMPLETE` and pops the screen.

---

## Data format sent from Flutter

```json
{
  "scenarioId": "basic_crossing_same_level",
  "scenarioTitle": "Crossing Traffic at Same Level",
  "initialAircraft": [
    { "callsign": "QFA123", "x": 60, "y": 210, "heading": 90, "speed": 0.8, "altitude": 320, "wasSelected": true, "wasConflicting": false },
    { "callsign": "UAE406", "x": 310, "y": 210, "heading": 270, "speed": 0.8, "altitude": 320, "wasSelected": false, "wasConflicting": false }
  ],
  "finalAircraft": [
    { "callsign": "QFA123", "x": 185, "y": 165, "heading": 75, "speed": 0.8, "altitude": 320, "wasSelected": true, "wasConflicting": false },
    { "callsign": "UAE406", "x": 222, "y": 205, "heading": 270, "speed": 0.8, "altitude": 320, "wasSelected": false, "wasConflicting": false }
  ],
  "minHorizDist": 68.4,
  "hadLOS": false,
  "score": 105,
  "ratingKey": "ratingExcellent"
}
```

---

## Coordinate mapping

Flutter radar space: `x: 0–370, y: 0–430` (origin top-left, Y down)

Unity world space (XZ plane, Y = altitude):
```
wx = (flutterX - 185) / coordScale
wz = (flutterY - 215) / coordScale
wy = (flightLevel - 250) * 0.02
```

`coordScale` defaults to 40. Adjust in ScenarioReplayManager Inspector to change scene scale.

---

## Content note

This Unity project uses generic radar/aviation visuals only.
No proprietary Thales UI, data, or procedures are included or implied.
The replay is a simplified educational visualisation, not an operational ATC system.
