import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class AboutSafetyScreen extends StatelessWidget {
  const AboutSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(l10n.aboutScreenTitle)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              icon: Icons.shield_outlined,
              color: AppTheme.warning,
              title: l10n.aboutSafetyDisclaimerTitle,
              content: l10n.aboutSafetyDisclaimerContent,
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.lock_outline,
              color: AppTheme.primary,
              title: l10n.aboutContentComplianceTitle,
              content: l10n.aboutContentComplianceContent,
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.info_outline,
              color: AppTheme.secondary,
              title: l10n.aboutAppSectionTitle,
              content: l10n.aboutAppSectionContent,
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.gavel_outlined,
              color: Colors.purpleAccent,
              title: l10n.aboutNoCertificationTitle,
              content: l10n.aboutNoCertificationContent,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.65,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
