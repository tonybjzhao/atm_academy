import 'dart:math' as math;

import '../core/alerts/alert_manager.dart';
import '../core/alerts/alert_priority.dart';
import '../core/alerts/operational_alert.dart';
import '../core/attention/attention_competition_engine.dart' as attention_v1;
import '../core/attention/attention_focus_state.dart';
import '../core/cognitive_load/cognitive_load_engine.dart';
import '../core/cognitive_load/cognitive_load_state.dart';
import '../core/mental_model/cognitive_cascade_engine.dart';
import '../core/mental_model/cognitive_cascade_state.dart';
import '../core/mental_model/controller_expectation_state.dart';
import '../core/mental_model/expectation_tracker.dart';
import '../core/mental_model/predictive_mental_model_engine.dart';
import '../core/mental_model/predictive_mental_model_state.dart';
import '../core/mental_model/working_memory_engine.dart';
import '../core/mental_model/working_memory_state.dart';
import '../core/pressure/attention_competition_engine.dart' as pressure;
import '../core/pressure/tunnel_vision_engine.dart';
import '../core/pressure/workload_degradation.dart';
import '../core/psychology/pressure_pacing_engine.dart';
import '../core/psychology/scenario_pressure_phase.dart';
import '../core/replay/cognition_analytics.dart';
import '../core/replay/replay_workload_frame.dart';
import '../engine/simulation_engine.dart';
import '../models/aircraft_state.dart';
import '../models/arrival_flow.dart';
import '../models/controller_alert.dart';
import '../models/departure_flow.dart';
import '../models/simulation_event.dart';
import '../models/separation_result.dart';
import '../models/simulation_snapshot.dart';
import 'scenario_definition.dart';

class ScenarioRuntime {
  final ScenarioDefinition definition;
  final SimulationEngine engine;
  final Set<String> _spawnedIds = <String>{};
  final Set<String> _exitedIds = <String>{};
  final Map<String, AircraftSpawnDefinition> _queuedDepartures =
      <String, AircraftSpawnDefinition>{};
  final Map<String, Duration> _lastDepartureReleaseByRunway =
      <String, Duration>{};
  final Set<String> _goAroundIssued = <String>{};
  final Map<String, ControllerAlert> _activeAlerts =
      <String, ControllerAlert>{};
  final Set<String> _alertsEscalatedThisTick = <String>{};
  final Map<String, Duration> _activeDistractionUntil = <String, Duration>{};
  final Set<String> _distractionsProcessedThisTick = <String>{};
  final Map<String, Duration> _subtleConflictFirstSeenAt = <String, Duration>{};
  final Set<String> _subtleConflictDeferred = <String>{};
  // Dynamic pacing: tracks spawn holds and their deadlines
  final Map<String, Duration> _spawnHeldUntil = <String, Duration>{};
  double _currentSectorPressure = 0;
  static const double _spawnHoldPressureThreshold = 2.5;
  static const Duration _maxSpawnHoldDuration = Duration(seconds: 25);
  int _separationLossCount = 0;
  double _pressureCarryOver = 0;
  // Decision Pressure Engine V1
  final CognitiveLoadEngine _cognitiveLoadEngine = CognitiveLoadEngine();
  final AlertManager _alertManager = AlertManager();
  // Overload Response System
  final pressure.AttentionCompetitionEngine _attentionEngine =
      pressure.AttentionCompetitionEngine();
  final TunnelVisionEngine _tunnelVisionEngine = TunnelVisionEngine();
  final attention_v1.AttentionCompetitionEngine _attentionV1Engine =
      attention_v1.AttentionCompetitionEngine();
  final PressurePacingEngine _pressurePacingEngine = PressurePacingEngine();
  final ExpectationTracker _expectationTracker = ExpectationTracker();
  final PredictiveMentalModelEngine _predictiveMentalModelEngine =
      PredictiveMentalModelEngine();
    final CognitiveCascadeEngine _cognitiveCascadeEngine =
      CognitiveCascadeEngine();
  final WorkingMemoryEngine _workingMemoryEngine = WorkingMemoryEngine();
  final List<AttentionFocusState> _attentionHistory = <AttentionFocusState>[];
  String? _selectedAircraftIdForAttention;
  String? _selectedRunwayIdForAttention;
  String? _selectedAlertIdForAttention;
  final CognitionAnalyticsTracker _analyticsTracker =
      CognitionAnalyticsTracker();
  WorkloadDegradation _currentDegradation = WorkloadDegradation.none;
  pressure.AttentionCompetitionResult _lastAttentionResult =
      pressure.AttentionCompetitionResult.idle;
  AttentionFocusState _lastAttentionFocusState = AttentionFocusState.idle;
  AttentionFocusState _previousAttentionFocusState = AttentionFocusState.idle;
  ScenarioPsychologyState _lastPsychologyState = ScenarioPsychologyState.idle;
  ControllerExpectationState _lastExpectationState =
      ControllerExpectationState.idle;
    PredictiveMentalModelState _lastPredictiveMentalModelState =
      PredictiveMentalModelState.idle;
    CognitiveCascadeState _lastCognitiveCascadeState =
      CognitiveCascadeState.idle;
  WorkingMemoryState _lastWorkingMemoryState = WorkingMemoryState.idle;
  WorkingMemoryState _previousWorkingMemoryState = WorkingMemoryState.idle;
  TunnelVisionState _lastTunnelVisionState = TunnelVisionState.none;
    Duration? _stickyFocusUntil;
    String? _stickyFocusTarget;
  // Rolling command timestamps for recent-command-density tracking
  final List<Duration> _recentCommandTimestamps = [];
  int _totalGoAroundCount = 0;

  ScenarioRuntime({
    required this.definition,
    SimulationEngine? engine,
  }) : engine = engine ??
            SimulationEngine(
              aircraft: const [],
              waypoints: definition.waypoints,
              weatherZones: definition.weatherZones,
              arrivalFlows: _effectiveArrivalFlows(definition),
              departureFlows: definition.departureFlows,
              holdPatterns: definition.holdPatterns,
              altitudeRestrictions: definition.altitudeRestrictions,
              maxControllerLoad: definition.maxControllerLoad,
            );

  static List<ArrivalFlow> _effectiveArrivalFlows(ScenarioDefinition def) {
    if (def.weatherMode != 'low_visibility' ||
        def.lowVisibilitySpacingMultiplier <= 1) {
      return def.arrivalFlows;
    }
    return def.arrivalFlows
        .map((flow) => ArrivalFlow(
              id: flow.id,
              runwayId: flow.runwayId,
              procedureId: flow.procedureId,
              mergeWaypointId: flow.mergeWaypointId,
              finalFixWaypointId: flow.finalFixWaypointId,
              thresholdWaypointId: flow.thresholdWaypointId,
              goAroundMergeWaypointId: flow.goAroundMergeWaypointId,
              goAroundRouteWaypointIds: flow.goAroundRouteWaypointIds,
              spacingTargetNm:
                  flow.spacingTargetNm * def.lowVisibilitySpacingMultiplier,
              stabilizedAltitudeFt: flow.stabilizedAltitudeFt,
            ))
        .toList(growable: false);
  }

  SimulationSnapshot get snapshot => engine.snapshot;

  SimulationSnapshot tick({int speedMultiplier = 1}) {
    final multiplier = speedMultiplier < 1 ? 1 : speedMultiplier;
    for (var i = 0; i < multiplier; i++) {
      _spawnDueAircraft(engine.snapshot.elapsed);
      _releaseQueuedDepartures(engine.snapshot.elapsed);
      _updateAdaptivePressure(engine.snapshot);
      _evaluateDistractionEvents(engine.snapshot.elapsed);
      final snapshot = engine.tick();
      _generateAndEscalateAlerts(snapshot);
      _evaluateGoAroundTriggers(snapshot);
      _recordSeparationLosses(snapshot);
      _markLandedAircraft(snapshot);
      _markExitedAircraft(snapshot);
    }
    _spawnDueAircraft(engine.snapshot.elapsed);
    _releaseQueuedDepartures(engine.snapshot.elapsed);
    _updateAdaptivePressure(engine.snapshot);
    _evaluateDistractionEvents(engine.snapshot.elapsed);
    _generateAndEscalateAlerts(engine.snapshot);
    return _buildSnapshotWithAlerts(engine.snapshot);
  }

  /// Builds a new snapshot including active alerts.
  SimulationSnapshot _buildSnapshotWithAlerts(SimulationSnapshot baseSnapshot) {
    // Update cognitive load engine from current simulation state
    final cognitiveLoad = _updateCognitiveLoad(baseSnapshot);

    // Sync alert manager: expire stale alerts, then sync from legacy alerts
    _alertManager.tick(baseSnapshot.elapsed);
    _syncOperationalAlerts(baseSnapshot);

    // Overload Response System — run each tick
    _currentDegradation =
        WorkloadDegradation.fromLoadScore(cognitiveLoad.totalLoadScore);
    _lastAttentionResult = _attentionEngine.evaluate(
      activeAlerts: _alertManager.activeAlerts,
      recentCommandCount: _recentCommandTimestamps.length,
    );
    _lastTunnelVisionState = _tunnelVisionEngine.tick(baseSnapshot.elapsed);
    final effectiveSelectedAircraft = _effectiveSelectedAircraftForAttention(
      elapsed: baseSnapshot.elapsed,
      requestedAircraftId: _selectedAircraftIdForAttention,
    );
    _lastAttentionFocusState = _attentionV1Engine.evaluate(
      snapshot: baseSnapshot,
      selectedAircraftId: effectiveSelectedAircraft,
      selectedRunwayId: _selectedRunwayIdForAttention,
      selectedAlertId: _selectedAlertIdForAttention,
      cognitiveLoad: cognitiveLoad,
      operationalAlerts: _alertManager.activeAlerts,
    );
    _recordAttentionDisciplineEvents(
      elapsed: baseSnapshot.elapsed,
      previous: _previousAttentionFocusState,
      current: _lastAttentionFocusState,
    );
    _previousAttentionFocusState = _lastAttentionFocusState;
    _attentionHistory.add(_lastAttentionFocusState);
    if (_attentionHistory.length > 240) {
      _attentionHistory.removeAt(0);
    }
    final attentionReport =
        attention_v1.AttentionReplayAnalytics(states: _attentionHistory)
            .generate();
    _lastPsychologyState = _pressurePacingEngine.evaluate(
      _snapshotForPsychology(baseSnapshot, cognitiveLoad),
    );
    _syncPsychologyTrapAlert(baseSnapshot.elapsed, _lastPsychologyState);
    _lastExpectationState = _expectationTracker.evaluate(
      _snapshotForMentalModel(baseSnapshot, cognitiveLoad),
    );
    _lastPredictiveMentalModelState = _predictiveMentalModelEngine.evaluate(
      snapshot: _snapshotForMentalModel(baseSnapshot, cognitiveLoad),
      expectationState: _lastExpectationState,
      attentionFocus: _lastAttentionFocusState,
      cognitiveLoad: cognitiveLoad,
    );
    _applyPredictiveMentalModelEffects(
      elapsed: baseSnapshot.elapsed,
      state: _lastPredictiveMentalModelState,
    );
    _lastCognitiveCascadeState = _cognitiveCascadeEngine.evaluate(
      snapshot: _snapshotForMentalModel(baseSnapshot, cognitiveLoad),
      predictive: _lastPredictiveMentalModelState,
      attention: _lastAttentionFocusState,
      workingMemory: _lastWorkingMemoryState,
      expectation: _lastExpectationState,
    );
    _applyCognitiveCascadeEffects(
      elapsed: baseSnapshot.elapsed,
      state: _lastCognitiveCascadeState,
    );
    _lastWorkingMemoryState = _workingMemoryEngine.evaluate(
      snapshot: _snapshotForMentalModel(baseSnapshot, cognitiveLoad),
      attentionFocus: _lastAttentionFocusState,
      cognitiveLoad: cognitiveLoad,
      operationalAlerts: _alertManager.activeAlerts,
    );
    _recordWorkingMemoryEvents(
      elapsed: baseSnapshot.elapsed,
      previous: _previousWorkingMemoryState,
      current: _lastWorkingMemoryState,
    );
    _previousWorkingMemoryState = _lastWorkingMemoryState;

    // Feed analytics tracker
    _analyticsTracker.recordTick(ReplayWorkloadFrame(
      elapsed: baseSnapshot.elapsed,
      workloadScore: cognitiveLoad.totalLoadScore,
      loadLevel: cognitiveLoad.currentLevel,
      activeAlerts: _alertManager.activeAlerts,
      activeStressors: cognitiveLoad.activeStressors,
    ));
    _analyticsTracker.recordFixationState(
      fixatedObjectId: _lastTunnelVisionState.fixatedObjectId,
      elapsed: baseSnapshot.elapsed,
      detectionLatencySeconds: _lastTunnelVisionState.detectionLatencySeconds,
      ignoredAlertDuration: _lastTunnelVisionState.ignoredAlertDuration,
    );

    return SimulationSnapshot(
      tick: baseSnapshot.tick,
      elapsed: baseSnapshot.elapsed,
      aircraft: baseSnapshot.aircraft,
      separation: baseSnapshot.separation,
      trails: baseSnapshot.trails,
      waypoints: baseSnapshot.waypoints,
      weatherZones: baseSnapshot.weatherZones,
      arrivalFlows: baseSnapshot.arrivalFlows,
      departureFlows: baseSnapshot.departureFlows,
      holdPatterns: baseSnapshot.holdPatterns,
      runwayStates: baseSnapshot.runwayStates,
      maxControllerLoad: baseSnapshot.maxControllerLoad,
      sectorPressureIndex: baseSnapshot.sectorPressureIndex,
      events: baseSnapshot.events,
      activeAlerts: List<ControllerAlert>.from(_activeAlerts.values),
      activeDistractions: Set<String>.from(_activeDistractionUntil.keys),
      distractionEfficiencyPenalty:
          getDistractionEfficiencyPenalty(baseSnapshot.elapsed),
      cognitiveLoad: cognitiveLoad,
      operationalAlerts: _alertManager.activeAlerts,
      attentionFocus: _lastAttentionFocusState,
      attentionReportLines: [
        ..._lastAttentionFocusState.reportLines,
        ...attentionReport.reportLines,
        ..._lastPsychologyState.reportLines,
        ..._lastExpectationState.reportLines,
        ..._lastPredictiveMentalModelState.reportLines,
        ..._lastCognitiveCascadeState.reportLines,
      ].take(5).toList(growable: false),
      psychologyState: _lastPsychologyState,
      expectationState: _lastExpectationState,
      predictiveMentalModelState: _lastPredictiveMentalModelState,
      predictiveMentalModelReportLines:
          List<String>.from(_lastPredictiveMentalModelState.reportLines),
      cognitiveCascadeState: _lastCognitiveCascadeState,
      cognitiveCascadeReportLines:
          List<String>.from(_lastCognitiveCascadeState.reportLines),
      workingMemoryState: _lastWorkingMemoryState,
      workingMemoryReportLines:
          List<String>.from(_lastWorkingMemoryState.reportLines),
    );
  }

  String? _effectiveSelectedAircraftForAttention({
    required Duration elapsed,
    required String? requestedAircraftId,
  }) {
    if (_stickyFocusUntil == null ||
        _stickyFocusTarget == null ||
        elapsed >= (_stickyFocusUntil ?? elapsed)) {
      return requestedAircraftId;
    }
    if (_stickyFocusTarget!.startsWith('aircraft:')) {
      return _stickyFocusTarget!.substring('aircraft:'.length);
    }
    return requestedAircraftId;
  }

  SimulationSnapshot _snapshotForPsychology(
    SimulationSnapshot base,
    CognitiveLoadState cognitiveLoad,
  ) {
    return SimulationSnapshot(
      tick: base.tick,
      elapsed: base.elapsed,
      aircraft: base.aircraft,
      separation: base.separation,
      trails: base.trails,
      waypoints: base.waypoints,
      weatherZones: base.weatherZones,
      arrivalFlows: base.arrivalFlows,
      departureFlows: base.departureFlows,
      holdPatterns: base.holdPatterns,
      runwayStates: base.runwayStates,
      maxControllerLoad: base.maxControllerLoad,
      sectorPressureIndex: base.sectorPressureIndex,
      events: base.events,
      activeAlerts: List<ControllerAlert>.from(_activeAlerts.values),
      activeDistractions: Set<String>.from(_activeDistractionUntil.keys),
      distractionEfficiencyPenalty:
          getDistractionEfficiencyPenalty(base.elapsed),
      cognitiveLoad: cognitiveLoad,
      operationalAlerts: _alertManager.activeAlerts,
      attentionFocus: _lastAttentionFocusState,
    );
  }

  SimulationSnapshot _snapshotForMentalModel(
    SimulationSnapshot base,
    CognitiveLoadState cognitiveLoad,
  ) {
    return SimulationSnapshot(
      tick: base.tick,
      elapsed: base.elapsed,
      aircraft: base.aircraft,
      separation: base.separation,
      trails: base.trails,
      waypoints: base.waypoints,
      weatherZones: base.weatherZones,
      arrivalFlows: base.arrivalFlows,
      departureFlows: base.departureFlows,
      holdPatterns: base.holdPatterns,
      runwayStates: base.runwayStates,
      maxControllerLoad: base.maxControllerLoad,
      sectorPressureIndex: base.sectorPressureIndex,
      events: base.events,
      activeAlerts: List<ControllerAlert>.from(_activeAlerts.values),
      activeDistractions: Set<String>.from(_activeDistractionUntil.keys),
      distractionEfficiencyPenalty:
          getDistractionEfficiencyPenalty(base.elapsed),
      cognitiveLoad: cognitiveLoad,
      operationalAlerts: _alertManager.activeAlerts,
      attentionFocus: _lastAttentionFocusState,
      psychologyState: _lastPsychologyState,
    );
  }

  void _syncPsychologyTrapAlert(
    Duration elapsed,
    ScenarioPsychologyState state,
  ) {
    const id = 'psychology:attention_trap';
    if (!state.attentionTrapActive) {
      _alertManager.dismiss(id);
      return;
    }
    _alertManager.registerOnce(OperationalAlert(
      id: id,
      type: OperationalAlertType.runwayChange,
      priority: AlertPriority.low,
      createdAt: elapsed,
      expiresAt: elapsed + const Duration(seconds: 12),
      workloadImpact: 2,
    ));
  }

  /// Calculates cognitive load from current snapshot state.
  CognitiveLoadState _updateCognitiveLoad(SimulationSnapshot snapshot) {
    final activeAircraft = snapshot.aircraft.where((a) => a.active).length;
    final unresolvedConflicts = snapshot.separation
        .where((r) => r.isLossOfSeparation || r.isPredictedConflict)
        .length;
    final occupiedRunways = snapshot.runwayStates
        .where((r) => r.isOccupiedAt(snapshot.elapsed))
        .length;
    final weatherSeverity =
        snapshot.weatherZones.fold<int>(0, (sum, z) => sum + z.severity);
    final escalationCount =
        _activeAlerts.values.fold<int>(0, (sum, a) => sum + a.escalationCount);

    // Evict command timestamps older than 30s
    final cutoff = snapshot.elapsed > const Duration(seconds: 30)
        ? snapshot.elapsed - const Duration(seconds: 30)
        : Duration.zero;
    _recentCommandTimestamps.removeWhere((t) => t < cutoff);

    final inputs = CognitiveLoadInputs(
      unresolvedConflicts: unresolvedConflicts,
      simultaneousAlerts:
          _activeAlerts.length + _alertManager.activeAlerts.length,
      activeAircraftCount: activeAircraft,
      departureQueueSize: _queuedDepartures.length,
      occupiedRunwayCount: occupiedRunways,
      weatherSeverityTotal: weatherSeverity,
      goAroundCount: _totalGoAroundCount,
      recentCommandCount: _recentCommandTimestamps.length,
      alertEscalationCount: escalationCount,
    );
    return _cognitiveLoadEngine.calculate(inputs, snapshot.elapsed);
  }

  /// Synchronises the [AlertManager] from the legacy [_activeAlerts] map so
  /// the two systems remain consistent during the migration period.
  void _syncOperationalAlerts(SimulationSnapshot snapshot) {
    // Register any legacy alerts not yet in the manager
    for (final legacyAlert in _activeAlerts.values) {
      final opType = _legacyAlertTypeToOperational(legacyAlert.type);
      _alertManager.registerOnce(OperationalAlert(
        id: 'legacy:${legacyAlert.id}',
        type: opType,
        priority: OperationalAlertType.defaultPriority(opType),
        createdAt: legacyAlert.createdAt,
        workloadImpact: OperationalAlertType.workloadImpact(opType),
        acknowledged: legacyAlert.acknowledged,
        relatedAircraftIds: legacyAlert.aircraftIds,
        relatedRunwayId: legacyAlert.runwayId,
      ));
    }

    // Dismiss manager entries whose legacy counterpart no longer exists
    final legacyIds = _activeAlerts.keys.map((k) => 'legacy:$k').toSet();
    for (final alert
        in List<OperationalAlert>.from(_alertManager.activeAlerts)) {
      if (alert.id.startsWith('legacy:') && !legacyIds.contains(alert.id)) {
        _alertManager.dismiss(alert.id);
      }
    }
  }

  /// Maps a [AlertType] enum value to an [OperationalAlertType] string.
  String _legacyAlertTypeToOperational(AlertType type) => switch (type) {
        AlertType.separationLoss => OperationalAlertType.separationLoss,
        AlertType.goAround => OperationalAlertType.goAround,
        AlertType.unstableApproach => OperationalAlertType.unstableSpacing,
        AlertType.weatherEscalation => OperationalAlertType.weatherEscalation,
        AlertType.runwayOccupancy => OperationalAlertType.runwayOccupancy,
        AlertType.departureQueueBacklog =>
          OperationalAlertType.departureQueueSaturation,
        AlertType.lowFuelWarning => OperationalAlertType.lowFuel,
        AlertType.medicalEmergency => OperationalAlertType.medicalEmergency,
        AlertType.distractionEvent => OperationalAlertType.runwayChange,
      };

  /// Returns the number of aircraft currently held from spawning due to high pressure.
  int get heldSpawnCount => _spawnHeldUntil.length;

  /// Records a command timestamp for recent-command-density tracking.
  /// Call this when the controller issues a command so the cognitive load
  /// engine can detect command bursts.
  void recordCommandTimestamp(
    Duration elapsed, {
    String? aircraftId,
    String? runwayId,
  }) {
    _recentCommandTimestamps.add(elapsed);
    _analyticsTracker.recordCommand(
      elapsed: elapsed,
      aircraftId: aircraftId ?? '',
    );
    if (aircraftId != null) {
      _tunnelVisionEngine.recordInteraction(
        aircraftId: aircraftId,
        runwayId: runwayId,
        elapsed: elapsed,
      );
    }
  }

  /// Exposes the [AlertManager] for acknowledgements from the UI layer.
  AlertManager get alertManager => _alertManager;

  /// Current workload degradation parameters driven by cognitive load.
  WorkloadDegradation get currentDegradation => _currentDegradation;

  /// Last attention competition evaluation result.
  pressure.AttentionCompetitionResult get lastAttentionResult =>
      _lastAttentionResult;
  AttentionFocusState get lastAttentionFocusState => _lastAttentionFocusState;

  /// Last tunnel-vision state snapshot.
  TunnelVisionState get lastTunnelVisionState => _lastTunnelVisionState;

  /// Generates the full cognition analytics report for the completed scenario.
  CognitionAnalyticsReport generateCognitionReport() =>
      _analyticsTracker.generateReport(engine.snapshot.elapsed);

  attention_v1.AttentionReplaySummary generateAttentionReport() =>
      attention_v1.AttentionReplayAnalytics(states: _attentionHistory)
          .generate();

  void updateAttentionFocus({
    String? selectedAircraftId,
    String? selectedRunwayId,
    String? selectedAlertId,
  }) {
    _selectedAircraftIdForAttention = selectedAircraftId;
    _selectedRunwayIdForAttention = selectedRunwayId;
    _selectedAlertIdForAttention = selectedAlertId;
  }

  /// Returns the current sector pressure index (0–5 scale).
  double get currentSectorPressure => _currentSectorPressure;
  ScenarioPsychologyState get lastPsychologyState => _lastPsychologyState;
  ControllerExpectationState get lastExpectationState => _lastExpectationState;
  PredictiveMentalModelState get lastPredictiveMentalModelState =>
      _lastPredictiveMentalModelState;
    CognitiveCascadeState get lastCognitiveCascadeState =>
      _lastCognitiveCascadeState;
  WorkingMemoryState get lastWorkingMemoryState => _lastWorkingMemoryState;

  void _applyPredictiveMentalModelEffects({
    required Duration elapsed,
    required PredictiveMentalModelState state,
  }) {
    for (final mismatch in state.newlyDetectedMismatches) {
      final alertId = 'predictive:${mismatch.id}';
      final alertType = OperationalAlertType.abnormalBehavior;
      final critical = mismatch.type == PredictionMismatchType.missedHandoff ||
          mismatch.type == PredictionMismatchType.wrongAltitudeTrend;
      _alertManager.register(OperationalAlert(
        id: alertId,
        type: alertType,
        priority: critical ? AlertPriority.critical : AlertPriority.high,
        createdAt: elapsed,
        expiresAt: elapsed + const Duration(seconds: 25),
        workloadImpact: critical ? 7 : 6,
        relatedAircraftIds: [mismatch.aircraftId],
      ));
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'predictionMismatch',
        label:
            '${mismatch.aircraftId} ${mismatch.typeLabel} (sev ${mismatch.severity.toStringAsFixed(2)})',
        aircraftId: mismatch.aircraftId,
      ));
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'attentionInterrupt',
        label: 'surprise_reallocation:${mismatch.aircraftId}',
        aircraftId: mismatch.aircraftId,
      ));
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'predictiveUrgentReevaluation',
        label: 'Urgent re-evaluation triggered for ${mismatch.aircraftId}',
        aircraftId: mismatch.aircraftId,
      ));
      if (mismatch.lateRecognition) {
        engine.recordEvent(SimulationEvent(
          elapsed: elapsed,
          type: 'predictionLateRecognition',
          label: 'Late recognition of abnormal behavior for ${mismatch.aircraftId}',
          aircraftId: mismatch.aircraftId,
        ));
      }
    }

    for (final resolved in state.resolvedMismatchIds) {
      _alertManager.dismiss('predictive:$resolved');
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'predictionRecovered',
        label: 'Prediction mismatch resolved ($resolved)',
      ));
    }

    if (state.surpriseLoad >= 0.72 && state.newlyDetectedMismatches.isNotEmpty) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'predictionSurpriseOverload',
        label:
            'Surprise overload moment ${(state.surpriseLoad * 100).round()}%',
      ));
    }
  }

  void _applyCognitiveCascadeEffects({
    required Duration elapsed,
    required CognitiveCascadeState state,
  }) {
    if (state.chainStartedThisTick) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'cognitiveCascadeChain',
        label: 'Cascade started from ${state.rootSurpriseLabel ?? 'unknown'}',
      ));
    }
    if (state.secondaryFailuresThisTick.isNotEmpty) {
      for (final secondary in state.secondaryFailuresThisTick) {
        engine.recordEvent(SimulationEvent(
          elapsed: elapsed,
          type: 'cognitiveCascadeSecondaryFailure',
          label: secondary,
        ));
      }
    }
    if (state.chainEndedThisTick) {
      final recent = state.chainHistory.isEmpty ? null : state.chainHistory.last;
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'cognitiveCascadeRecovery',
        label: recent == null
            ? 'Cascade recovery assessed'
            : 'Cascade recovery quality ${recent.recoveryQuality.toStringAsFixed(2)}',
      ));
    }

    if (state.stickyFocusActive) {
      _stickyFocusUntil = elapsed + const Duration(seconds: 10);
      _stickyFocusTarget = _lastAttentionFocusState.currentFocusTarget;
    } else if (_stickyFocusUntil != null && elapsed >= _stickyFocusUntil!) {
      _stickyFocusUntil = null;
      _stickyFocusTarget = null;
    }

    if (state.intentionInterruptionActive || state.recoveryInstabilityActive) {
      _activeDistractionUntil['cascade:${state.activeChainId ?? 'recovery'}'] =
          elapsed + const Duration(seconds: 12);
    }

    if (state.scanQualityPenalty >= 0.18) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'attentionScanDisruption',
        label: 'Cascade scan penalty ${(state.scanQualityPenalty * 100).round()}%',
      ));
    }
    if (state.recoveryInstabilityActive) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'cognitiveRecoveryInstability',
        label: 'Recovery instability: over-correction risk elevated',
      ));
    }
  }

  void _recordWorkingMemoryEvents({
    required Duration elapsed,
    required WorkingMemoryState previous,
    required WorkingMemoryState current,
  }) {
    if (current.forgottenIntentionCount > previous.forgottenIntentionCount) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'workingMemoryForgotten',
        label: 'Pending intention lost salience and was forgotten',
      ));
    }
    if (current.recoveredTaskCount > previous.recoveredTaskCount) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'workingMemoryRecovered',
        label: 'Forgotten intention recovered late',
      ));
    }
    if (current.catchUpBurstCount > previous.catchUpBurstCount) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'workingMemoryCatchUp',
        label: 'Catch-up burst followed reminder recovery',
      ));
    }
    if (current.interruptedWorkflowCount > previous.interruptedWorkflowCount) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'workingMemoryInterrupted',
        label: 'Task chain interrupted by competing demand',
      ));
    }
  }

  /// Returns upcoming spawn times within the next [lookAheadSeconds], sorted ascending.
  /// Useful for UI to show imminent traffic load forecast.
  List<Duration> upcomingSpawnTimes({
    Duration? fromElapsed,
    int lookAheadSeconds = 120,
  }) {
    final elapsed = fromElapsed ?? engine.snapshot.elapsed;
    final horizon = elapsed + Duration(seconds: lookAheadSeconds);
    final results = <Duration>[];
    for (final spawn in definition.aircraft) {
      if (_spawnedIds.contains(spawn.id)) continue;
      final scaledSpawnAt = Duration(
        milliseconds:
            (spawn.spawnAt.inMilliseconds / definition.densityScale).round(),
      );
      if (scaledSpawnAt >= elapsed && scaledSpawnAt <= horizon) {
        results.add(scaledSpawnAt);
      }
    }
    results.sort();
    return results;
  }

  ScenarioResultState evaluate() {
    final snapshot = engine.snapshot;
    final reasons = <String>[];

    for (final condition in definition.failConditions) {
      if (condition.type == 'separationLoss' && _separationLossCount > 0) {
        reasons.add('Separation loss detected');
      }
      if (condition.type == 'timeout' &&
          snapshot.elapsed >= definition.duration &&
          !_allAircraftSpawned) {
        reasons.add('Scenario timed out before all traffic spawned');
      }
    }

    if (reasons.isNotEmpty) {
      return ScenarioResultState(
          complete: true, failed: true, reasons: reasons);
    }

    final reachedDuration = snapshot.elapsed >= definition.duration;
    final exitedSafely = _allAircraftSpawned && _allSpawnedAircraftExited;

    if (_allAircraftSpawned && (reachedDuration || exitedSafely)) {
      final winReasons = <String>[];
      for (final condition in definition.winConditions) {
        if (condition.type == 'maxSeparationLosses') {
          final maxLosses = condition.value ?? 0;
          if (_separationLossCount > maxLosses) {
            return const ScenarioResultState.running();
          }
          winReasons.add('No excessive separation losses');
        }
        if (condition.type == 'allAircraftSpawned' && _allAircraftSpawned) {
          winReasons.add('All aircraft spawned');
        }
        if (condition.type == 'durationReached' && reachedDuration) {
          winReasons.add('Scenario duration reached');
        }
        if (condition.type == 'allAircraftExitedSafely' && exitedSafely) {
          winReasons.add('All aircraft exited safely');
        }
      }
      if (winReasons.isNotEmpty) {
        return ScenarioResultState(
          complete: true,
          failed: false,
          reasons: winReasons,
        );
      }
    }

    return const ScenarioResultState.running();
  }

  bool get _allAircraftSpawned =>
      _spawnedIds.length == definition.aircraft.length;

  bool get _allSpawnedAircraftExited =>
      _spawnedIds.isNotEmpty && _spawnedIds.every(_exitedIds.contains);

  void _spawnDueAircraft(Duration elapsed) {
    // Release any hold expirations first
    _spawnHeldUntil.removeWhere((_, deadline) => elapsed >= deadline);

    for (final spawn in definition.aircraft) {
      if (_spawnedIds.contains(spawn.id)) continue;
      final scaledSpawnAt = Duration(
        milliseconds:
            (spawn.spawnAt.inMilliseconds / definition.densityScale).round(),
      );
      if (scaledSpawnAt > elapsed) continue;

      // Apply dynamic pacing hold if pressure is too high
      if (_spawnHeldUntil.containsKey(spawn.id)) {
        // Still held - skip this tick
        continue;
      }

      // Check if this is a fresh spawn during high pressure
      if (_lastPsychologyState.deceptiveCalmActive &&
          elapsed < scaledSpawnAt + const Duration(seconds: 12)) {
        _spawnHeldUntil[spawn.id] = scaledSpawnAt + const Duration(seconds: 12);
        continue;
      }

      if (_currentSectorPressure >= _spawnHoldPressureThreshold) {
        // Hold spawning if deadline hasn't passed yet
        final deadline = scaledSpawnAt + _maxSpawnHoldDuration;
        if (elapsed < deadline) {
          _spawnHeldUntil[spawn.id] = deadline;
          continue;
        }
        // Deadline passed - spawn regardless of pressure
        _spawnHeldUntil.remove(spawn.id);
      }

      if (spawn.isDeparture) {
        _queuedDepartures[spawn.id] = spawn;
        _spawnedIds.add(spawn.id);
        engine.recordEvent(SimulationEvent(
          elapsed: elapsed,
          type: 'departureQueued',
          label: '${spawn.callsign} queued for departure',
          aircraftId: spawn.id,
        ));
        continue;
      }
      _spawnAndActivate(spawn, elapsed, releasedAsDeparture: false);
    }
  }

  void _spawnAndActivate(
    AircraftSpawnDefinition spawn,
    Duration elapsed, {
    required bool releasedAsDeparture,
  }) {
    final departureFlow = _departureFlowFor(spawn.departureFlowId);
    final procedure = spawn.procedureId == null
        ? null
        : definition.routeProcedures[spawn.procedureId!];
    final route = spawn.initialState.intent.route.isNotEmpty
        ? spawn.initialState.intent.route
        : (procedure?.waypointIds ?? const <String>[]);
    var state = spawn.initialState.copyWith(
      intent: spawn.initialState.intent.copyWith(
        route: route,
        assignedProcedureId: spawn.procedureId,
        isDeparture: spawn.isDeparture,
        assignedAltitudeFt:
            spawn.isDeparture ? departureFlow?.initialClimbFt : null,
      ),
      routeWaypointIndex: 0,
    );
    state = _scaledAircraft(state);
    engine.addAircraft(state);
    _spawnedIds.add(spawn.id);
    engine.recordEvent(SimulationEvent(
      elapsed: elapsed,
      type: releasedAsDeparture ? 'departureReleased' : 'sectorEntry',
      label: releasedAsDeparture
          ? '${spawn.callsign} departure released'
          : '${spawn.callsign} entered sector',
      aircraftId: spawn.id,
    ));
  }

  void _releaseQueuedDepartures(Duration elapsed) {
    if (_queuedDepartures.isEmpty) return;
    final queue = _queuedDepartures.values.toList(growable: false);
    for (final spawn in queue) {
      final flow = _departureFlowFor(spawn.departureFlowId);
      if (flow == null) {
        _spawnAndActivate(spawn, elapsed, releasedAsDeparture: true);
        _queuedDepartures.remove(spawn.id);
        continue;
      }
      if (!_canReleaseDeparture(flow, elapsed)) continue;
      _spawnAndActivate(spawn, elapsed, releasedAsDeparture: true);
      _queuedDepartures.remove(spawn.id);
      _lastDepartureReleaseByRunway[flow.runwayId] = elapsed;
      engine.occupyRunway(
        runwayId: flow.runwayId,
        duration: _scaledDuration(_effectiveRunwayOccupancy(), 0.6),
        aircraftId: spawn.id,
      );
    }
  }

  bool _canReleaseDeparture(DepartureFlow flow, Duration elapsed) {
    final state = engine.snapshot.runwayState(flow.runwayId);
    if (state != null && state.isOccupiedAt(elapsed)) {
      return false;
    }
    for (final crossing in flow.crossingRunwayIds) {
      final crossingState = engine.snapshot.runwayState(crossing);
      if (crossingState != null && crossingState.isOccupiedAt(elapsed)) {
        return false;
      }
    }
    final lastRelease = _lastDepartureReleaseByRunway[flow.runwayId];
    if (lastRelease != null &&
        elapsed - lastRelease <
            Duration(seconds: flow.releaseIntervalSeconds)) {
      return false;
    }
    return !_arrivalOnShortFinal(flow.runwayId);
  }

  bool _arrivalOnShortFinal(String runwayId) {
    final flow = _arrivalFlowForRunway(runwayId);
    if (flow == null) return false;
    final threshold = definition.waypoints[flow.thresholdWaypointId];
    if (threshold == null) return false;
    return engine.snapshot.aircraft.any((aircraft) {
      if (!aircraft.active || aircraft.intent.isDeparture) return false;
      if (aircraft.intent.assignedRunwayId != runwayId) return false;
      final distance = _distance(
        aircraft.xNm,
        aircraft.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      return distance <= 6;
    });
  }

  AircraftState _scaledAircraft(AircraftState aircraft) {
    final speedBoost = 1 + (definition.difficulty.clamp(1, 5) - 1) * 0.035;
    return aircraft.copyWith(
        groundSpeedKt: aircraft.groundSpeedKt * speedBoost);
  }

  void _evaluateGoAroundTriggers(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || aircraft.intent.isDeparture) continue;
      if (_goAroundIssued.contains(aircraft.id)) continue;
      final runwayId = aircraft.intent.assignedRunwayId;
      if (runwayId == null) continue;
      final flow = _arrivalFlowForRunway(runwayId);
      if (flow == null) continue;
      final threshold = definition.waypoints[flow.thresholdWaypointId];
      if (threshold == null) continue;

      final runwayState = snapshot.runwayState(runwayId);
      final distanceToThreshold = _distance(
        aircraft.xNm,
        aircraft.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      if (runwayState != null &&
          runwayState.isOccupiedAt(snapshot.elapsed) &&
          distanceToThreshold < 6 &&
          runwayState.occupiedUntil - snapshot.elapsed >=
              const Duration(seconds: 16)) {
        _executeGoAround(
          aircraft,
          flow,
          reason: 'runway occupied',
          elapsed: snapshot.elapsed,
        );
        continue;
      }
      if (_hasUnstableFinalSpacing(snapshot, aircraft, flow)) {
        _executeGoAround(
          aircraft,
          flow,
          reason: 'unstable spacing',
          elapsed: snapshot.elapsed,
        );
        continue;
      }
      if (_hasCloseFinalPair(snapshot, aircraft, flow)) {
        _executeGoAround(
          aircraft,
          flow,
          reason: 'aircraft too close on final',
          elapsed: snapshot.elapsed,
        );
      }
    }
  }

  bool _hasUnstableFinalSpacing(
    SimulationSnapshot snapshot,
    AircraftState aircraft,
    ArrivalFlow flow,
  ) {
    final threshold = definition.waypoints[flow.thresholdWaypointId];
    if (threshold == null) return false;
    final sameRunway = snapshot.aircraft.where((candidate) {
      return candidate.active &&
          !candidate.intent.isDeparture &&
          candidate.intent.assignedRunwayId == flow.runwayId;
    }).toList(growable: false);
    sameRunway.sort((a, b) {
      final ad = _distance(a.xNm, a.yNm, threshold.xNm, threshold.yNm);
      final bd = _distance(b.xNm, b.yNm, threshold.xNm, threshold.yNm);
      return ad.compareTo(bd);
    });
    final index =
        sameRunway.indexWhere((candidate) => candidate.id == aircraft.id);
    if (index <= 0) return false;
    final leader = sameRunway[index - 1];
    final spacing =
        _distance(aircraft.xNm, aircraft.yNm, leader.xNm, leader.yNm);
    final instability =
        0.72 + _lastPsychologyState.spacingInstabilityProbability * 0.45;
    return spacing < flow.spacingTargetNm * instability.clamp(0.72, 0.95);
  }

  bool _hasCloseFinalPair(
    SimulationSnapshot snapshot,
    AircraftState aircraft,
    ArrivalFlow flow,
  ) {
    final threshold = definition.waypoints[flow.thresholdWaypointId];
    if (threshold == null) return false;
    final ownDistance =
        _distance(aircraft.xNm, aircraft.yNm, threshold.xNm, threshold.yNm);
    if (ownDistance > 8) return false;
    for (final candidate in snapshot.aircraft) {
      if (candidate.id == aircraft.id || !candidate.active) continue;
      if (candidate.intent.isDeparture) continue;
      if (candidate.intent.assignedRunwayId != flow.runwayId) continue;
      final candidateDistance = _distance(
        candidate.xNm,
        candidate.yNm,
        threshold.xNm,
        threshold.yNm,
      );
      if (candidateDistance > 8) continue;
      final pairDistance = _distance(
        aircraft.xNm,
        aircraft.yNm,
        candidate.xNm,
        candidate.yNm,
      );
      if (pairDistance < math.max(2.8, flow.spacingTargetNm * 0.45)) {
        return true;
      }
    }
    return false;
  }

  void _executeGoAround(
    AircraftState aircraft,
    ArrivalFlow flow, {
    required String reason,
    required Duration elapsed,
  }) {
    final goAroundRoute = flow.goAroundRouteWaypointIds.isNotEmpty
        ? flow.goAroundRouteWaypointIds
        : <String>[
            flow.mergeWaypointId,
            flow.finalFixWaypointId,
            flow.thresholdWaypointId
          ];
    final targetAltitude = flow.stabilizedAltitudeFt + 3000;
    final updated = aircraft.copyWith(
      routeWaypointIndex: 0,
      intent: aircraft.intent.copyWith(
        route: goAroundRoute,
        assignedAltitudeFt: targetAltitude,
        assignedSpeedKt: math.max(aircraft.groundSpeedKt, 190).toDouble(),
        clearAssignedHeading: true,
        clearDirectTo: true,
        hold: false,
        clearHoldPattern: true,
      ),
    );
    _goAroundIssued.add(aircraft.id);
    _totalGoAroundCount += 1;
    _pressureCarryOver += 0.5;
    engine
      ..updateAircraft(updated)
      ..recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'goAround',
        label: '${aircraft.callsign} go-around: $reason',
        aircraftId: aircraft.id,
      ));
  }

  void _updateAdaptivePressure(SimulationSnapshot snapshot) {
    final active = snapshot.aircraft.where((item) => item.active).length;
    final occupiedRunways = snapshot.runwayStates
        .where((state) => state.isOccupiedAt(snapshot.elapsed))
        .length;
    final weatherComplexity = snapshot.weatherZones
        .fold<int>(0, (total, zone) => total + zone.severity);
    final spawnOverlap = _imminentSpawnCount(snapshot.elapsed);
    final queuePressure = _queuedDepartures.length;

    var pressure = (active / math.max(1, definition.maxControllerLoad)) - 1;
    pressure += weatherComplexity * 0.14;
    pressure += occupiedRunways * 0.24;
    pressure += spawnOverlap * 0.11;
    pressure += queuePressure * 0.18;
    pressure += _pressureCarryOver;
    pressure *= definition.workloadPressureMultiplier;
    pressure *= _lastPsychologyState.pressureMultiplier;
    pressure = pressure.clamp(0, 5.0);
    _pressureCarryOver = (_pressureCarryOver * 0.92).clamp(0, 2.0);
    _currentSectorPressure = pressure;

    final dynamicLoad =
        (definition.maxControllerLoad - pressure.round()).clamp(3, 9);
    engine.updateWorkloadState(
      dynamicControllerLoad: dynamicLoad,
      sectorPressureIndex: pressure,
    );
  }

  int _imminentSpawnCount(Duration elapsed) {
    var count = 0;
    for (final spawn in definition.aircraft) {
      if (_spawnedIds.contains(spawn.id)) continue;
      final scaledSpawnAt = Duration(
        milliseconds:
            (spawn.spawnAt.inMilliseconds / definition.densityScale).round(),
      );
      final delta = scaledSpawnAt - elapsed;
      if (delta >= Duration.zero && delta <= const Duration(seconds: 45)) {
        count += 1;
      }
    }
    return count;
  }

  void _recordSeparationLosses(SimulationSnapshot snapshot) {
    for (final result
        in snapshot.separation.where((result) => result.isLossOfSeparation)) {
      _separationLossCount += 1;
      engine.recordEvent(SimulationEvent(
        elapsed: snapshot.elapsed,
        type: 'separationLoss',
        label: 'Loss ${result.aircraftAId}/${result.aircraftBId}',
        aircraftId: result.aircraftAId,
      ));
    }
  }

  void _markExitedAircraft(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || _exitedIds.contains(aircraft.id)) continue;
      if (_isOutsideRadarRange(aircraft)) {
        _exitedIds.add(aircraft.id);
        engine.recordEvent(SimulationEvent(
          elapsed: snapshot.elapsed,
          type: 'aircraftExited',
          label: '${aircraft.callsign} exited radar',
          aircraftId: aircraft.id,
        ));
        engine.deactivateAircraft(aircraft.id);
      }
    }
  }

  void _markLandedAircraft(SimulationSnapshot snapshot) {
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || _exitedIds.contains(aircraft.id)) continue;
      if (aircraft.intent.isDeparture) continue;
      final runwayId = aircraft.intent.assignedRunwayId;
      if (runwayId == null) continue;
      final flow = _arrivalFlowForRunway(runwayId);
      if (flow == null) continue;
      final threshold = definition.waypoints[flow.thresholdWaypointId];
      if (threshold == null) continue;
      final dx = aircraft.xNm - threshold.xNm;
      final dy = aircraft.yNm - threshold.yNm;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > 0.8 * 0.8) continue;

      _exitedIds.add(aircraft.id);
      engine
        ..occupyRunway(
          runwayId: runwayId,
          duration: _effectiveRunwayOccupancy(),
          aircraftId: aircraft.id,
        )
        ..recordEvent(SimulationEvent(
          elapsed: snapshot.elapsed,
          type: 'handoff',
          label: '${aircraft.callsign} landed and handed off',
          aircraftId: aircraft.id,
        ))
        ..deactivateAircraft(aircraft.id);
    }
  }

  Duration _effectiveRunwayOccupancy() {
    final multiplier = definition.weatherMode == 'low_visibility'
        ? definition.lowVisibilityRunwayOccupancyMultiplier
        : 1.0;
    return Duration(
      milliseconds:
          (definition.runwayOccupancyDuration.inMilliseconds * multiplier)
              .round(),
    );
  }

  Duration _scaledDuration(Duration duration, double factor) {
    return Duration(
      milliseconds: (duration.inMilliseconds * factor).round(),
    );
  }

  bool _isOutsideRadarRange(AircraftState aircraft) {
    final distanceSquared =
        aircraft.xNm * aircraft.xNm + aircraft.yNm * aircraft.yNm;
    return distanceSquared > definition.radarRangeNm * definition.radarRangeNm;
  }

  ArrivalFlow? _arrivalFlowForRunway(String runwayId) {
    for (final flow in definition.arrivalFlows) {
      if (flow.runwayId == runwayId) return flow;
    }
    return null;
  }

  DepartureFlow? _departureFlowFor(String? departureFlowId) {
    if (departureFlowId == null) return null;
    for (final flow in definition.departureFlows) {
      if (flow.id == departureFlowId) return flow;
    }
    return null;
  }

  double _distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Evaluates and fires distraction events based on scenario definition timeline.
  /// Tracks active distractions and applies temporary controller performance penalties.
  void _evaluateDistractionEvents(Duration elapsed) {
    // Clear processed tracking from previous tick
    _distractionsProcessedThisTick.clear();

    // Fire any new attention management events due at this elapsed time
    for (final event in definition.attentionManagementEvents) {
      if (_distractionsProcessedThisTick.contains(event.id)) continue;
      if (elapsed < event.scheduledAt ||
          elapsed >= event.scheduledAt + const Duration(seconds: 1)) {
        continue;
      }

      switch (event.type) {
        case 'distraction':
          final durationSecs = (event.duration?.inSeconds ?? 30);
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: durationSecs);
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'radio_chatter:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        case 'runway_change':
          final durationSecs = (event.duration?.inSeconds ?? 22);
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: durationSecs);
          _activeAlerts[event.id] = ControllerAlert(
            id: event.id,
            type: AlertType.distractionEvent,
            severity: 5,
            createdAt: elapsed,
            runwayId: event.targetRunwayId,
          );
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'runway_change:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        case 'weather_escalation':
          final durationSecs = (event.duration?.inSeconds ?? 18);
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: durationSecs);
          _activeAlerts[event.id] = ControllerAlert(
            id: event.id,
            type: AlertType.weatherEscalation,
            severity: (4 + (event.severityIncrease ?? 1)).clamp(1, 10),
            createdAt: elapsed,
          );
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'weather_update:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        case 'simultaneous_alerts':
          final durationSecs = (event.duration?.inSeconds ?? 20);
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: durationSecs);
          _activeAlerts[event.id] = ControllerAlert(
            id: event.id,
            type: AlertType.distractionEvent,
            severity: 6,
            createdAt: elapsed,
          );
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'simultaneous_alerts:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        case 'medical_emergency':
          if (event.targetRunwayId != null) {
            // Target runway is overloaded with the emergency callsign
            _activeAlerts[event.id] = ControllerAlert(
              id: event.id,
              type: AlertType.medicalEmergency,
              severity: 9,
              createdAt: elapsed,
              runwayId: event.targetRunwayId,
            );
          }
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: event.duration?.inSeconds ?? 30);
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'emergency_distraction:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        case 'low_fuel':
          if (event.targetRunwayId != null) {
            _activeAlerts[event.id] = ControllerAlert(
              id: event.id,
              type: AlertType.lowFuelWarning,
              severity: 8,
              createdAt: elapsed,
              runwayId: event.targetRunwayId,
            );
          }
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: event.duration?.inSeconds ?? 28);
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'emergency_distraction:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        case 'engine_failure':
          if (event.targetRunwayId != null) {
            _activeAlerts[event.id] = ControllerAlert(
              id: event.id,
              type: AlertType.medicalEmergency, // Highest priority class
              severity: 10,
              createdAt: elapsed,
              runwayId: event.targetRunwayId,
            );
          }
          _activeDistractionUntil[event.id] =
              elapsed + Duration(seconds: event.duration?.inSeconds ?? 35);
          engine.recordEvent(SimulationEvent(
            elapsed: elapsed,
            type: 'attentionInterrupt',
            label: 'emergency_distraction:${event.id}',
          ));
          _distractionsProcessedThisTick.add(event.id);

        default:
          _distractionsProcessedThisTick.add(event.id);
      }
    }

    // Expire old distractions
    _activeDistractionUntil
        .removeWhere((_, expiryTime) => elapsed >= expiryTime);
  }

  /// Checks if a distraction is currently active that impacts controller performance.
  bool hasActiveDistraction(Duration elapsed) =>
      _activeDistractionUntil.isNotEmpty &&
      _activeDistractionUntil.values.any((expiry) => elapsed < expiry);

  /// Returns penalty multiplier applied to controller efficiency during active distractions.
  /// Values < 1.0 reduce efficiency; values > 1.0 (not used here) would increase it.
  double getDistractionEfficiencyPenalty(Duration elapsed) {
    if (!hasActiveDistraction(elapsed)) return 1.0;

    // Multiple active distractions compound the penalty (non-linearly)
    final activeCount = _activeDistractionUntil.values
        .where((expiry) => elapsed < expiry)
        .length;
    if (activeCount == 0) return 1.0;
    if (activeCount == 1) return 0.8; // 20% efficiency loss
    if (activeCount == 2) return 0.6; // 40% efficiency loss
    return 0.4; // 60% efficiency loss for 3+ distractions
  }

  /// Generates and escalates active alerts based on current snapshot conditions.
  /// Alerts compete for controller attention based on urgency hierarchy.
  void _generateAndEscalateAlerts(SimulationSnapshot snapshot) {
    _alertsEscalatedThisTick.clear();
    final predictedConflictKeys = <String>{};

    // Generate separation loss alerts
    for (final result in snapshot.separation) {
      if (!result.isLossOfSeparation && !result.isPredictedConflict) continue;
      final key = _alertKeyForPair(result.aircraftAId, result.aircraftBId);
      if (result.isPredictedConflict && !result.isLossOfSeparation) {
        predictedConflictKeys.add(key);
      }
      if (_activeAlerts.containsKey(key)) {
        // Update existing alert with escalation
        final existing = _activeAlerts[key]!;
        if (existing.timeToLoss != null &&
            result.timeToConflict != null &&
            result.timeToConflict!.inSeconds < existing.timeToLoss!.inSeconds) {
          final escalationStep =
              _lastPsychologyState.alertTimingFactor < 0.85 ? 2 : 1;
          final newSeverity = (existing.severity + escalationStep).clamp(1, 10);
          _activeAlerts[key] = existing.copyWith(
            severity: newSeverity,
            timeToLoss: result.timeToConflict,
            escalationCount: existing.escalationCount + 1,
          );
          _alertsEscalatedThisTick.add(key);
        }
      } else {
        if (result.isPredictedConflict &&
            !result.isLossOfSeparation &&
            _shouldDelaySubtleConflict(result, snapshot)) {
          continue;
        }

        // Create new alert
        final alertType = result.isLossOfSeparation
            ? AlertType.separationLoss
            : AlertType.separationLoss; // Can refine for predicted vs actual
        _activeAlerts[key] = ControllerAlert(
          id: key,
          type: alertType,
          severity: result.isLossOfSeparation ? 10 : 5,
          createdAt: snapshot.elapsed,
          timeToLoss: result.timeToConflict,
          aircraftIds: [result.aircraftAId, result.aircraftBId],
        );
      }
    }

    _subtleConflictFirstSeenAt
        .removeWhere((key, _) => !predictedConflictKeys.contains(key));
    _subtleConflictDeferred
        .removeWhere((key) => !predictedConflictKeys.contains(key));

    // Generate runway occupancy alerts
    for (final runway in snapshot.runwayStates) {
      if (!runway.isOccupiedAt(snapshot.elapsed)) continue;
      for (final flow in definition.arrivalFlows) {
        if (flow.runwayId != runway.runwayId) continue;
        final threshold = definition.waypoints[flow.thresholdWaypointId];
        if (threshold == null) continue;
        for (final aircraft in snapshot.aircraft) {
          if (!aircraft.active ||
              aircraft.intent.isDeparture ||
              aircraft.intent.assignedRunwayId != runway.runwayId) {
            continue;
          }
          final distance = _distance(
            aircraft.xNm,
            aircraft.yNm,
            threshold.xNm,
            threshold.yNm,
          );
          if (distance >= 10) continue; // Not approaching actively

          final key = 'runway_occupancy:${runway.runwayId}:${aircraft.id}';
          if (!_activeAlerts.containsKey(key)) {
            final ttl = runway.occupiedUntil - snapshot.elapsed;
            _activeAlerts[key] = ControllerAlert(
              id: key,
              type: AlertType.runwayOccupancy,
              severity: 7,
              createdAt: snapshot.elapsed,
              timeToLoss: ttl.inSeconds > 0 ? ttl : Duration.zero,
              aircraftIds: [aircraft.id],
              runwayId: runway.runwayId,
            );
          }
        }
      }
    }

    // Generate departure queue backlog alerts
    if (_queuedDepartures.isNotEmpty) {
      final oldestQueued = _queuedDepartures.values
          .reduce((a, b) => a.spawnAt.compareTo(b.spawnAt) < 0 ? a : b);
      final queueAge = snapshot.elapsed - oldestQueued.spawnAt;
      if (queueAge.inSeconds > 30) {
        const key = 'departure_queue:backlog';
        if (!_activeAlerts.containsKey(key)) {
          _activeAlerts[key] = ControllerAlert(
            id: key,
            type: AlertType.departureQueueBacklog,
            severity: (queueAge.inSeconds ~/ 30).clamp(1, 10),
            createdAt: snapshot.elapsed,
            aircraftIds: _queuedDepartures.keys.toList(),
          );
        } else {
          final existing = _activeAlerts[key]!;
          final newSeverity = (queueAge.inSeconds ~/ 30).clamp(1, 10);
          if (newSeverity > existing.severity) {
            _activeAlerts[key] = existing.copyWith(
              severity: newSeverity,
              escalationCount: existing.escalationCount + 1,
            );
            _alertsEscalatedThisTick.add(key);
          }
        }
      }
    }

    // Remove old/resolved alerts
    _activeAlerts.removeWhere((key, alert) {
      // Remove if no longer predicted/actual conflict
      if (alert.type == AlertType.separationLoss) {
        final pair = key.split(':');
        if (pair.length != 2) return true;
        return !snapshot.separation.any((result) =>
            (result.aircraftAId == pair[0] && result.aircraftBId == pair[1]) ||
            (result.aircraftAId == pair[1] && result.aircraftBId == pair[0]));
      }
      // Keep other alerts for now
      return false;
    });
  }

  bool _shouldDelaySubtleConflict(
    SeparationResult result,
    SimulationSnapshot snapshot,
  ) {
    final ttc = result.timeToConflict?.inSeconds;
    if (ttc == null || ttc <= 0) return false;
    if (ttc <= 35) return false;

    final key = _alertKeyForPair(result.aircraftAId, result.aircraftBId);
    final firstSeen = _subtleConflictFirstSeenAt.putIfAbsent(
      key,
      () => snapshot.elapsed,
    );
    final attentionPoor = _lastAttentionFocusState.scanCoverageQuality < 0.58 ||
        _lastAttentionFocusState.riskLevel.index >=
            AttentionRiskLevel.tunnelVision.index ||
        _lastAttentionResult.remainingAttentionBudget < 0.42;
    if (!attentionPoor) {
      return false;
    }

    if (_subtleConflictDeferred.add(key)) {
      engine.recordEvent(SimulationEvent(
        elapsed: snapshot.elapsed,
        type: 'attentionDelayedRecognition',
        label: 'Subtle conflict cue not recognized for $key',
        aircraftId: result.aircraftAId,
      ));
    }

    final delay = snapshot.elapsed - firstSeen;
    if (delay >= const Duration(seconds: 18)) {
      return false;
    }
    return true;
  }

  void _recordAttentionDisciplineEvents({
    required Duration elapsed,
    required AttentionFocusState previous,
    required AttentionFocusState current,
  }) {
    if (current.scanBlindDuration >= const Duration(seconds: 12) &&
        previous.scanBlindDuration < const Duration(seconds: 12)) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'attentionScanBlind',
        label: 'Scan blind period reached ${current.scanBlindDuration.inSeconds}s',
      ));
    }
    if (current.focusDuration >= const Duration(seconds: 20) &&
        current.competingHighPriorityAlertCount > 0 &&
        previous.focusDuration < const Duration(seconds: 20)) {
      engine.recordEvent(SimulationEvent(
        elapsed: elapsed,
        type: 'attentionFixationWindow',
        label: 'Fixation window opened on ${current.currentFocusTarget ?? 'unknown'}',
      ));
    }
  }

  String _alertKeyForPair(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}:${ids[1]}';
  }
}
