import 'package:flutter/material.dart';
import '../../shared/models/note_model.dart';
import '../../shared/models/category_model.dart';
import '../../core/services/database_service.dart';
import '../../core/services/sync_service.dart';

class NotesState {
  final List<NoteModel> notes;
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final String searchQuery;
  final bool isLoading;

  const NotesState({
    this.notes = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.isLoading = true,
  });

  NotesState copyWith({
    List<NoteModel>? notes,
    List<CategoryModel>? categories,
    String? selectedCategoryId,
    String? searchQuery,
    bool? isLoading,
  }) => NotesState(
    notes: notes ?? this.notes,
    categories: categories ?? this.categories,
    selectedCategoryId: selectedCategoryId,
    searchQuery: searchQuery ?? this.searchQuery,
    isLoading: isLoading ?? this.isLoading,
  );

  List<NoteModel> get filteredNotes {
    var filtered = List<NoteModel>.from(notes);
    if (selectedCategoryId != null) {
      filtered = filtered.where((n) => n.categoryId == selectedCategoryId).toList();
    }
    filtered = filtered.where((n) => !n.isArchived).toList();
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query) ||
            n.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered;
  }
}

class NotesProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.getInstance();
  final SyncService _sync = SyncService.getInstance();
  NotesState _state = const NotesState();

  NotesState get state => _state;

  bool _loadedOnce = false;

  Future<void> initialize() async {
    if (_loadedOnce) return;
    await loadData();
  }

  Future<void> loadData() async {
    _loadedOnce = true;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final notes = _db.getNotes();
    final categories = _db.getCategories().where((c) => c.type == 'note').toList();

    _state = _state.copyWith(
      notes: notes,
      categories: categories,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<void> addNote(NoteModel note) async {
    await _db.saveNote(note);
    await loadData();
    _sync.saveNoteToFirestore(note);
  }

  Future<void> updateNote(NoteModel note) async {
    await _db.saveNote(note);
    await loadData();
    _sync.saveNoteToFirestore(note);
  }

  Future<void> deleteNote(String noteId) async {
    await _db.deleteNote(noteId);
    await loadData();
    _sync.deleteNoteFromFirestore(noteId);
  }

  Future<void> togglePin(NoteModel note) async {
    final updated = note.copyWith(
      isPinned: !note.isPinned,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _db.saveNote(updated);
    await loadData();
    _sync.saveNoteToFirestore(updated);
  }

  Future<void> addCategory(CategoryModel category) async {
    await _db.saveCategory(category);
    await loadData();
    _sync.saveCategoryToFirestore(category);
  }

  void updateSearch(String query) {
    _state = _state.copyWith(searchQuery: query);
    notifyListeners();
  }

  void selectCategory(String? categoryId) {
    _state = _state.copyWith(selectedCategoryId: categoryId);
    notifyListeners();
  }
}
