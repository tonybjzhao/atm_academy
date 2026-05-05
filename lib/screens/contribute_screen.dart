import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ContributeScreen extends StatelessWidget {
  const ContributeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('CONTRIBUTE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.people_outline, color: Colors.tealAccent, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Built by ATM Engineers',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ATM Academy is an open educational project for the aviation and ATM '
                    'community. If you work in ATM, ATC, or aviation — your knowledge '
                    'can help others learn.',
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'HOW TO CONTRIBUTE',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            const _ContributeOption(
              icon: Icons.add_box_outlined,
              color: AppTheme.secondary,
              title: 'Suggest a Lesson',
              description:
                  'Propose a new topic, lesson outline, or learning objective.',
            ),
            const SizedBox(height: 10),
            const _ContributeOption(
              icon: Icons.edit_note,
              color: AppTheme.warning,
              title: 'Improve a Quiz',
              description:
                  'Suggest better questions, correct inaccuracies, or add explanations.',
            ),
            const SizedBox(height: 10),
            const _ContributeOption(
              icon: Icons.radar,
              color: AppTheme.primary,
              title: 'Add a Simulation Scenario',
              description:
                  'Design a radar scenario, conflict situation, or runway exercise.',
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GET STARTED',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  // TODO: Replace with actual GitHub repo URL once published
                  _LinkRow(
                    icon: Icons.code,
                    label: 'GitHub Repository',
                    value: 'github.com/in5km/atm_academy',
                  ),
                  SizedBox(height: 8),
                  // TODO: Replace with team contact email
                  _LinkRow(
                    icon: Icons.email_outlined,
                    label: 'Contact',
                    value: 'atm.academy@in5km.com',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'All contributions must use publicly available, generic ATM knowledge only.\n'
                'No proprietary, confidential, or restricted information.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ContributeOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _ContributeOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
