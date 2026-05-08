class SeparationResult {
  final String aircraftAId;
  final String aircraftBId;
  final double lateralNm;
  final int verticalFt;
  final bool isLossOfSeparation;
  final bool isPredictedConflict;
  final Duration? timeToConflict;
  final double? conflictXNm;
  final double? conflictYNm;

  const SeparationResult({
    required this.aircraftAId,
    required this.aircraftBId,
    required this.lateralNm,
    required this.verticalFt,
    required this.isLossOfSeparation,
    required this.isPredictedConflict,
    this.timeToConflict,
    this.conflictXNm,
    this.conflictYNm,
  });
}
