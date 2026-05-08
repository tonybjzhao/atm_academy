# ATM Academy V2 Roadmap

Status: draft for V2 development  
Branch: `feature/v2-radar-engine`  
V1 rule: do not refactor or destabilize the submitted App Store / Play Store release flow.

## Goals

V2 should make ATM Academy feel more alive, repeatable, and worth returning to. The main product direction is:

- Realism: aircraft move continuously, conflicts are computed, and controller actions have believable consequences.
- Replayability: scenarios are data-driven, varied, and scalable by difficulty.
- Retention: progress, ranks, replay review, and career structure give players reasons to improve.

## Release Guardrails

- Keep V1 releasable from the current stable release/tag path.
- Do V2 implementation on `feature/v2-radar-engine` or later V2 branches.
- Put any V2 entry points behind feature flags until stable.
- Prefer additive modules over changing existing V1 screens in place.
- Keep Flutter-native radar rendering as the default path.
- Avoid Unity dependency for core V2 gameplay unless a later prototype proves it is necessary.

Recommended feature flags:

```dart
const bool kRadarEngineV2Enabled = false;
const bool kScenarioEngineV2Enabled = false;
const bool kReplayEngineV2Enabled = false;
const bool kAudioPhraseologyEnabled = false;
```

## Architecture Proposal

V2 should separate simulation state, rendering, commands, scoring, and replay. The radar screen should become a thin composition layer that subscribes to engine state and sends controller commands.

Core modules:

- Scenario engine: loads JSON scenario definitions, spawns aircraft, applies difficulty rules, and evaluates win/fail conditions.
- Simulation engine: advances aircraft each tick, updates positions, computes predicted paths, and detects separation risk.
- Command engine: validates and applies controller commands to aircraft intent.
- Radar renderer: draws aircraft, tracks, labels, vectors, predicted conflict points, and sector overlays.
- Replay engine: records ticks, commands, conflicts, scoring events, and explanations.
- Progression engine: manages XP, rank, career stage, unlocks, and challenge completion.
- Audio phraseology engine: generates or plays ATC/pilot phrases and validates command phrase structure.

Data flow:

```text
Scenario JSON
  -> ScenarioEngine
  -> SimulationEngine tick stream
  -> RadarRenderer view model
  -> ControllerCommandEngine
  -> ReplayRecorder + ScoringEngine
  -> ProgressionEngine
```

## Proposed File Structure

```text
lib/
  features/
    radar_v2/
      radar_v2_screen.dart
      radar_v2_feature_flags.dart
      engine/
        simulation_clock.dart
        simulation_engine.dart
        separation_calculator.dart
        conflict_predictor.dart
        trajectory_integrator.dart
      scenario/
        scenario_engine.dart
        scenario_loader.dart
        scenario_validator.dart
        scenario_runtime.dart
      commands/
        controller_command.dart
        command_parser.dart
        command_validator.dart
        command_executor.dart
      rendering/
        radar_canvas.dart
        radar_painter.dart
        radar_view_model.dart
        sector_overlay_painter.dart
      replay/
        replay_recorder.dart
        replay_timeline.dart
        replay_analyzer.dart
        replay_player.dart
      scoring/
        scoring_engine.dart
        scoring_events.dart
        mistake_explainer.dart
      audio/
        phraseology_catalog.dart
        phrase_builder.dart
        phrase_validator.dart
        voice_playback_service.dart
      progression/
        career_stage.dart
        progression_v2_service.dart
        rank_model.dart
      models/
        aircraft_state.dart
        aircraft_intent.dart
        route_model.dart
        waypoint_model.dart
        sector_model.dart
        scenario_definition.dart
        simulation_event.dart
assets/
  scenarios/v2/
    melbourne/
    sydney/
    singapore/
    heathrow/
  audio/phraseology/
test/
  radar_v2/
    engine/
    scenario/
    commands/
    scoring/
```

## Phase Plan

### Phase 0: Safety Baseline

Deliverables:

- Add V2 feature flags.
- Add empty V2 module structure.
- Add scenario JSON schema draft.
- Add engine unit test harness.
- Keep V1 screen as default.

Exit criteria:

- App launches exactly like V1 when all V2 flags are false.
- No review/release metadata changes.
- CI or local tests cover new pure Dart engine utilities.

### Phase 1: Real Moving Aircraft Trajectories

Scope:

- Aircraft continuously move on radar.
- Tick/update engine with fixed simulation time step.
- Configurable simulation speed: pause, 1x, 2x, 4x.
- Velocity vectors from heading, ground speed, and vertical speed.
- Separation calculations for lateral and vertical separation.
- Predicted conflict point and time-to-conflict.

Recommended approach:

- Use a pure Dart `SimulationEngine` with immutable tick snapshots.
- Keep units explicit: nautical miles, feet, knots, seconds.
- Start with flat-earth local coordinates for mobile performance and clarity.
- Add geodesic conversion later for sector realism.

Key models:

```dart
class AircraftState {
  final String id;
  final String callsign;
  final double xNm;
  final double yNm;
  final int altitudeFt;
  final double headingDeg;
  final double groundSpeedKt;
  final int verticalSpeedFpm;
  final AircraftIntent intent;
}

class SeparationResult {
  final String aircraftAId;
  final String aircraftBId;
  final double lateralNm;
  final int verticalFt;
  final bool isLossOfSeparation;
  final bool isPredictedConflict;
  final Duration? timeToConflict;
}
```

Risks:

- Overly realistic geometry can slow early delivery.
- Visual clutter can hurt mobile usability.

### Phase 2: Radar Scenario Engine V2

Scope:

- JSON-driven scenarios.
- Dynamic aircraft spawning.
- Difficulty scaling.
- Win/fail conditions.
- Time pressure system.
- Progressive complexity.

Scenario JSON draft:

```json
{
  "id": "melbourne_approach_001",
  "title": "Crossing Arrivals",
  "sectorId": "melbourne_approach",
  "durationSeconds": 480,
  "difficulty": 2,
  "speedOptions": [1, 2, 4],
  "aircraft": [
    {
      "callsign": "QFA214",
      "spawnAtSeconds": 0,
      "position": { "xNm": -28, "yNm": 12 },
      "altitudeFt": 9000,
      "headingDeg": 120,
      "groundSpeedKt": 250,
      "route": ["MLB_WEST", "MLB_BASE", "RWY27"]
    }
  ],
  "winConditions": [
    { "type": "allAircraftExitSafely" },
    { "type": "maxSeparationLosses", "value": 0 }
  ],
  "failConditions": [
    { "type": "separationLoss" },
    { "type": "timeout" }
  ]
}
```

Risks:

- JSON flexibility can become hard to validate.
- Difficulty scaling needs telemetry or careful playtesting.

### Phase 3: Controller Command System

Scope:

- Heading commands.
- Speed commands.
- Altitude commands.
- Hold commands.
- Direct-to waypoint commands.
- Temporary restrictions.

Command model:

```dart
sealed class ControllerCommand {
  String get aircraftId;
  Duration get issuedAt;
}

class AssignHeading extends ControllerCommand {
  final int headingDeg;
}

class AssignAltitude extends ControllerCommand {
  final int altitudeFt;
}

class DirectToWaypoint extends ControllerCommand {
  final String waypointId;
}
```

UX recommendation:

- Mobile-first command panel with quick controls.
- Avoid typing as the primary control path.
- Later add phraseology input as optional advanced mode.

Risks:

- Too many command types can overwhelm new users.
- Command latency and turn/climb behavior must feel predictable.

### Phase 4: Scoring And Replay Engine

Scope:

- Timeline replay.
- Mistake explanation.
- Separation loss analysis.
- Command efficiency scoring.
- XP/rank integration.

Replay data model:

```dart
class ReplayTimeline {
  final String scenarioId;
  final Duration duration;
  final List<SimulationSnapshot> snapshots;
  final List<ControllerCommand> commands;
  final List<ScoringEvent> scoringEvents;
  final List<SeparationResult> separationEvents;
}
```

Scoring dimensions:

- Safety: no separation loss, early conflict resolution.
- Efficiency: minimal unnecessary vectors, speed changes, and altitude changes.
- Stability: avoids late or repeated corrective commands.
- Timeliness: issues commands before conflict alerts become urgent.

Risks:

- Replay storage can grow quickly if every tick is persisted.
- Scoring must explain itself or users will distrust it.

### Phase 5: Audio Phraseology System

Scope:

- ATC voice playback.
- Synthetic pilot readback.
- Phrase validation.
- Optional subtitles.

Recommended approach:

- Start with generated phrase text plus subtitles.
- Add local audio assets for common phrases.
- Consider platform TTS for pilot readback only after UX testing.

Risks:

- Audio can increase app size.
- Phrase validation can become brittle across accents and abbreviations.

### Phase 6: Sector Realism

Initial sectors:

- Melbourne.
- Sydney.
- Singapore.
- Heathrow.

Scope:

- Basic sector boundaries.
- Common approach/departure flow concepts.
- Basic STAR/SID route concepts without claiming operational fidelity.
- Generic educational waypoints where needed.

Compliance note:

- Keep all sector data educational and simplified.
- Do not imply operational ATC accuracy.
- Avoid restricted, proprietary, or live operational data.

Risks:

- Real airport names increase user expectations.
- Over-specific route data may create review or licensing concerns.

### Phase 7: Career Progression

Career stages:

- Cadet.
- Tower.
- Approach.
- Enroute.
- Supervisor challenges.

Retention mechanics:

- Daily scenario challenge.
- XP and rank progression.
- Scenario mastery badges.
- Replay-based coaching.
- Unlockable sectors and challenge types.

Risks:

- Progression should reward skill, not grind.
- Avoid making early learning feel punitive.

## Recommended Packages

Core:

- `json_serializable` and `build_runner` for scenario/data model parsing.
- `freezed` for immutable engine state if code generation is acceptable.
- `equatable` if a lighter model approach is preferred.
- `collection` for sorted event timelines and utilities.

Rendering:

- Flutter `CustomPainter` first.
- `vector_math` for geometry utilities if needed.

Audio:

- `just_audio` for local phrase playback.
- `flutter_tts` only if synthetic voice is validated on target devices.

Testing:

- `flutter_test` for unit and widget tests.
- Golden tests for radar rendering only after the visual language stabilizes.

State management:

- Prefer the app's existing patterns initially.
- Add a dedicated state package only if engine/view-model complexity demands it.

## Technical Tradeoffs

Flutter-native radar:

- Pros: lighter app, easier App Review path, one codebase, mobile-friendly.
- Cons: 3D replay realism is limited, complex animation needs careful optimization.

Unity replay:

- Pros: richer 3D and camera replay potential.
- Cons: heavier builds, more integration risk, more review/build complexity.

Fixed-step simulation:

- Pros: deterministic replay and testability.
- Cons: needs careful interpolation for smooth rendering.

JSON scenarios:

- Pros: fast content iteration, easier difficulty scaling, future downloadable content.
- Cons: schema validation and migration become important.

## Performance Requirements

- Maintain 60fps on target mobile devices.
- Keep simulation engine pure Dart and efficient.
- Render radar with `CustomPainter` and repaint boundaries.
- Use fixed-step simulation with render interpolation.
- Cap visible labels and prediction overlays to avoid clutter.
- Avoid per-frame allocations in painters.
- Keep replay snapshots compact.

## Future Multiplayer Readiness

V2 should not build multiplayer yet, but it should avoid blocking it:

- Commands should be serializable events.
- Simulation should be deterministic from scenario seed plus command timeline.
- Scenario state should be restorable from snapshots.
- Player identity should not be hard-coded into engine models.
- Replay timeline should be suitable for sharing or server validation later.

## Suggested Milestones

Milestone 1: V2 simulation prototype

- Moving aircraft.
- Separation calculations.
- Conflict prediction.
- Basic radar painter.

Milestone 2: Data-driven scenarios

- JSON loader.
- Dynamic spawns.
- Win/fail evaluation.
- Difficulty scaling.

Milestone 3: Commandable aircraft

- Heading, speed, altitude.
- Direct-to waypoint.
- Hold command.
- Temporary restrictions.

Milestone 4: Replay and scoring

- Timeline recording.
- Replay playback.
- Mistake explanations.
- XP/rank hooks.

Milestone 5: Retention and realism

- Career stages.
- Sector packs.
- Audio phraseology.
- Daily challenge loop.

## Immediate Next Steps

1. Add feature flags and empty V2 module directories.
2. Define `ScenarioDefinition`, `AircraftState`, `ControllerCommand`, and `ReplayTimeline`.
3. Implement a pure Dart simulation tick test with two moving aircraft.
4. Add lateral/vertical separation unit tests.
5. Build a hidden V2 radar screen reachable only in debug or behind `kRadarEngineV2Enabled`.
