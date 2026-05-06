import '../models/radar_level_config.dart';

// All 10 levels.  Aircraft speed is multiplied by config.speedMultiplier at runtime.
// Conflict rule: horizontal distance < conflictDistancePx AND altitude diff < 10 FL.
const List<RadarLevelConfig> allLevels = [

  // ── Level 1 — Basic Crossing ──────────────────────────────────────────────
  // Two slow aircraft on opposite headings.  Start 200 px apart, ~7 s to conflict.
  // Lesson: heading change is the simplest separation tool.
  RadarLevelConfig(
    level: 1,
    scenarioKey: 'radarLevel1Name',
    tipKey: 'radarLevel1Tip',
    primaryTechnique: 'heading',
    timeLimitSeconds: 60,
    startingScore: 100,
    successBonus: 20,
    speedMultiplier: 0.65,
    conflictDistancePx: 75,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 80,  y: 200, heading: 90,  speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'UAE406', x: 280, y: 195, heading: 270, speed: 1.0, altitude: 320),
    ],
  ),

  // ── Level 2 — Altitude Separation ────────────────────────────────────────
  // Head-on pair with only 5 FL vertical gap → immediate conflict.
  // Heading divergence alone is too slow; climb/descend is the fast fix.
  RadarLevelConfig(
    level: 2,
    scenarioKey: 'radarLevel2Name',
    tipKey: 'radarLevel2Tip',
    primaryTechnique: 'altitude',
    timeLimitSeconds: 60,
    startingScore: 100,
    successBonus: 20,
    speedMultiplier: 0.70,
    conflictDistancePx: 70,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 140, y: 200, heading: 90,  speed: 1.0, altitude: 325),
      RadarAircraftStart(callsign: 'UAE406', x: 200, y: 200, heading: 270, speed: 1.0, altitude: 320),
    ],
  ),

  // ── Level 3 — Speed Control ───────────────────────────────────────────────
  // QFA is much faster than UAE on the same heading → catches up in ~3 s.
  // THA789 adds visual clutter but is clear of separation.
  // Lesson: slow the overtaking aircraft to restore longitudinal spacing.
  RadarLevelConfig(
    level: 3,
    scenarioKey: 'radarLevel3Name',
    tipKey: 'radarLevel3Tip',
    primaryTechnique: 'speed',
    timeLimitSeconds: 55,
    startingScore: 100,
    successBonus: 20,
    speedMultiplier: 0.75,
    conflictDistancePx: 70,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 55,  y: 200, heading: 90,  speed: 1.40, altitude: 320),
      RadarAircraftStart(callsign: 'UAE406', x: 155, y: 200, heading: 90,  speed: 0.80, altitude: 320),
      RadarAircraftStart(callsign: 'THA789', x: 250, y: 130, heading: 210, speed: 1.00, altitude: 280),
    ],
  ),

  // ── Level 4 — Mixed Conflict ──────────────────────────────────────────────
  // Two independent pairs: QFA/UAE (heading), THA/SIA (altitude gap 4 FL).
  // Lesson: use heading for one pair, altitude for the other simultaneously.
  RadarLevelConfig(
    level: 4,
    scenarioKey: 'radarLevel4Name',
    tipKey: 'radarLevel4Tip',
    primaryTechnique: 'mixed',
    timeLimitSeconds: 55,
    startingScore: 100,
    successBonus: 25,
    speedMultiplier: 0.80,
    conflictDistancePx: 70,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 140, y: 175, heading: 80,  speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'UAE406', x: 200, y: 180, heading: 260, speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'THA789', x: 110, y: 295, heading: 48,  speed: 0.9, altitude: 260),
      RadarAircraftStart(callsign: 'SIA201', x: 162, y: 252, heading: 228, speed: 0.9, altitude: 264),
    ],
  ),

  // ── Level 5 — Late Conflict ───────────────────────────────────────────────
  // Three aircraft; two converge fast AND a third approaches from the side.
  // Shorter time window — react before the situation compounds.
  RadarLevelConfig(
    level: 5,
    scenarioKey: 'radarLevel5Name',
    tipKey: 'radarLevel5Tip',
    primaryTechnique: 'heading',
    timeLimitSeconds: 45,
    startingScore: 100,
    successBonus: 25,
    speedMultiplier: 0.85,
    conflictDistancePx: 65,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 130, y: 195, heading: 78,  speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'UAE406', x: 195, y: 195, heading: 258, speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'THA789', x: 280, y: 120, heading: 198, speed: 1.0, altitude: 320),
    ],
  ),

  // ── Level 6 — High Traffic ────────────────────────────────────────────────
  // Five aircraft; two simultaneous conflicts.  Manage workload without losing track.
  RadarLevelConfig(
    level: 6,
    scenarioKey: 'radarLevel6Name',
    tipKey: 'radarLevel6Tip',
    primaryTechnique: 'mixed',
    timeLimitSeconds: 50,
    startingScore: 100,
    successBonus: 30,
    speedMultiplier: 0.85,
    conflictDistancePx: 65,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 130, y: 170, heading: 78,  speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'UAE406', x: 195, y: 175, heading: 258, speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'THA789', x: 108, y: 300, heading: 48,  speed: 0.9, altitude: 260),
      RadarAircraftStart(callsign: 'SIA201', x: 162, y: 258, heading: 228, speed: 0.9, altitude: 264),
      RadarAircraftStart(callsign: 'BAW772', x: 295, y: 210, heading: 185, speed: 0.9, altitude: 300),
    ],
  ),

  // ── Level 7 — Climb / Descend Crossing ───────────────────────────────────
  // Aircraft with differing altitudes (gap 3–8 FL) converging.  Model the
  // "predict future conflict" concept: act before the altitudes equalise.
  RadarLevelConfig(
    level: 7,
    scenarioKey: 'radarLevel7Name',
    tipKey: 'radarLevel7Tip',
    primaryTechnique: 'altitude',
    timeLimitSeconds: 50,
    startingScore: 100,
    successBonus: 30,
    speedMultiplier: 0.90,
    conflictDistancePx: 65,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 90,  y: 195, heading: 90,  speed: 1.0, altitude: 323),
      RadarAircraftStart(callsign: 'UAE406', x: 280, y: 200, heading: 270, speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'THA789', x: 175, y: 85,  heading: 155, speed: 0.9, altitude: 317),
      RadarAircraftStart(callsign: 'SIA201', x: 185, y: 345, heading: 335, speed: 0.9, altitude: 322),
    ],
  ),

  // ── Level 8 — Holding Pattern ────────────────────────────────────────────
  // Five aircraft circulating; speed adjustments prevent bunching.
  // All at slightly varied altitudes to create near-conflicts as they orbit.
  RadarLevelConfig(
    level: 8,
    scenarioKey: 'radarLevel8Name',
    tipKey: 'radarLevel8Tip',
    primaryTechnique: 'speed',
    timeLimitSeconds: 60,
    startingScore: 100,
    successBonus: 30,
    speedMultiplier: 0.75,
    conflictDistancePx: 60,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 185, y: 115, heading: 120, speed: 1.0, altitude: 320),
      RadarAircraftStart(callsign: 'UAE406', x: 270, y: 230, heading: 210, speed: 1.0, altitude: 322),
      RadarAircraftStart(callsign: 'THA789', x: 185, y: 320, heading: 300, speed: 0.9, altitude: 320),
      RadarAircraftStart(callsign: 'SIA201', x: 100, y: 220, heading: 30,  speed: 1.1, altitude: 318),
      RadarAircraftStart(callsign: 'BAW772', x: 230, y: 165, heading: 245, speed: 0.8, altitude: 321),
    ],
  ),

  // ── Level 9 — Approach Conflict ───────────────────────────────────────────
  // Four aircraft converging on the same arrival corridor.
  // Maintain runway separation order — one must give way.
  RadarLevelConfig(
    level: 9,
    scenarioKey: 'radarLevel9Name',
    tipKey: 'radarLevel9Tip',
    primaryTechnique: 'mixed',
    timeLimitSeconds: 45,
    startingScore: 100,
    successBonus: 35,
    speedMultiplier: 0.90,
    conflictDistancePx: 60,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'QFA123', x: 80,  y: 140, heading: 135, speed: 1.0, altitude: 180),
      RadarAircraftStart(callsign: 'UAE406', x: 115, y: 80,  heading: 150, speed: 1.0, altitude: 185),
      RadarAircraftStart(callsign: 'THA789', x: 285, y: 120, heading: 215, speed: 0.9, altitude: 180),
      RadarAircraftStart(callsign: 'SIA201', x: 265, y: 70,  heading: 225, speed: 0.9, altitude: 178),
    ],
  ),

  // ── Level 10 — Priority Emergency ────────────────────────────────────────
  // Five aircraft; MAYDAY1 is the priority aircraft.  Clear its path —
  // all other aircraft must be moved away immediately.  Fastest speed, least time.
  RadarLevelConfig(
    level: 10,
    scenarioKey: 'radarLevel10Name',
    tipKey: 'radarLevel10Tip',
    primaryTechnique: 'mixed',
    timeLimitSeconds: 40,
    startingScore: 100,
    successBonus: 50,
    speedMultiplier: 1.00,
    conflictDistancePx: 60,
    requiredClearSeconds: 5,
    aircraft: [
      RadarAircraftStart(callsign: 'MAYDAY', x: 185, y: 215, heading: 90,  speed: 0.8, altitude: 80),
      RadarAircraftStart(callsign: 'QFA123', x: 130, y: 175, heading: 100, speed: 1.0, altitude: 82),
      RadarAircraftStart(callsign: 'UAE406', x: 240, y: 180, heading: 260, speed: 1.0, altitude: 79),
      RadarAircraftStart(callsign: 'THA789', x: 175, y: 160, heading: 160, speed: 0.9, altitude: 81),
      RadarAircraftStart(callsign: 'BAW772', x: 195, y: 265, heading: 340, speed: 0.9, altitude: 80),
    ],
  ),
];
