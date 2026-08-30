import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/color_constants.dart';
import '../models/bit_chat_message.dart';
import '../widgets/message_actions_sheet.dart';

class MessageBubble extends StatelessWidget {
  final BitChatMessage message;
  final bool isMine;
  final String? peerNickname;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.peerNickname,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          margin: EdgeInsets.only(
            bottom: 8,
            left: isMine ? 60 : 0,
            right: isMine ? 0 : 60,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    peerNickname ?? message.senderPeerId,
                    style: AppTextStyles.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.primary,
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine
                      ? ColorConstants.primary
                      : isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: AppTextStyles.googleSans(
                        fontSize: 15,
                        color: isMine
                            ? Colors.white
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: AppTextStyles.googleSans(
                            fontSize: 11,
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          _buildDeliveryIcon(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryIcon() {
    IconData icon;
    Color color;

    switch (message.deliveryState) {
      case MessageDeliveryState.pending:
      case MessageDeliveryState.sending:
        icon = Icons.access_time_rounded;
        color = Colors.white.withValues(alpha: 0.6);
        break;
      case MessageDeliveryState.sent:
        icon = Icons.done_rounded;
        color = Colors.white.withValues(alpha: 0.6);
        break;
      case MessageDeliveryState.delivered:
        icon = Icons.done_all_rounded;
        color = Colors.white.withValues(alpha: 0.8);
        break;
      case MessageDeliveryState.queued:
        icon = Icons.schedule_rounded;
        color = Colors.white.withValues(alpha: 0.6);
        break;
      case MessageDeliveryState.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.red.shade300;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => MessageActionsSheet(message: message),
    );
  }
}
