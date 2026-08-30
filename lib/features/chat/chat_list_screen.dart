import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/helpers.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/empty_state.dart';
import 'chat_provider.dart';
import 'chat_screen.dart';
import 'create_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chat',
                    style: AppTextStyles.googleSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: _navigateToCreate,
                    icon: const Icon(Icons.edit_square, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  if (provider.state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final conversations = provider.state.conversations;
                  if (conversations.isEmpty) {
                    return EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No conversations yet',
                      subtitle: 'Start a new conversation',
                      actionText: 'New Chat',
                      onAction: _navigateToCreate,
                    );
                  }
                  return ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(conversation: conversation),
                            ),
                          );
                        },
                        leading: AvatarWidget(
                          name: conversation.name ?? 'Chat',
                          size: 52,
                          photoUrl: conversation.photoUrl,
                        ),
                        title: Text(
                          conversation.name ?? 'Direct Chat',
                          style: AppTextStyles.googleSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          conversation.lastMessage ?? 'No messages yet',
                          style: AppTextStyles.googleSans(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (conversation.lastMessageTime != null)
                              Text(
                                Helpers.formatRelativeTime(conversation.lastMessageTime!),
                                style: AppTextStyles.googleSans(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            if (conversation.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorConstants.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${conversation.unreadCount}',
                                  style: AppTextStyles.googleSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateConversationScreen()),
    );
  }
}
