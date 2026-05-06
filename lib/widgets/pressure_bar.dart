import 'package:flutter/material.dart';
import '../core/models/scenario_result.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class PressureBar extends StatelessWidget {
  final AlertLevel level;
  final double minHorizDist;

  const PressureBar({super.key, required this.level, required this.minHorizDist});

  Color get _color {
    switch (level) {
      case AlertLevel.normal:   return AppTheme.primary;
      case AlertLevel.advisory: return Colors.yellowAccent;
      case AlertLevel.warning:  return AppTheme.warning;
      case AlertLevel.los:      return AppTheme.danger;
    }
  }

  String _label(AppLocalizations l10n) {
    switch (level) {
      case AlertLevel.normal:   return l10n.alertNormal;
      case AlertLevel.advisory: return l10n.alertAdvisory;
      case AlertLevel.warning:  return l10n.alertWarning;
      case AlertLevel.los:      return l10n.alertLOS;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            level == AlertLevel.los
                ? Icons.warning_rounded
                : level == AlertLevel.warning
                    ? Icons.warning_amber_rounded
                    : level == AlertLevel.advisory
                        ? Icons.info_outlined
                        : Icons.check_circle_outline,
            color: _color,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _label(l10n),
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Text(
            '${minHorizDist.toStringAsFixed(0)} px',
            style: TextStyle(color: _color.withValues(alpha: 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
