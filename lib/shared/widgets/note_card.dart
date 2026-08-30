import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '../../shared/models/note_model.dart';
import '../../core/utils/helpers.dart';
import '../../core/constants/color_constants.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;

  const NoteCard({super.key, required this.note, this.onTap});

  List<TextSpan> _parseContent(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\[(/?)(b|i|u|s|code)\]');
    int lastEnd = 0;
    final stack = <String>[];
    final baseStyle = const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4);

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: _applyStack(stack, baseStyle)));
      }
      final close = match.group(1) == '/';
      final tag = match.group(2)!;
      if (close) {
        if (stack.isNotEmpty && stack.last == tag) stack.removeLast();
      } else {
        stack.add(tag);
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: _applyStack(stack, baseStyle)));
    }
    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  TextStyle _applyStack(List<String> stack, TextStyle base) {
    var style = base;
    for (final tag in stack) {
      switch (tag) {
        case 'b':
          style = style.copyWith(fontWeight: FontWeight.w700);
        case 'i':
          style = style.copyWith(fontStyle: FontStyle.italic);
        case 'u':
          style = style.copyWith(decoration: TextDecoration.underline);
        case 's':
          style = style.copyWith(decoration: TextDecoration.lineThrough);
        case 'code':
          style = style.copyWith(fontFamily: 'monospace', backgroundColor: Colors.white.withValues(alpha: 0.1));
      }
    }
    return style;
  }

  int _countPreviewLines(String text) {
    final regex = RegExp(r'\[/?[a-z]+\]');
    final clean = text.replaceAll(regex, '');
    return clean.split('\n').where((l) => l.trim().isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = note.content.trim().isNotEmpty;
    final previewLines = hasContent ? _countPreviewLines(note.content) : 0;
    final maxLines = previewLines < 2 ? 3 : previewLines < 5 ? 5 : 7;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: AppTextStyles.googleSans(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.push_pin_rounded, size: 14, color: ColorConstants.primary),
                  ),
              ],
            ),
            if (hasContent) ...[
              const SizedBox(height: 8),
              RichText(
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(children: _parseContent(note.content)),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              Helpers.formatRelativeTime(note.updatedAt),
              style: AppTextStyles.googleSans(fontSize: 10, color: Colors.grey.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
