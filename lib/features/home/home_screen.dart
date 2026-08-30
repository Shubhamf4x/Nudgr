import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_text_styles.dart';
import 'home_provider.dart';
import '../auth/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userName = authProvider.user?.displayName ?? 'User';
      context.read<HomeProvider>().loadData(userName);
      _fadeController.forward();
      _slideController.forward();
    });
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('profile_image_path');
    if (savedPath != null && mounted) {
      setState(() => _profileImagePath = savedPath);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Selector<HomeProvider, ({bool isLoading, String userName, int completed30Days, double completionRate, List<double> weeklyActivity, List<double> dailyActivity})>(
          selector: (_, provider) => (
            isLoading: provider.state.isLoading,
            userName: provider.state.userName,
            completed30Days: provider.state.completed30Days,
            completionRate: provider.state.completionRate,
            weeklyActivity: provider.state.weeklyActivity,
            dailyActivity: provider.state.dailyActivity,
          ),
          builder: (context, data, _) {
            final provider = context.read<HomeProvider>();
            if (data.isLoading) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                final authProvider = context.read<AuthProvider>();
                final userName = authProvider.user?.displayName ?? 'User';
                await provider.loadData(userName);
              },
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildProfileAndStats(),
                          const SizedBox(height: 28),
                          _buildActivityGraphSection(),
                          const SizedBox(height: 28),
                          _buildDailyActivitySection(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Welcome!!',
        style: AppTextStyles.googleSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProfileAndStats() {
    final provider = context.read<HomeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSection(provider),
          const SizedBox(width: 24),
          Expanded(child: _buildStatsSection(provider)),
        ],
      ),
    );
  }

  Widget _buildProfileSection(HomeProvider provider) {
    final hasImage = _profileImagePath != null;
    final initial = provider.state.userName.isNotEmpty
        ? provider.state.userName[0].toUpperCase()
        : 'U';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasImage ? null : const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C7CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.transparent,
              backgroundImage: hasImage
                  ? ResizeImage(
                      FileImage(File(_profileImagePath!)),
                      width: 112,
                      height: 112,
                      policy: ResizeImagePolicy.exact,
                    )
                  : null,
              child: hasImage ? null : Text(
                initial,
                style: AppTextStyles.googleSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          provider.state.userName,
          style: AppTextStyles.googleSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Online',
              style: AppTextStyles.googleSans(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection(HomeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Last 30 Days',
          style: AppTextStyles.googleSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        _buildStatItem(
          value: '${provider.state.completed30Days}',
          label: 'Tasks completed',
        ),
        const SizedBox(height: 12),
        _buildStatItem(
          value: '${(provider.state.completionRate * 100).toInt()}%',
          label: 'Completion rate',
        ),
      ],
    );
  }

  Widget _buildStatItem({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            value,
            key: ValueKey(value),
            style: AppTextStyles.googleSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6C63FF),
            ),
          ),
        ),
        Text(
          label,
          style: AppTextStyles.googleSans(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityGraphSection() {
    final provider = context.read<HomeProvider>();
    final weeklyData = provider.state.weeklyActivity;
    final hasActivity = weeklyData.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Graph',
            style: AppTextStyles.googleSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            child: hasActivity
                ? _buildMainGraph(provider)
                : _buildEmptyState('No activity yet', Icons.show_chart_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMainGraph(HomeProvider provider) {
    final data = provider.state.weeklyActivity;
    final maxValue = data.isNotEmpty ? data.reduce(max) : 1.0;
    final displayMax = maxValue > 0 ? maxValue : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 180),
                painter: ActivityGraphPainter(
                  data: data,
                  maxValue: displayMax,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildGraphLabels(data),
        ],
      ),
    );
  }

  Widget _buildGraphLabels(List<double> data) {
    final labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Now'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(labels.length, (index) {
        final val = index < data.length ? data[index] : 0.0;
        return Column(
          children: [
            if (val > 0 && index == data.length - 1) ...[
              Text(
                '${val.toStringAsFixed(1)}h',
                style: AppTextStyles.googleSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              labels[index],
              style: AppTextStyles.googleSans(fontSize: 10, color: Colors.grey),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDailyActivitySection() {
    final provider = context.read<HomeProvider>();
    final dailyData = provider.state.dailyActivity;
    final hasActivity = dailyData.any((v) => v > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Activity',
            style: AppTextStyles.googleSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            child: hasActivity
                ? _buildDailyBars(provider)
                : _buildEmptyState('No activity yet', Icons.wb_sunny_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBars(HomeProvider provider) {
    final data = provider.state.dailyActivity;
    final maxValue = data.isNotEmpty ? data.reduce(max) : 1.0;
    final displayMax = maxValue > 0 ? maxValue : 1.0;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final labels = List.generate(5, (i) {
      final day = DateTime(now.year, now.month, now.day - (4 - i));
      return dayNames[day.weekday - 1];
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (index) {
                final value = index < data.length ? data[index] : 0.0;
                final barHeight = (value / displayMax) * 90;
                return Expanded(
                  child: TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 500 + index * 80),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: barHeight.clamp(4.0, 90.0)),
                    builder: (context, h, _) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Center(
                  child: Text(
                    labels[index],
                    style: AppTextStyles.googleSans(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                message,
                style: AppTextStyles.googleSans(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityGraphPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;

  ActivityGraphPainter({required this.data, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final padT = 20.0, padB = 20.0, padL = 8.0, padR = 8.0;
    final cW = width - padL - padR;
    final cH = height - padT - padB;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = padL + (cW / (data.length - 1)) * i;
      final y = padT + cH - (data[i] / maxValue) * cH;
      points.add(Offset(x, y));
    }

    final fillPath = Path();
    fillPath.moveTo(points.first.dx, height - padB);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp = (points[i].dx + points[i + 1].dx) / 2;
      fillPath.cubicTo(cp, points[i].dy, cp, points[i + 1].dy, points[i + 1].dx, points[i + 1].dy);
    }
    fillPath.lineTo(points.last.dx, height - padB);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.2),
            const Color(0xFF6C63FF).withValues(alpha: 0.01),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp = (points[i].dx + points[i + 1].dx) / 2;
      linePath.cubicTo(cp, points[i].dy, cp, points[i + 1].dy, points[i + 1].dx, points[i + 1].dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF4A90D9), Color(0xFF6C63FF), Color(0xFF9C7CFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, width, height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final lp = points.last;
    canvas.drawCircle(lp, 5, Paint()..color = const Color(0xFF6C63FF));
    canvas.drawCircle(lp, 3, Paint()..color = Colors.white);

    final dashPaint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(lp.dx, lp.dy + 6), Offset(lp.dx, height - padB), dashPaint);
  }

  @override
  bool shouldRepaint(covariant ActivityGraphPainter oldDelegate) {
    if (oldDelegate.maxValue != maxValue) return true;
    if (oldDelegate.data.length != data.length) return true;
    for (int i = 0; i < data.length; i++) {
      if (oldDelegate.data[i] != data[i]) return true;
    }
    return false;
  }
}
