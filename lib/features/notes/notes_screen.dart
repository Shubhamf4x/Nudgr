import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/note_model.dart';
import '../../shared/widgets/note_card.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/empty_state.dart';
import 'notes_provider.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchController = TextEditingController();
  final GlobalKey _gridKey = GlobalKey();
  final ValueNotifier<bool> _hasSearchText = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hasSearchText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<NotesProvider, ({bool isLoading, List<NoteModel> filteredNotes})>(
      selector: (_, provider) => (
        isLoading: provider.state.isLoading,
        filteredNotes: provider.state.filteredNotes,
      ),
      builder: (context, data, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: AppTextStyles.googleSans(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      _buildCategoryChips(),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildNotesArea(data),
                ),
              ],
            ),
          ),
          // The floating + appears only once notes exist — when the list is
          // empty the centered "Add Note" button in the empty state covers it.
          floatingActionButton:
              (!data.isLoading && data.filteredNotes.isNotEmpty)
                  ? FloatingActionButton(
                      onPressed: () => _navigateToEditor(context),
                      child: const Icon(Icons.add_rounded),
                    )
                  : null,
        );
      },
    );
  }

  Widget _buildNotesArea(({bool isLoading, List<NoteModel> filteredNotes}) data) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final notes = data.filteredNotes;
    if (notes.isEmpty) {
      return EmptyState(
        icon: Icons.note_alt_rounded,
        title: 'No notes yet',
        subtitle: 'Create your first note to get started',
        actionText: 'Add Note',
        onAction: () => _navigateToEditor(context),
      );
    }
    return _MasonryGrid(
      key: _gridKey,
      notes: notes,
      onTap: (note) => _navigateToEditor(context, note: note),
    );
  }

  Widget _buildSearchBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasSearchText,
      builder: (context, hasText, _) {
        return TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search notes...',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _hasSearchText.value = false;
                      context.read<NotesProvider>().updateSearch('');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            _hasSearchText.value = value.isNotEmpty;
            context.read<NotesProvider>().updateSearch(value);
          },
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return Selector<NotesProvider, ({List<dynamic> categories, String? selectedCategoryId})>(
      selector: (_, provider) => (
        categories: provider.state.categories,
        selectedCategoryId: provider.state.selectedCategoryId,
      ),
      builder: (context, data, _) {
        final provider = context.read<NotesProvider>();
        return SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CategoryChip(
                  label: 'All',
                  isSelected: data.selectedCategoryId == null,
                  onTap: () => provider.selectCategory(null),
                ),
              ),
              ...data.categories.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CategoryChip(
                    label: entry.value.name,
                    colorIndex: entry.value.colorIndex,
                    isSelected: data.selectedCategoryId == entry.value.id,
                    onTap: () => provider.selectCategory(entry.value.id),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _navigateToEditor(BuildContext context, {NoteModel? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
  }
}

class _MasonryGrid extends StatelessWidget {
  final List<NoteModel> notes;
  final ValueChanged<NoteModel> onTap;

  const _MasonryGrid({super.key, required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 2;
        const spacing = 10.0;
        const horizontalPadding = 20.0;
        final availableWidth = constraints.maxWidth;
        final gridWidth = (availableWidth - horizontalPadding * 2).clamp(0.0, availableWidth);
        final columnWidth = (gridWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        final columns = List.generate(crossAxisCount, (_) => <_MasonryItem>[]);
        final columnHeights = List.filled(crossAxisCount, 0.0);

        for (final note in notes) {
          final cardHeight = _estimateCardHeight(note, columnWidth);
          final shortestCol = columnHeights.indexOf(columnHeights.reduce((a, b) => a < b ? a : b));
          columns[shortestCol].add(_MasonryItem(note, cardHeight));
          columnHeights[shortestCol] += cardHeight + spacing;
        }

        final maxColHeight = columnHeights.reduce((a, b) => a > b ? a : b);

        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: horizontalPadding, right: horizontalPadding, bottom: 96),
          child: SizedBox(
            width: gridWidth,
            height: maxColHeight,
            child: Stack(
              children: [
                for (int col = 0; col < crossAxisCount; col++)
                  for (int row = 0; row < columns[col].length; row++)
                    Positioned(
                      left: col * (columnWidth + spacing),
                      top: _getTopPosition(columns, col, row, spacing),
                      width: columnWidth,
                      child: NoteCard(
                        note: columns[col][row].note,
                        onTap: () => onTap(columns[col][row].note),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getTopPosition(List<List<_MasonryItem>> columns, int col, int row, double spacing) {
    double top = 0;
    for (int r = 0; r < row; r++) {
      top += columns[col][r].height + spacing;
    }
    return top;
  }

  double _estimateCardHeight(NoteModel note, double width) {
    final titleLen = note.title.length;

    // Must mirror NoteCard's preview logic: maxLines depends on the number
    // of NON-EMPTY content lines (3 / 5 / 7), tags stripped.
    final hasContent = note.content.trim().isNotEmpty;
    int previewLines = 0;
    if (hasContent) {
      final clean = note.content.replaceAll(RegExp(r'\[/?[a-z]+\]'), '');
      previewLines =
          clean.split('\n').where((l) => l.trim().isNotEmpty).length.clamp(1, 7);
    }
    final maxLines = previewLines < 2 ? 3 : previewLines < 5 ? 5 : 7;

    double baseHeight = 14 + 14 + 8;

    // ~7.2px per character at fontSize 14, capped at 2 lines.
    final titleLines = (titleLen / (width / 7.2)).ceil().clamp(1, 2);
    baseHeight += titleLines * 20.0;

    if (hasContent) {
      baseHeight += 8;
      // RichText line height at fontSize 12 with height 1.4 is ~16.8px.
      baseHeight += maxLines * 17.0;
    }

    baseHeight += 8 + 14;
    baseHeight += 14;

    return baseHeight;
  }
}

class _MasonryItem {
  final NoteModel note;
  final double height;
  const _MasonryItem(this.note, this.height);
}
