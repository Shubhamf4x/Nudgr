import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/color_constants.dart';
import '../../core/services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 4;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.check_circle_outline_rounded,
      iconColor: Color(0xFFF59E0B),
      iconBgColor: Color(0xFF2D2A1E),
      title: 'Plan your day',
      description: 'Capture tasks, set priorities and due dates, and let reminders keep you on track.',
    ),
    _OnboardingPage(
      icon: Icons.timer_outlined,
      iconColor: Color(0xFF10B981),
      iconBgColor: Color(0xFF1A2E2A),
      title: 'Focus deeply',
      description: 'Pomodoro sessions with ambient soundscapes \u2014 brown noise, rain, waves and more.',
    ),
    _OnboardingPage(
      icon: Icons.directions_walk_rounded,
      iconColor: Color(0xFF8B5CF6),
      iconBgColor: Color(0xFF231F35),
      title: 'Track your steps',
      description: 'Count your daily steps automatically with your phone\'s built-in sensor.',
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: Color(0xFF3B82F6),
      iconBgColor: Color(0xFF1A2236),
      title: 'Stay connected',
      description: 'Chat with teammates in groups or one-on-one, even without a signal.',
    ),
  ];

  void _onNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onSkip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (!mounted) return;

    // Request notification permission at the proper moment — after the
    // user has finished onboarding, not during login.
    await NotificationService.requestPermissionOnce(context);

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _onSkip,
                child: Text(
                  'Skip',
                  style: AppTextStyles.googleSans(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: page.iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              page.icon,
                              size: 64,
                              color: page.iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: AppTextStyles.googleSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.description,
                          style: AppTextStyles.googleSans(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == index ? 28 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? ColorConstants.primary
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConstants.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_currentPage == _totalPages - 1) ...[
                            const Icon(Icons.rocket_launch_rounded, size: 18),
                            const SizedBox(width: 8),
                          ] else ...[
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _currentPage == _totalPages - 1
                                ? 'Get started'
                                : 'Next',
                            style: AppTextStyles.googleSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
  });
}
