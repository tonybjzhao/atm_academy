import 'aircraft_intent.dart';
import 'aircraft_performance_profile.dart';

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
  final int routeWaypointIndex;
  final AircraftPerformanceType performanceType;
  final double holdElapsedSeconds;
  final bool active;

  const AircraftState({
    required this.id,
    required this.callsign,
    required this.xNm,
    required this.yNm,
    required this.altitudeFt,
    required this.headingDeg,
    required this.groundSpeedKt,
    this.verticalSpeedFpm = 0,
    this.intent = const AircraftIntent.empty(),
    this.routeWaypointIndex = 0,
    this.performanceType = AircraftPerformanceType.jet,
    this.holdElapsedSeconds = 0,
    this.active = true,
  });

  AircraftState copyWith({
    String? id,
    String? callsign,
    double? xNm,
    double? yNm,
    int? altitudeFt,
    double? headingDeg,
    double? groundSpeedKt,
    int? verticalSpeedFpm,
    AircraftIntent? intent,
    int? routeWaypointIndex,
    AircraftPerformanceType? performanceType,
    double? holdElapsedSeconds,
    bool? active,
  }) {
    return AircraftState(
      id: id ?? this.id,
      callsign: callsign ?? this.callsign,
      xNm: xNm ?? this.xNm,
      yNm: yNm ?? this.yNm,
      altitudeFt: altitudeFt ?? this.altitudeFt,
      headingDeg: headingDeg ?? this.headingDeg,
      groundSpeedKt: groundSpeedKt ?? this.groundSpeedKt,
      verticalSpeedFpm: verticalSpeedFpm ?? this.verticalSpeedFpm,
      intent: intent ?? this.intent,
      routeWaypointIndex: routeWaypointIndex ?? this.routeWaypointIndex,
      performanceType: performanceType ?? this.performanceType,
      holdElapsedSeconds: holdElapsedSeconds ?? this.holdElapsedSeconds,
      active: active ?? this.active,
    );
  }
}
