import 'package:flutter/services.dart' show rootBundle;

import 'scenario_definition.dart';
import 'scenario_loader.dart';

class ScenarioAssetLoader {
  final ScenarioLoader parser;

  const ScenarioAssetLoader({
    this.parser = const ScenarioLoader(),
  });

  Future<ScenarioDefinition> load(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    return parser.parse(source);
  }
}
