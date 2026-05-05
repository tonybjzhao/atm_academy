import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AboutSafetyScreen extends StatelessWidget {
  const AboutSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('ABOUT & SAFETY')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              icon: Icons.shield_outlined,
              color: AppTheme.warning,
              title: 'Safety Disclaimer',
              content:
                  'This application is designed for general aviation and ATM education only.\n\n'
                  '• It is NOT an operational ATC system.\n'
                  '• It must NOT be used for real-world operational decision-making.\n'
                  '• All simulations are simplified and do not represent real ATM procedures.\n'
                  '• No real aircraft, airspace, or operational data is used.',
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.lock_outline,
              color: AppTheme.primary,
              title: 'Content Compliance',
              content:
                  'ATM Academy uses only publicly available, generic ATM/ATC knowledge.\n\n'
                  '• No proprietary, confidential, or restricted information is included.\n'
                  '• No information from any commercial ATM system vendor is used.\n'
                  '• Content is based on publicly available ICAO, EUROCONTROL, and FAA materials.',
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.info_outline,
              color: AppTheme.secondary,
              title: 'About ATM Academy',
              content:
                  'ATM Academy is an open educational project created by ATM engineers '
                  'for the aviation and ATM learning community.\n\n'
                  'Version: 1.0.0\n'
                  'Platform: iOS & Android\n\n'
                  // TODO: Add organisation name and website when published
                  'For feedback and contributions, visit the project page.',
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.gavel_outlined,
              color: Colors.purpleAccent,
              title: 'No Official Certification',
              content:
                  'This app does not provide, imply, or replace any form of official ATC '
                  'training, licensing, or certification.\n\n'
                  'For official ATC training, consult your national aviation authority or '
                  'an approved ATC training organisation.',
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
