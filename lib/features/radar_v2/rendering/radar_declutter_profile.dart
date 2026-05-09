class RadarDeclutterProfile {
  final double visibleRangeNm;
  final double sectorRangeNm;
  final double wideZoomFactor;
  final double symbolScale;
  final double labelScale;
  final double conflictRingScale;
  final bool showSecondaryLabelDetails;
  final bool simplifyWeather;
  final int weatherLabelSeverityMin;
  final int maxTrailPoints;
  final int trailPointStride;
  final int nonCriticalLabelBudget;
  final int callsignChars;

  const RadarDeclutterProfile({
    required this.visibleRangeNm,
    required this.sectorRangeNm,
    required this.wideZoomFactor,
    required this.symbolScale,
    required this.labelScale,
    required this.conflictRingScale,
    required this.showSecondaryLabelDetails,
    required this.simplifyWeather,
    required this.weatherLabelSeverityMin,
    required this.maxTrailPoints,
    required this.trailPointStride,
    required this.nonCriticalLabelBudget,
    required this.callsignChars,
  });

  factory RadarDeclutterProfile.fromVisibleRange({
    required double visibleRangeNm,
    required double sectorRangeNm,
  }) {
    final safeSector = sectorRangeNm <= 0 ? visibleRangeNm : sectorRangeNm;
    final normalized = ((visibleRangeNm / safeSector) - 0.45) / 0.55;
    final wide = normalized.clamp(0.0, 1.0);
    final showSecondary = wide < 0.35;
    final simplifyWeather = wide >= 0.45;

    int labelBudget;
    if (wide >= 0.8) {
      labelBudget = 4;
    } else if (wide >= 0.62) {
      labelBudget = 6;
    } else if (wide >= 0.48) {
      labelBudget = 8;
    } else {
      labelBudget = 12;
    }

    int callsignChars;
    if (wide >= 0.82) {
      callsignChars = 4;
    } else if (wide >= 0.55) {
      callsignChars = 5;
    } else {
      callsignChars = 6;
    }

    return RadarDeclutterProfile(
      visibleRangeNm: visibleRangeNm,
      sectorRangeNm: safeSector,
      wideZoomFactor: wide,
      symbolScale: _lerp(1.0, 0.88, wide),
      labelScale: _lerp(1.0, 0.9, wide),
      conflictRingScale: _lerp(1.0, 0.9, wide),
      showSecondaryLabelDetails: showSecondary,
      simplifyWeather: simplifyWeather,
      weatherLabelSeverityMin: wide >= 0.72 ? 2 : 1,
      maxTrailPoints: _lerp(24.0, 9.0, wide).round(),
      trailPointStride: 1 + (wide * 2).round(),
      nonCriticalLabelBudget: labelBudget,
      callsignChars: callsignChars,
    );
  }

  bool shouldShowAircraftLabel({
    required RadarLabelPriority priority,
    required int nonCriticalRank,
  }) {
    if (priority != RadarLabelPriority.normal) {
      return true;
    }
    return nonCriticalRank < nonCriticalLabelBudget;
  }

  String formatCallsign(String callsign, {required bool preserveFull}) {
    final normalized = callsign.trim().toUpperCase();
    if (preserveFull || normalized.length <= callsignChars) {
      return normalized;
    }
    return normalized.substring(0, callsignChars);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

enum RadarLabelPriority {
  normal,
  warning,
  commanded,
  selected,
  conflict,
}
