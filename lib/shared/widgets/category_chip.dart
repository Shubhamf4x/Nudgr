import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '../../core/constants/color_constants.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final int colorIndex;

  final bool monochrome;

  const CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.colorIndex = 0,
    this.monochrome = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ColorConstants
        .categoryColors[colorIndex % ColorConstants.categoryColors.length];
    final neutralText = isDark ? Colors.white70 : Colors.black54;
    final neutralBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final neutralBorder = isDark ? Colors.white24 : Colors.black26;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: monochrome
              ? (isSelected ? neutralBg : Colors.transparent)
              : (isSelected ? accent : accent.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: monochrome
                ? (isSelected ? neutralBorder : neutralBorder.withValues(alpha: 0.6))
                : (isSelected ? accent : accent.withValues(alpha: 0.3)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.googleSans(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: monochrome
                ? (isSelected ? Theme.of(context).textTheme.bodyLarge?.color : neutralText)
                : (isSelected ? Colors.white : accent),
          ),
        ),
      ),
    );
  }
}
