import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

const _onboardingKey = 'hasSeenOnboarding';

Future<bool> hasSeenOnboarding() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(_onboardingKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_onboardingKey, true);
}

// ── Data ──────────────────────────────────────────────────────────────────────

const _pages = [
  _Page(
    icon: Icons.airplanemode_active,
    title: 'Your job is simple.',
    body: 'Keep aircraft safely separated.',
  ),
  _Page(
    icon: Icons.touch_app_outlined,
    title: 'Control aircraft.',
    body: 'Tap an aircraft on the radar,\nthen give a heading or altitude command.',
  ),
  _Page(
    icon: Icons.warning_amber_outlined,
    title: 'Avoid conflicts.',
    body: 'If aircraft get too close, separation is lost\nand you lose points.',
  ),
  _Page(
    icon: Icons.timer_outlined,
    title: 'Think ahead.',
    body: 'Earlier decisions = safer skies.\nAct before the warning triggers.',
  ),
];

class _Page {
  final IconData icon;
  final String   title;
  final String   body;
  const _Page({required this.icon, required this.title, required this.body});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  /// Called after the user taps "Start Training" or "Skip".
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _current = 0;

  void _next() {
    if (_current < _pages.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await markOnboardingSeen();
    widget.onComplete();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _current == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      // Skip button
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text(
              'Skip',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _PageView(page: _pages[i]),
              ),
            ),

            // Dot indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width:  active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Action button
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isLast ? 'Start Training' : 'Next',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single page ───────────────────────────────────────────────────────────────

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.10),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Icon(page.icon, size: 44, color: AppTheme.primary),
          ),

          const SizedBox(height: 36),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 18),

          // Body
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 17,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
