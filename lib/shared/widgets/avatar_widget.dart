import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '../../core/constants/color_constants.dart';

class AvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final bool showOnlineStatus;
  final bool isOnline;

  const AvatarWidget({
    super.key,
    this.photoUrl,
    required this.name,
    this.size = 48,
    this.showOnlineStatus = false,
    this.isOnline = false,
  });

  String get _initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color get _backgroundColor {
    final hash = name.hashCode;
    final colors = ColorConstants.categoryColors;
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _backgroundColor,
          ),
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildInitials(),
                  ),
                )
              : _buildInitials(),
        ),
        if (showOnlineStatus)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: isOnline ? ColorConstants.success : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: AppTextStyles.googleSans(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
