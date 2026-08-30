import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/bit_chat_message.dart';

class MessageActionsSheet extends StatelessWidget {
  final BitChatMessage message;

  const MessageActionsSheet({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildAction(
            context,
            icon: Icons.copy_rounded,
            title: 'Copy',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
          _buildAction(
            context,
            icon: Icons.reply_rounded,
            title: 'Reply',
            onTap: () => Navigator.pop(context),
          ),
          _buildAction(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Delete local copy',
            color: Colors.red,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: AppTextStyles.googleSans(
          fontSize: 15,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
