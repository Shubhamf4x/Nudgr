import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentTheme = themeProvider.themeType;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appearance',
          style: AppTextStyles.googleSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.light,
                  title: 'Light',
                  subtitle: 'White background, dark text',
                  accentColor: const Color(0xFF6C63FF),
                  isSelected: currentTheme == AppThemeType.light,
                  onTap: () => themeProvider.setTheme(AppThemeType.light),
                ),
                _buildDivider(context),
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.dark,
                  title: 'Dark',
                  subtitle: 'Near-black, gray surfaces',
                  accentColor: const Color(0xFF8B85FF),
                  isSelected: currentTheme == AppThemeType.dark,
                  onTap: () => themeProvider.setTheme(AppThemeType.dark),
                ),
                _buildDivider(context),
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.midnight,
                  title: 'Midnight',
                  subtitle: 'Near-black, dark gray surfaces',
                  accentColor: const Color(0xFFBB86FC),
                  isSelected: currentTheme == AppThemeType.midnight,
                  onTap: () => themeProvider.setTheme(AppThemeType.midnight),
                ),
                _buildDivider(context),
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.neonPurple,
                  title: 'Neon Purple',
                  subtitle: 'Dark with glowing purple accents',
                  accentColor: const Color(0xFFCE93D8),
                  isSelected: currentTheme == AppThemeType.neonPurple,
                  onTap: () => themeProvider.setTheme(AppThemeType.neonPurple),
                ),
                _buildDivider(context),
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.electricBlue,
                  title: 'Electric Blue',
                  subtitle: 'Dark navy with bright blue accents',
                  accentColor: const Color(0xFF64B5F6),
                  isSelected: currentTheme == AppThemeType.electricBlue,
                  onTap: () => themeProvider.setTheme(AppThemeType.electricBlue),
                ),
                _buildDivider(context),
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.emerald,
                  title: 'Emerald',
                  subtitle: 'Very dark with green glow accents',
                  accentColor: const Color(0xFF69F0AE),
                  isSelected: currentTheme == AppThemeType.emerald,
                  onTap: () => themeProvider.setTheme(AppThemeType.emerald),
                ),
                _buildDivider(context),
                _buildThemeTile(
                  context: context,
                  theme: AppThemeType.ocean,
                  title: 'Ocean',
                  subtitle: 'Deep blue with cyan/teal accents',
                  accentColor: const Color(0xFF4DD0E1),
                  isSelected: currentTheme == AppThemeType.ocean,
                  onTap: () => themeProvider.setTheme(AppThemeType.ocean),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required AppThemeType theme,
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.googleSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.googleSans(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: accentColor,
                size: 22,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.withValues(alpha: 0.4),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: Theme.of(context).dividerTheme.color,
    );
  }
}
