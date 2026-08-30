import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/nudgr_button.dart';
import '../../shared/widgets/nudgr_text_field.dart';
import 'chat_provider.dart';

class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({super.key});

  @override
  State<CreateConversationScreen> createState() => _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> {
  final _nameController = TextEditingController();
  bool _isGroup = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createConversation() async {
    if (_nameController.text.trim().isEmpty) return;

    final creator = UserModel(
      id: 'current_user',
      email: 'user@nudgr.app',
      displayName: 'You',
      lastSeen: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await context.read<ChatProvider>().createConversation(
          name: _nameController.text.trim(),
          creator: creator,
          isGroup: _isGroup,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Conversation',
          style: AppTextStyles.googleSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NudgrTextField(
              label: 'Conversation Name',
              hint: 'Enter a name',
              controller: _nameController,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                'Group Chat',
                style: AppTextStyles.googleSans(fontSize: 15),
              ),
              subtitle: Text(
                'Create a group conversation',
                style: AppTextStyles.googleSans(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              value: _isGroup,
              onChanged: (value) => setState(() => _isGroup = value),
              contentPadding: EdgeInsets.zero,
            ),
            const Spacer(),
            NudgrButton(
              text: 'Create',
              onPressed: _createConversation,
            ),
          ],
        ),
      ),
    );
  }
}
