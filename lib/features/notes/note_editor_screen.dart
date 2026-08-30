import '../../core/theme/app_text_styles.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/note_model.dart';
import 'notes_provider.dart';

class _FormattedTextEditingController extends TextEditingController {
  _FormattedTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, required bool withComposing, TextStyle? style}) {
    final text = this.text;
    final spans = <TextSpan>[];
    final tagRegex = RegExp(r'\[/?([a-z]+)\]');
    int lastEnd = 0;
    final stack = <String>[];
    final baseStyle = style ?? const TextStyle();

    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: _applyStack(stack, baseStyle)));
      }
      final close = match.group(1)!.startsWith('/');
      final tag = close ? match.group(1)!.substring(1) : match.group(1)!;
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
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: spans);
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
          style = style.copyWith(fontFamily: 'monospace');
      }
    }
    return style;
  }
}

class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late _FormattedTextEditingController _contentController;
  late FocusNode _contentFocusNode;
  bool _isPinned = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = _FormattedTextEditingController(text: widget.note?.content ?? '');
    _contentFocusNode = FocusNode();
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _toggleFormatting(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final openTag = '[$tag]';
    final closeTag = '[/$tag]';

    List<int>? findEnclosingPair(String s, int rangeStart, int rangeEnd) {
      int openIdx = -1;
      int depth = 0;
      for (int i = rangeStart - 1; i >= 0; i--) {
        if (s.length >= i + closeTag.length && s.substring(i, i + closeTag.length) == closeTag) {
          depth++;
          i -= closeTag.length - 1;
          continue;
        }
        if (s.length >= i + openTag.length && s.substring(i, i + openTag.length) == openTag) {
          if (depth == 0) { openIdx = i; break; }
          depth--;
          i -= openTag.length - 1;
          continue;
        }
      }
      if (openIdx < 0) return null;

      int closeIdx = -1;
      depth = 0;
      for (int i = openIdx + openTag.length; i < s.length; i++) {
        if (s.length >= i + openTag.length && s.substring(i, i + openTag.length) == openTag) {
          depth++;
          i += openTag.length - 1;
          continue;
        }
        if (s.length >= i + closeTag.length && s.substring(i, i + closeTag.length) == closeTag) {
          if (depth == 0) { closeIdx = i; break; }
          depth--;
          i += closeTag.length - 1;
          continue;
        }
      }
      if (closeIdx < 0) return null;
      return [openIdx, closeIdx + closeTag.length];
    }

    if (!selection.isCollapsed) {
      final start = selection.start;
      final end = selection.end;

      final pair = findEnclosingPair(text, end, start);
      if (pair != null) {
        final innerStart = pair[0] + openTag.length;
        final innerEnd = pair[1] - closeTag.length;
        final innerText = text.substring(innerStart, innerEnd);
        final newText = text.substring(0, pair[0]) + innerText + text.substring(pair[1]);
        final newSelStart = start - openTag.length;
        final newSelEnd = end - openTag.length;
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: newSelStart.clamp(0, newText.length),
            extentOffset: newSelEnd.clamp(0, newText.length),
          ),
        );
      } else {
        final selectedText = text.substring(start, end);
        final newText = text.substring(0, start) + openTag + selectedText + closeTag + text.substring(end);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: start + openTag.length,
            extentOffset: start + openTag.length + selectedText.length,
          ),
        );
      }
    } else {
      final cursor = selection.baseOffset;
      final pair = findEnclosingPair(text, cursor, cursor);
      if (pair != null) {
        final innerStart = pair[0] + openTag.length;
        final innerEnd = pair[1] - closeTag.length;
        final innerText = text.substring(innerStart, innerEnd);
        final newText = text.substring(0, pair[0]) + innerText + text.substring(pair[1]);
        final newPos = cursor - openTag.length;
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newPos.clamp(0, newText.length)),
        );
      } else {
        final newText = text.substring(0, cursor) + openTag + closeTag + text.substring(cursor);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor + openTag.length),
        );
      }
    }
    _contentFocusNode.requestFocus();
  }

  void _insertLinePrefix(String prefix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final beforeCursor = text.substring(0, selection.baseOffset);
    final lineStart = beforeCursor.lastIndexOf('\n') + 1;
    final newText = text.substring(0, lineStart) + prefix + text.substring(lineStart);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.baseOffset + prefix.length),
    );
    _contentFocusNode.requestFocus();
  }

  Future<void> _saveNote() async {
    if (_saved) return;
    _saved = true;

    final now = DateTime.now();
    final provider = context.read<NotesProvider>();

    final title = InputValidators.clampLength(
      _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Untitled',
      InputValidators.maxNoteTitleLength,
    );
    final content = InputValidators.clampLength(
      _contentController.text,
      InputValidators.maxNoteContentLength,
    );

    if (widget.note != null) {
      final updated = widget.note!.copyWith(
        title: title,
        content: content,
        isPinned: _isPinned,
        updatedAt: now,
        isSynced: false,
      );
      await provider.updateNote(updated);
    } else {
      if (title == 'Untitled' && content.trim().isEmpty) return;

      await provider.addNote(NoteModel(
        id: const Uuid().v4(),
        title: title,
        content: content,
        isPinned: _isPinned,
        userId: '',
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF232340) : Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3);
    final subtitleColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && !_saved) await _saveNote();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
            onPressed: () async {
              if (!_saved) await _saveNote();
              if (!mounted) return;
              Navigator.pop(this.context);
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.note != null ? 'Edit note' : 'New note',
                style: AppTextStyles.googleSans(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
              ),
              Text(
                'All changes saved',
                style: AppTextStyles.googleSans(fontSize: 11, color: subtitleColor),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.check_rounded, size: 22, color: textColor),
              onPressed: () async {
                if (!_saved) await _saveNote();
                if (!mounted) return;
                Navigator.pop(this.context);
              },
            ),
            IconButton(
              icon: Icon(Icons.push_pin_rounded, size: 20, color: _isPinned ? Theme.of(context).colorScheme.primary : textColor),
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),
            if (widget.note != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: textColor),
                onPressed: () async {
                  if (widget.note == null) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete Note', style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600)),
                      content: Text('Are you sure you want to delete this note?', style: AppTextStyles.googleSans(fontSize: 14)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: AppTextStyles.googleSans(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete', style: AppTextStyles.googleSans(color: ColorConstants.error, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  if (!mounted) return;
                  _saved = true;
                  this.context.read<NotesProvider>().deleteNote(widget.note!.id);
                  Navigator.pop(this.context);
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _titleController,
                  style: AppTextStyles.googleSans(fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: AppTextStyles.googleSans(fontSize: 22, fontWeight: FontWeight.w700, color: hintColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  maxLines: null,
                ),
              ),
              _buildFormatToolbar(cardColor, textColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    style: AppTextStyles.googleSans(fontSize: 15, height: 1.6, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Start typing...',
                      hintStyle: AppTextStyles.googleSans(fontSize: 15, color: hintColor),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      isDense: true,
                    ),
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatToolbar(Color cardColor, Color textColor) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBtn(Icons.format_bold_rounded, 'Bold', 'b', textColor),
            _buildBtn(Icons.format_italic_rounded, 'Italic', 'i', textColor),
            _buildBtn(Icons.format_underline_rounded, 'Underline', 'u', textColor),
            _buildBtn(Icons.strikethrough_s_rounded, 'Strike', 's', textColor),
            _divider(textColor),
            _buildBtn(Icons.format_list_bulleted_rounded, 'Bullet', '- ', textColor),
            _buildBtn(Icons.format_list_numbered_rounded, 'Number', '1. ', textColor),
            _divider(textColor),
            _buildBtn(Icons.code_rounded, 'Code', 'code', textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(IconData icon, String tooltip, String tag, Color color) {
    final isLinePrefix = tag == '- ' || tag == '1. ';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: () => isLinePrefix ? _insertLinePrefix(tag) : _toggleFormatting(tag),
        style: IconButton.styleFrom(
          foregroundColor: color.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(32, 32),
        ),
      ),
    );
  }

  Widget _divider(Color color) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color.withValues(alpha: 0.15),
    );
  }
}
