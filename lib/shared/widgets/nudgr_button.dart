import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '../../core/constants/color_constants.dart';

class NudgrButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final double? width;
  final double? height;

  const NudgrButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Colors.transparent : ColorConstants.primary,
          foregroundColor: isSecondary ? ColorConstants.primary : Colors.white,
          side: isSecondary
              ? BorderSide(color: ColorConstants.primary, width: 1.5)
              : null,
          disabledBackgroundColor:
              isSecondary ? Colors.transparent : ColorConstants.primary.withValues(alpha: 0.6),
          disabledForegroundColor:
              isSecondary ? ColorConstants.primary.withValues(alpha: 0.6) : Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isSecondary ? ColorConstants.primary : Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: AppTextStyles.googleSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
