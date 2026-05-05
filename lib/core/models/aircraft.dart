import 'dart:math';
import 'dart:ui' show Size;

class Aircraft {
  Aircraft({
    required this.callsign,
    required this.x,
    required this.y,
    required this.heading,
    required this.speed,
    required this.altitude,
  });

  final String callsign;
  double x;
  double y;
  double heading;
  double speed;
  int altitude;

  void update(Size radarSize) {
    final radians = heading * pi / 180;
    x += cos(radians) * speed;
    y += sin(radians) * speed;
    if (x < 20 || x > radarSize.width - 20) heading = 180 - heading;
    if (y < 20 || y > radarSize.height - 20) heading = -heading;
  }
}
