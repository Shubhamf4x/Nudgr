import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/color_constants.dart';

class Helpers {
  Helpers._();

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = dateOnly.difference(today).inDays;

    if (dateOnly == today) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (date.year == now.year) {
      return DateFormat('EEEE, MMM d').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  static String formatTimer(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return ColorConstants.priorityLow;
      case 'medium':
        return ColorConstants.priorityMedium;
      case 'high':
        return ColorConstants.priorityHigh;
      case 'urgent':
        return ColorConstants.priorityUrgent;
      default:
        return ColorConstants.priorityMedium;
    }
  }

  static IconData getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Icons.arrow_downward_rounded;
      case 'medium':
        return Icons.remove_rounded;
      case 'high':
        return Icons.arrow_upward_rounded;
      case 'urgent':
        return Icons.priority_high_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  static Color getCategoryColor(int index) {
    return ColorConstants.categoryColors[index % ColorConstants.categoryColors.length];
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ColorConstants.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String getMotivationalMessage() {
    final messages = [
      'Stay focused, stay productive.',
      'Small steps lead to big results.',
      'One task at a time, one step at a time.',
      'Progress, not perfection.',
      'Your future self will thank you.',
      'Done is better than perfect.',
      'Focus on being productive instead of busy.',
      'The secret of getting ahead is getting started.',
      'Turn your wounds into wisdom.',
      'You don\'t have to be great to start, but you have to start to be great.',
    ];
    final index = DateTime.now().millisecondsSinceEpoch % messages.length;
    return messages[index];
  }
}
