# Internal Tester Verification Checklist

## Pre-Deployment Verification

### ✅ Build Quality Checks
- [x] `flutter clean` completed
- [x] `flutter pub get` completed
- [x] `flutter analyze` — No issues found
- [x] `flutter test` — 201/201 passing
- [x] `flutter build appbundle --release` — 41 MB artifact created
- [x] `flutter build ios --release` — 19.5 MB app built
- [x] iOS archive created: `ios/build/Runner.xcarchive`
- [x] Build number incremented: 1.0.0+2 → 1.0.0+3
- [x] No debug overlays in release build
- [x] Code signing verified (iOS)

### ✅ Artifact Locations
- **Android APK Bundle:** `build/app/outputs/bundle/release/app-release.aab` (41 MB)
- **iOS Archive:** `ios/build/Runner.xcarchive`
- **Documentation:** `INTERNAL_TEST_RELEASE_NOTES.md`

### ✅ Release Notes Prepared
- [x] Test scenarios documented
- [x] Known characteristics explained
- [x] Testing checklist provided
- [x] Issue reporting guidelines included
- [x] Device requirements listed

---

## Scenario Availability

| Scenario | Difficulty | Duration | Weather | Status |
|----------|-----------|----------|---------|--------|
| Beginner Crossing Arrivals | 2/5 | 4 min | Normal | ✓ Ready |
| False Recovery / Tunnel Vision | 4/5 | 5.5 min | Low Vis | ✓ Ready |
| Melbourne Storm Arrival Rush | 4/5 | 5.5 min | Low Vis | ✓ Ready |

---

## Tester Instructions

### For Android Testers
1. Upload `app-release.aab` to Google Play Console
2. Create internal testing track
3. Add tester email addresses
4. Share download link with testers
5. Testers install from Google Play

### For iOS Testers
1. Archive exists at: `ios/build/Runner.xcarchive`
2. Option A (Recommended): Use Xcode → Organizer → Validate App → Upload to App Store Connect → Add to TestFlight
3. Option B: Use xcrun altool (deprecated but may work on older systems)
4. Share TestFlight link via Apple App Store Connect
5. Testers receive invite to TestFlight

### Steps to Upload iOS Archive (Manual)

```bash
# 1. Open the archive in Xcode Organizer
open ios/build/Runner.xcarchive

# 2. In Xcode, select: Distribute App → App Store Connect
# 3. Select signing options
# 4. Upload
# 5. In App Store Connect, go to TestFlight → Add build to internal testing
```

---

## Sign-Off Checklist

**Before sending to testers, verify:**

- [ ] All 201 tests still passing
- [ ] `flutter analyze` shows no errors
- [ ] Android appbundle is 40-45 MB (expected range)
- [ ] iOS archive exists and is accessible
- [ ] Release notes are clear and complete
- [ ] No accidental debug code committed
- [ ] Git history is clean

**Tester communication:**
- [ ] Clear instructions on how to download/install
- [ ] Link to test scenarios
- [ ] Examples of expected vs problematic behavior
- [ ] Clear reporting channel for issues
- [ ] Timeline for feedback collection

---

## Post-Testing Process

1. **Collect feedback** for 3-5 days
2. **Triage issues:**
   - Crashes → Fix immediately
   - Fairness concerns → Review scenario balance
   - Tuning requests → Only apply if widespread
   - UX/polish → Document for next release
3. **Re-test** any fixes
4. **Create release candidate** once stable

---

## Key Metrics to Monitor

Ask testers to provide:
- Command responsiveness score (1-5)
- ACK delay acceptability (too fast / just right / too slow)
- Scenario fairness (1-5 for each scenario)
- Debrief usefulness (1-5)
- Any crashes or stuck states (frequency)

---

**Internal Test Build Ready: BUILD 3 (1.0.0+3)**  
**Prepared:** 9 May 2026  
**Status:** ✅ Ready for distribution
