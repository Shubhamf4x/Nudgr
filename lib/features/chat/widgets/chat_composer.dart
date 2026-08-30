import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/color_constants.dart';

class ChatComposer extends StatefulWidget {
  final Function(String) onSend;
  final String hintText;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.hintText = 'Type a message...',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: AppTextStyles.googleSans(fontSize: 15),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTextStyles.googleSans(
                    fontSize: 15,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: _hasText
                  ? ColorConstants.primary
                  : isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _hasText ? _send : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: _hasText
                        ? Colors.white
                        : isDark
                            ? Colors.white38
                            : Colors.black26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
