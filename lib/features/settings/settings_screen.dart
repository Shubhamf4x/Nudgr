import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/color_constants.dart';
import '../../shared/providers/theme_provider.dart';
import '../auth/auth_provider.dart';
import 'appearance_screen.dart';
import 'legal_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final themeName = _getThemeName(themeProvider.themeType);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.googleSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Account', [
              _buildListTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit Profile',
                onTap: () => _showEditProfileSheet(),
              ),
              _buildListTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                onTap: () => _showChangePasswordDialog(),
              ),
            ]),
            _buildSection('Appearance', [
              _buildListTile(
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: themeName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                  );
                },
              ),
            ]),
            _buildSection('Privacy', [
              _buildListTile(
                icon: Icons.security_rounded,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: AppTextStyles.googleSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorConstants.primary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? ColorConstants.primary, size: 22),
      title: Text(
        title,
        style: AppTextStyles.googleSans(
          fontSize: 15,
          color: color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTextStyles.googleSans(fontSize: 12, color: Colors.grey),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: color ?? Colors.grey,
        size: 22,
      ),
      onTap: onTap,
    );
  }

  void _showEditProfileSheet() {
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: auth.user?.displayName ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Edit Profile', style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: AppTextStyles.googleSans(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: AppTextStyles.googleSans(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorConstants.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    await auth.updateProfile(displayName: newName);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConstants.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save', style: AppTextStyles.googleSans(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final auth = context.read<AuthProvider>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Password', style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                style: AppTextStyles.googleSans(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: AppTextStyles.googleSans(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ColorConstants.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                style: AppTextStyles.googleSans(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: AppTextStyles.googleSans(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ColorConstants.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                style: AppTextStyles.googleSans(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: AppTextStyles.googleSans(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ColorConstants.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.googleSans(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final current = currentController.text;
              final newPass = newController.text;
              final confirm = confirmController.text;
              if (newPass != confirm) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                }
                return;
              }
              if (newPass.isEmpty || current.isEmpty) return;
              final success = await auth.changePassword(
                currentPassword: current,
                newPassword: newPass,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Password changed successfully' : 'Failed to change password')),
                );
              }
            },
            child: Text('Change', style: AppTextStyles.googleSans(color: ColorConstants.primary)),
          ),
        ],
      ),
    );
  }

  String _getThemeName(AppThemeType type) {
    switch (type) {
      case AppThemeType.light:
        return 'Light';
      case AppThemeType.dark:
        return 'Dark';
      case AppThemeType.midnight:
        return 'Midnight';
      case AppThemeType.neonPurple:
        return 'Neon Purple';
      case AppThemeType.electricBlue:
        return 'Electric Blue';
      case AppThemeType.emerald:
        return 'Emerald';
      case AppThemeType.ocean:
        return 'Ocean';
    }
  }
}
