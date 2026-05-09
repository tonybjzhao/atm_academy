# ATM Academy Radar Training Beta V1.0.0 Build 3
**Internal Testing Release**  
**Release Date:** 9 May 2026  
**Build Artifacts:**
- Android: `app-release.aab` (41 MB) — Ready for Google Play internal testing
- iOS: `Runner.xcarchive` — Ready for TestFlight upload

---

## Build Summary

**Branch:** feature/v2-radar-engine  
**Latest Commit:** HEAD (feature/v2-radar-engine)  
**Tests:** 201/201 passing  
**Static Analysis:** Clean  

### Recent Work
- **Trait-Aware Scenario Generation V1** — Scenarios now measure how natural pressure patterns interact with controller trait vulnerabilities
- **QA Tuning Pass V1** — Command acknowledgement optimized (2.6s), weather wobble subtler (1.2x)
- **All systems integrated** — Controller archetype profiles, mental model state tracking, environmental pressure ecology, cognitive cascade detection

---

## Test Scenarios

### 1. **Beginner Crossing Arrivals** ⭐ Start here
- **Difficulty:** 2/5  
- **Duration:** 4 minutes  
- **Weather:** Normal  
- **Objective:** Resolve a crossing conflict before it becomes urgent  
- **Testing Focus:**
  - Command responsiveness (turn, speed, direct-to)
  - Beginner feedback (is it forgiving enough?)
  - ACK delay (does 2.6s feel immediate?)
  - No crashes on command execution

### 2. **False Recovery / Tunnel Vision**
- **Difficulty:** 4/5  
- **Duration:** ~5.5 minutes  
- **Weather:** Low visibility  
- **Objective:** Avoid fixation on early conflict while managing arrival spacing  
- **Testing Focus:**
  - Does scenario feel challenging but fair?
  - Does weather affect radar readability?
  - Does second conflict surprise feel warranted?
  - Debrief should explain fixation triggers

### 3. **Melbourne Storm Arrival Rush**
- **Difficulty:** 4/5  
- **Duration:** ~5.5 minutes  
- **Weather:** Low visibility  
- **Objective:** Manage weather reroutes + runway pressure + attention trap  
- **Testing Focus:**
  - Storm scenario tension (is it stressful but not unfair?)
  - Weather wobble (are tracks readable or too erratic?)
  - Final approach compression (does runway pressure feel realistic?)
  - Debrief explanation of pressure interaction

---

## What to Test

### Command System
- [ ] **Heading command** — Aircraft accept and turn smoothly (no oscillation)
- [ ] **Speed command** — Aircraft accelerate/decelerate without lag
- [ ] **Direct-to command** — Waypoint vectors work, no path crossing anomalies
- [ ] **Feedback sequence:**
  - Command appears immediately when issued ✓
  - ACK appears ~2.6 seconds later (not instant, not delayed)
  - Aircraft behavior changes roughly 0.5s after ACK

### Radar Display
- [ ] **Aircraft symbols** — Clear callsigns, altitudes, speed vectors
- [ ] **Separation rings** — Visible at all radar ranges
- [ ] **Weather** — Low-visibility wobble is subtle, not distracting
- [ ] **Trail history** — 28-point trails provide good scan reference
- [ ] **Conflict alerts** — Appear with enough lead time to maneuver

### Scenario Fairness
- [ ] **Beginner** — Should feel achievable; no "gotcha" conflicts
- [ ] **Storm** — Should feel tense; conflicts should require decisive vectoring
- [ ] **All scenarios** — No missed conflict predictions

### Result Screen
- [ ] **Score display** — Clear, prominent
- [ ] **Main Debrief** — First card summarizes critical mistake
- [ ] **Cognitive Cascade** — Flow diagram makes sense
- [ ] **Cognitive Timeline** — Events line up with your actions
- [ ] **Replay moments** — Can jump to specific timeline events
- [ ] **Trait–Scenario Interaction** — Section identifies which scenario pressures stressed your approach
- [ ] **More Details** — Expandable without overwhelming

### Stability
- [ ] **No crashes** — App runs through full scenario + debrief without errors
- [ ] **No stuck states** — Commands always execute, scenario progresses smoothly
- [ ] **No debug overlay** — No FPS counter, debug widgets visible in release

---

## Known Characteristics (Not Bugs)

### Responsiveness Degradation
- Aircraft turn/speed responsiveness reduces by up to 45% under high sector pressure
- **Why:** Simulates controller workload fatigue; teaches that you must plan ahead under load
- **Intended:** Not a bug; part of pressure simulation

### Weather Wobble Timing
- Track wobble only appears after aircraft is in weather zone for 6+ seconds
- **Why:** Realistic ATC timing; weather effects don't trigger on initial entry
- **Intended:** Not a bug; realistic behavior

### Runway Occupancy (Storm Scenario)
- Runway occupancy extended to 58 seconds (vs 45s in beginner scenario)
- **Why:** Low visibility + weather = longer runway occupancy; teaches about pressure accumulation
- **Intended:** Not a bug; pressure teaching scenario

---

## How to Report Issues

If you encounter problems:

1. **Take note of:**
   - What scenario (Beginner / Tunnel Vision / Storm)
   - What action triggered the issue (command, manual action, etc.)
   - Exact error message or description of unexpected behavior
   - Time elapsed when issue occurred

2. **Report to:** [Tester feedback channel]

3. **Include:**
   - Build number (currently 3)
   - Device/platform (Android / iOS)
   - Reproducibility (one-time / always happens)

### Do NOT Report
- Scenarios feeling challenging (that's intentional)
- Acknowledgement delay feeling ~2.6s (that's tuned)
- Weather wobble in low-visibility scenarios (that's intentional)
- Responsiveness degrading under high load (that's intentional pressure simulation)

---

## Testing Checklist

**Pre-Test:**
- [ ] Device has enough storage (50+ MB free)
- [ ] Device is on latest OS or recent stable build
- [ ] Network available for initial scenario load

**Each Scenario:**
- [ ] App launches scenario successfully
- [ ] Can issue at least one command and see ACK
- [ ] Radar is readable throughout
- [ ] No crashes before result screen
- [ ] Result screen opens and debrief data loads

**Result Screen:**
- [ ] Can view main debrief
- [ ] Can expand cascade and timeline
- [ ] Can replay moments without errors

**Overall:**
- [ ] No crashes reported
- [ ] Command feel is acceptable
- [ ] Scenario fairness is reasonable
- [ ] Debrief is useful (not too noisy, not too sparse)

---

## Release Notes

### What's New in This Build

**Trait-Aware Scenario Generation**
- Scenarios now classify their natural pressure topology (5 patterns: surprise-heavy, multi-conflict scan, backlog, escalation, tight spacing)
- Per-tick measurement of how each pattern interacts with your controller traits
- Debrief now includes "Trait–Scenario Interaction" section identifying which pressures amplified your mistakes

**Tuning Adjustments**
- Command acknowledgement delay: 3.0s → 2.6s (snappier feedback)
- Weather wobble: 1.4x → 1.2x (subtler, more readable tracks)

**Architecture**
- Full integration of controller archetype profiling (18 traits across 6 cognitive systems)
- Mental model state tracking per tick
- Environmental pressure ecology explaining operational load sources
- Cognitive cascade detection (failure propagation analysis)

### Stability Improvements
- Clean static analysis (0 issues)
- All 201 unit tests passing
- Release build optimizations enabled

---

## Device Requirements

**Android:**
- Minimum SDK: 21 (Android 5.0)
- Recommended: SDK 28+ (Android 9+)
- Storage: 50+ MB free
- RAM: 2GB+

**iOS:**
- Minimum: iOS 11.0
- Recommended: iOS 14+
- Storage: 50+ MB free
- RAM: 1.5GB+

---

## Next Steps After Testing

1. Testers use app and report findings
2. Feedback collected (focus: command feel, fairness, stability)
3. Any real issues fixed (tuning only if testers report problems)
4. Public release candidate build created

---

## Support

**Questions about the app?** Check the in-app lesson content or scenario objectives.  
**Found a bug?** Report with scenario name, action, and result.  
**Feedback on design/UX?** Collect for post-beta discussion.

---

**Thank you for testing Radar Training Beta V1.0.0!**

*Build prepared for internal testing on 9 May 2026*
