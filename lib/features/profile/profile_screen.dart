import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/color_constants.dart';
import '../../core/services/update_service.dart';
import '../../shared/providers/sync_provider.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _localImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSavedImage();
  }

  Future<void> _loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('profile_image_path');
    if (savedPath != null && mounted) {
      setState(() => _localImagePath = savedPath);
    }
  }

  Future<void> _saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', path);
  }

  Future<void> _removeSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path');
    _localImagePath = null;
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Photo',
                style: AppTextStyles.googleSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: ColorConstants.primary),
                title: Text('Camera', style: AppTextStyles.googleSans(fontSize: 16)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: ColorConstants.primary),
                title: Text('Gallery', style: AppTextStyles.googleSans(fontSize: 16)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (_localImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: ColorConstants.error),
                  title: Text(
                    'Remove Photo',
                    style: AppTextStyles.googleSans(
                      fontSize: 16,
                      color: ColorConstants.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeSavedImage();
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;

    // Crop step: the user selects the exact square/circular area to keep.
    final cropped = await _cropImage(picked.path);
    if (cropped == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Photo',
          style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: ClipOval(
          child: Image.file(
            File(cropped),
            width: 150,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.googleSans(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use Photo', style: AppTextStyles.googleSans(color: ColorConstants.primary)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _localImagePath = cropped);
      await _saveImagePath(cropped);
    }
  }

  Future<String?> _cropImage(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: ColorConstants.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: ColorConstants.primary,
            initAspectRatio: CropAspectRatioPreset.original,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      return cropped?.path;
    } catch (_) {
      // If the cropper fails to open, fall back to the uncropped image.
      return sourcePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Selector<AuthProvider, dynamic>(
          selector: (_, auth) => auth.user,
          builder: (context, user, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildAvatar(user),
                  const SizedBox(height: 20),
                  _buildUserInfo(user),
                  const SizedBox(height: 20),
                  _buildSyncStatus(context),
                  const SizedBox(height: 28),
                  _buildMenuItems(context),
                  const SizedBox(height: 16),
                  _buildSignOutButton(context, context.read<AuthProvider>()),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(dynamic user) {
    final hasImage = _localImagePath != null;
    final initial = (user?.displayName ?? 'U')[0].toUpperCase();

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                ColorConstants.primary,
                ColorConstants.primary.withValues(alpha:0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: Colors.grey.shade800,
            // Decode the picked image at display resolution to save memory.
            backgroundImage: hasImage
                ? ResizeImage(
                    FileImage(File(_localImagePath!)),
                    width: 220,
                    height: 220,
                    policy: ResizeImagePolicy.exact,
                  )
                : null,
            child: hasImage
                ? null
                : Text(
                    initial,
                    style: AppTextStyles.googleSans(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 3,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                color: ColorConstants.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo(dynamic user) {
    final username = user?.username ??
        user?.displayName?.toLowerCase().replaceAll(' ', '') ??
        'user';

    return Column(
      children: [
        Text(
          user?.displayName ?? 'User',
          style: AppTextStyles.googleSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@$username',
          style: AppTextStyles.googleSans(
            fontSize: 15,
            color: ColorConstants.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncStatus(BuildContext context) {
    return Selector<SyncProvider, ({bool isOnline, bool isSyncing, bool cloudEnabled, String statusLabel, String lastSyncLabel, int pendingCount})>(
      selector: (_, sync) => (
        isOnline: sync.isOnline,
        isSyncing: sync.isSyncing,
        cloudEnabled: sync.cloudEnabled,
        statusLabel: sync.statusLabel,
        lastSyncLabel: sync.lastSyncLabel,
        pendingCount: sync.pendingCount,
      ),
      builder: (context, data, _) {
        final sync = context.read<SyncProvider>();
        final cloudEnabled = data.cloudEnabled;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    !cloudEnabled
                        ? Icons.phone_android_rounded
                        : data.isOnline
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                    color: !cloudEnabled
                        ? ColorConstants.primary
                        : data.isOnline
                            ? const Color(0xFF4CAF50)
                            : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cloudEnabled ? 'Cloud Sync' : 'Local Storage',
                      style: AppTextStyles.googleSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (cloudEnabled && data.isSyncing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (cloudEnabled)
                    IconButton(
                      icon: Icon(
                        Icons.sync_rounded,
                        color: ColorConstants.primary,
                        size: 22,
                      ),
                      onPressed: data.isOnline ? () => sync.syncNow() : null,
                      tooltip: 'Sync now',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: AppTextStyles.googleSans(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    data.statusLabel,
                    style: AppTextStyles.googleSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: !cloudEnabled
                          ? ColorConstants.primary
                          : data.isOnline
                              ? const Color(0xFF4CAF50)
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (cloudEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Last sync: ',
                      style: AppTextStyles.googleSans(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      data.lastSyncLabel,
                      style: AppTextStyles.googleSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (data.pendingCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Pending: ',
                        style: AppTextStyles.googleSans(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${data.pendingCount} change${data.pendingCount == 1 ? '' : 's'}',
                        style: AppTextStyles.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  'Sign in with Google to sync your data across devices.',
                  style: AppTextStyles.googleSans(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final items = [
      _MenuItem(
        icon: Icons.settings_rounded,
        title: 'Settings',
        color: const Color(0xFF2196F3),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.download_rounded,
        title: 'Check for updates',
        color: const Color(0xFF009688),
        onTap: () => _checkForUpdates(),
      ),
      _MenuItem(
        icon: Icons.help_outline_rounded,
        title: 'About Nudgr',
        color: const Color(0xFF2196F3),
        onTap: () {},
      ),
    ];

    return Column(
      children: items.map((item) => _buildMenuItemCard(context, item)).toList(),
    );
  }

  Widget _buildMenuItemCard(BuildContext context, _MenuItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha:0.15),
                    shape: BoxShape.circle,
                  ),
                  child: item.onTap == _checkForUpdates && _isCheckingUpdates
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTextStyles.googleSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.withValues(alpha:0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isCheckingUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);

    final result = await UpdateService.checkForUpdate();

    if (!mounted) return;
    setState(() => _isCheckingUpdates = false);

    if (result is UpdateAvailable) {
      _showUpdateDialog(result);
    } else if (result is UpdateUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are on the latest version (v${result.currentVersion}).',
            style: AppTextStyles.googleSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result is UpdateCheckError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message,
            style: AppTextStyles.googleSans(color: Colors.white),
          ),
          backgroundColor: ColorConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUpdateDialog(UpdateAvailable update) {
    final notes = update.releaseNotes.trim().isEmpty
        ? null
        : update.releaseNotes.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColorConstants.primary.withValues(alpha:0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: ColorConstants.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Update available',
                style: AppTextStyles.googleSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of Nudgr is available.',
              style: AppTextStyles.googleSans(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'v${update.currentVersion}  →  v${update.latestVersion}',
              style: AppTextStyles.googleSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ColorConstants.primary,
              ),
            ),
            if (notes != null) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: AppTextStyles.googleSans(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: AppTextStyles.googleSans(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _launchDownload(update.downloadUrl);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              'Download',
              style: AppTextStyles.googleSans(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConstants.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open the download page.',
              style: AppTextStyles.googleSans(color: Colors.white),
            ),
            backgroundColor: ColorConstants.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the download page.',
            style: AppTextStyles.googleSans(color: Colors.white),
          ),
          backgroundColor: ColorConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSignOutButton(BuildContext context, AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Sign Out',
                style: AppTextStyles.googleSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                'Are you sure you want to sign out?',
                style: AppTextStyles.googleSans(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.googleSans(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Sign Out',
                    style: AppTextStyles.googleSans(color: ColorConstants.error),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await auth.logout();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: ColorConstants.error, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Sign Out',
          style: AppTextStyles.googleSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColorConstants.error,
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}
