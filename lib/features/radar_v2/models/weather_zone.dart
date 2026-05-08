class WeatherZone {
  final String id;
  final double xNm;
  final double yNm;
  final double radiusNm;
  final int severity;

  const WeatherZone({
    required this.id,
    required this.xNm,
    required this.yNm,
    required this.radiusNm,
    this.severity = 1,
  });
}
