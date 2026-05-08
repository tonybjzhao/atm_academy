import 'dart:convert';

import 'scenario_definition.dart';

class ScenarioLoader {
  const ScenarioLoader();

  ScenarioDefinition parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Scenario root must be an object');
    }
    return _parseScenario(decoded);
  }

  ScenarioDefinition _parseScenario(Map<String, dynamic> json) {
    return ScenarioDefinition(
      id: _string(json, 'id'),
      title: _string(json, 'title'),
      sectorId: _string(json, 'sectorId'),
      duration: Duration(seconds: _int(json, 'durationSeconds')),
      difficulty: _int(json, 'difficulty'),
      radarRangeNm: (json['radarRangeNm'] as num?)?.toDouble() ?? 42,
      trafficDescription: (json['trafficDescription'] as String?) ?? '',
      objectives: _optionalStringList(json['objectives']),
      expectedTechniques: _optionalStringList(json['expectedTechniques']),
      speedOptions: _intList(json['speedOptions']),
      aircraft: _list(json['aircraft'])
          .map((item) => _parseAircraft(_map(item, 'aircraft item')))
          .toList(growable: false),
      winConditions: _list(json['winConditions'])
          .map((item) => _parseCondition(_map(item, 'win condition')))
          .toList(growable: false),
      failConditions: _list(json['failConditions'])
          .map((item) => _parseCondition(_map(item, 'fail condition')))
          .toList(growable: false),
    );
  }

  AircraftSpawnDefinition _parseAircraft(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? _string(json, 'callsign');
    final callsign = _string(json, 'callsign');
    final position = _map(json['position'], 'position');
    final route = json['route'] == null
        ? const <String>[]
        : _list(json['route'])
            .map((item) => item.toString())
            .toList(growable: false);
    final initialState = aircraftStateFromSpawn(
      id: id,
      callsign: callsign,
      xNm: _number(position, 'xNm'),
      yNm: _number(position, 'yNm'),
      altitudeFt: _int(json, 'altitudeFt'),
      headingDeg: _number(json, 'headingDeg'),
      groundSpeedKt: _number(json, 'groundSpeedKt'),
      verticalSpeedFpm: (json['verticalSpeedFpm'] as num?)?.round() ?? 0,
      route: route,
    );
    return AircraftSpawnDefinition(
      id: id,
      callsign: callsign,
      spawnAt: Duration(seconds: _int(json, 'spawnAtSeconds')),
      initialState: initialState,
    );
  }

  ScenarioCondition _parseCondition(Map<String, dynamic> json) {
    return ScenarioCondition(
      type: _string(json, 'type'),
      value: (json['value'] as num?)?.round(),
    );
  }

  String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Missing string field: $key');
  }

  int _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.round();
    throw FormatException('Missing number field: $key');
  }

  double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    throw FormatException('Missing number field: $key');
  }

  List<dynamic> _list(Object? value) {
    if (value is List) return value;
    throw const FormatException('Expected list field');
  }

  List<int> _intList(Object? value) {
    return _list(value).map((item) {
      if (item is num) return item.round();
      throw const FormatException('Expected numeric speed option');
    }).toList(growable: false);
  }

  List<String> _optionalStringList(Object? value) {
    if (value == null) return const [];
    return _list(value).map((item) => item.toString()).toList(growable: false);
  }

  Map<String, dynamic> _map(Object? value, String label) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Expected object for $label');
  }
}
