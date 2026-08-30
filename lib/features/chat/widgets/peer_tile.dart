import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/color_constants.dart';
import '../models/bit_chat_peer.dart';

class PeerTile extends StatelessWidget {
  final BitChatPeer peer;
  final VoidCallback onTap;
  final VoidCallback onPrivateMessage;

  const PeerTile({
    super.key,
    required this.peer,
    required this.onTap,
    required this.onPrivateMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ColorConstants.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (peer.nickname ?? peer.peerId).substring(0, 1).toUpperCase(),
                      style: AppTextStyles.googleSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer.nickname ?? 'Unknown',
                        style: AppTextStyles.googleSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        peer.displayId,
                        style: AppTextStyles.googleSans(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: peer.isActive ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (peer.isActive ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
