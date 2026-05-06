import '../core/models/aircraft.dart';

class AircraftSetup {
  final String callsign;
  final double x;
  final double y;
  final double heading;
  final double speed;
  final int altitude;

  const AircraftSetup({
    required this.callsign,
    required this.x,
    required this.y,
    required this.heading,
    required this.speed,
    required this.altitude,
  });

  Aircraft toAircraft() => Aircraft(
        callsign: callsign,
        x: x,
        y: y,
        heading: heading,
        speed: speed,
        altitude: altitude,
      );
}

class LevelConfig {
  final int level;
  final String nameKey; // ARB key
  final String tipKey;  // ARB key shown on failure
  final int timeLimit;  // seconds
  final List<AircraftSetup> aircraft;

  const LevelConfig({
    required this.level,
    required this.nameKey,
    required this.tipKey,
    required this.timeLimit,
    required this.aircraft,
  });

  static const int maxLevel = 6;

  static LevelConfig forLevel(int n) =>
      _all[(n - 1).clamp(0, _all.length - 1)];

  static const List<LevelConfig> _all = [
    // ── Level 1: Basic Separation ────────────────────────────────────────
    // 2 slow aircraft, 210 px apart, ~7 s before conflict develops.
    // Introductory — user has time to read the interface.
    LevelConfig(
      level: 1,
      nameKey: 'radarLevel1Name',
      tipKey: 'radarLevel1Tip',
      timeLimit: 90,
      aircraft: [
        AircraftSetup(callsign: 'QFA123', x: 80,  y: 200, heading: 90,  speed: 0.55, altitude: 320),
        AircraftSetup(callsign: 'UAE406', x: 290, y: 200, heading: 270, speed: 0.45, altitude: 320),
      ],
    ),

    // ── Level 2: Crossing Traffic ────────────────────────────────────────
    // 3 aircraft; QFA/UAE in immediate conflict, THA789 approaching.
    LevelConfig(
      level: 2,
      nameKey: 'radarLevel2Name',
      tipKey: 'radarLevel2Tip',
      timeLimit: 75,
      aircraft: [
        AircraftSetup(callsign: 'QFA123', x: 140, y: 195, heading: 70,  speed: 0.65, altitude: 320),
        AircraftSetup(callsign: 'UAE406', x: 200, y: 195, heading: 250, speed: 0.60, altitude: 320),
        AircraftSetup(callsign: 'THA789', x: 185, y: 70,  heading: 155, speed: 0.55, altitude: 280),
      ],
    ),

    // ── Level 3: Altitude Conflict ───────────────────────────────────────
    // QFA/UAE: 60 px apart, altitude diff = 5 FL (< 10) → immediate conflict.
    // Higher speed makes lateral heading changes slower; climb/descend faster.
    LevelConfig(
      level: 3,
      nameKey: 'radarLevel3Name',
      tipKey: 'radarLevel3Tip',
      timeLimit: 60,
      aircraft: [
        AircraftSetup(callsign: 'QFA123', x: 140, y: 200, heading: 90,  speed: 0.75, altitude: 325),
        AircraftSetup(callsign: 'UAE406', x: 200, y: 200, heading: 270, speed: 0.70, altitude: 320),
        AircraftSetup(callsign: 'THA789', x: 80,  y: 120, heading: 30,  speed: 0.60, altitude: 310),
      ],
    ),

    // ── Level 4: Double Conflict ─────────────────────────────────────────
    // 4 aircraft; two simultaneous conflicts from the start.
    // QFA/UAE pair + THA/SIA pair (both within horiz 70 px, same alt).
    LevelConfig(
      level: 4,
      nameKey: 'radarLevel4Name',
      tipKey: 'radarLevel4Tip',
      timeLimit: 55,
      aircraft: [
        AircraftSetup(callsign: 'QFA123', x: 140, y: 160, heading: 75,  speed: 0.80, altitude: 320),
        AircraftSetup(callsign: 'UAE406', x: 200, y: 165, heading: 255, speed: 0.75, altitude: 320),
        AircraftSetup(callsign: 'THA789', x: 110, y: 290, heading: 45,  speed: 0.65, altitude: 260),
        AircraftSetup(callsign: 'SIA201', x: 160, y: 248, heading: 225, speed: 0.60, altitude: 260),
      ],
    ),

    // ── Level 5: High Speed ──────────────────────────────────────────────
    // Same geometry as level 4, noticeably faster, 15 s less time.
    LevelConfig(
      level: 5,
      nameKey: 'radarLevel5Name',
      tipKey: 'radarLevel5Tip',
      timeLimit: 45,
      aircraft: [
        AircraftSetup(callsign: 'QFA123', x: 140, y: 160, heading: 75,  speed: 1.00, altitude: 320),
        AircraftSetup(callsign: 'UAE406', x: 200, y: 165, heading: 255, speed: 0.95, altitude: 320),
        AircraftSetup(callsign: 'THA789', x: 110, y: 290, heading: 45,  speed: 0.85, altitude: 260),
        AircraftSetup(callsign: 'SIA201', x: 160, y: 248, heading: 225, speed: 0.80, altitude: 260),
      ],
    ),

    // ── Level 6: Complex Pattern ─────────────────────────────────────────
    // 4 aircraft, both pairs in immediate conflict, highest speeds, 35 s.
    LevelConfig(
      level: 6,
      nameKey: 'radarLevel6Name',
      tipKey: 'radarLevel6Tip',
      timeLimit: 35,
      aircraft: [
        AircraftSetup(callsign: 'QFA123', x: 140, y: 155, heading: 70,  speed: 1.15, altitude: 320),
        AircraftSetup(callsign: 'UAE406', x: 200, y: 160, heading: 250, speed: 1.05, altitude: 320),
        AircraftSetup(callsign: 'THA789', x: 105, y: 285, heading: 50,  speed: 1.00, altitude: 255),
        AircraftSetup(callsign: 'SIA201', x: 165, y: 235, heading: 230, speed: 0.95, altitude: 258),
      ],
    ),
  ];
}
