# Radar Training Beta Manual QA Checklist

Purpose: Standard pass/fail sheet for internal testers validating Radar Training Beta readiness.

Build under test:
- Date:
- Branch/commit:
- Device:
- OS version:
- Orientation tested: Portrait / Landscape / Both

## Pre-flight
- [ ] App launches normally.
- [ ] Home screen loads with no red error banners.
- [ ] Debug entry visible only in debug builds: Radar Training Beta.
- [ ] Entry not visible in non-debug build.

## Scenario Coverage (Run all 3)
Scenarios:
1. Beginner Crossing Conflict
2. Arrival Spacing Under Weather
3. False Recovery / Tunnel Vision

For each scenario, complete every check below.

### Flow Validation (per scenario)
- [ ] Scenario list opens.
- [ ] Scenario card opens briefing.
- [ ] Briefing shows objective, traffic situation, expected technique, risks, success criteria.
- [ ] Start Scenario launches radar screen.
- [ ] Aircraft are selectable by tap.
- [ ] Command buttons work: heading, altitude, speed, hold.
- [ ] Pause works.
- [ ] Restart works.
- [ ] Scenario can be completed to result screen.
- [ ] Retry from result screen starts same scenario again.
- [ ] Scenario List button returns to training list.
- [ ] Progress stars update after attempt.

### Results and Replay Validation (per scenario)
- [ ] Final score and grade are shown.
- [ ] Top mistake text is shown and coherent.
- [ ] Best recovery text is shown.
- [ ] Replay explanation list is populated.
- [ ] Replay timeline slider works.

## Error Handling
Force-load failure case (bad/missing scenario asset):
- [ ] Friendly error title shown: Scenario could not be loaded.
- [ ] Retry button shown.
- [ ] Retry re-attempts loading.
- [ ] App remains responsive; no crash.

## Mobile Usability
### Safe area and layout
- [ ] Content respects top/bottom safe areas on notched devices.
- [ ] Bottom actions are not obscured by system UI/home indicator.
- [ ] Result screen scrolls fully to bottom on small screens.

### Touch targets
- [ ] Command buttons are comfortably tappable (target >= 44 px).
- [ ] Buttons are not overlapping at narrow widths.

### Orientation
- [ ] Portrait layout remains usable.
- [ ] Landscape layout remains usable.
- [ ] No critical text/buttons clipped in either orientation.

## Persistence Checks
- [ ] Onboarding card dismiss persists across app relaunch.
- [ ] Best score persists across relaunch.
- [ ] Completion count increments per run.
- [ ] Stars reflect best score thresholds consistently.

## Audio/Feedback Sanity
- [ ] Conflict/interaction cues play when expected.
- [ ] Mute toggle works in beta run.
- [ ] No repeated audio spam during idle.

## Exit Criteria
- [ ] No crashes across all 3 scenarios.
- [ ] No blocker UX issues found.
- [ ] No data-loss in progress persistence.
- [ ] Ready for internal feedback wave.

## Defect Log
Use one line per issue.
- Severity (Blocker/High/Medium/Low):
- Scenario:
- Steps:
- Expected:
- Actual:
- Screenshot/video:
- Repro rate:
