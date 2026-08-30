import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/task_model.dart';
import '../../shared/widgets/task_card.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/empty_state.dart';
import 'tasks_provider.dart';
import 'add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final ValueNotifier<bool> _hasSearchText = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TasksProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _hasSearchText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<TasksProvider, ({bool isLoading, List<dynamic> filteredTasks})>(
      selector: (_, provider) => (
        isLoading: provider.state.isLoading,
        filteredTasks: provider.state.filteredTasks,
      ),
      builder: (context, data, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tasks',
                        style: AppTextStyles.googleSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      _buildCategoryChips(),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildTaskList(data),
                ),
              ],
            ),
          ),
          // The floating + appears only once tasks exist â€” when the list is
          // empty the centered "Add Task" button in the empty state covers it.
          floatingActionButton:
              (!data.isLoading && data.filteredTasks.isNotEmpty)
                  ? FloatingActionButton(
                      onPressed: () => _navigateToAddTask(context),
                      child: const Icon(Icons.add_rounded),
                    )
                  : null,
        );
      },
    );
  }

  Widget _buildTaskList(({bool isLoading, List<dynamic> filteredTasks}) data) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tasks = data.filteredTasks;
    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No tasks yet',
        subtitle: 'Tap the button below to create your first task',
        actionText: 'Add Task',
        onAction: () => _navigateToAddTask(context),
      );
    }
    final provider = context.read<TasksProvider>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index] as TaskModel;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TaskCard(
            task: task,
            onToggle: () => provider.toggleTask(task),
            onDelete: () => provider.deleteTask(task.id),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasSearchText,
      builder: (context, hasText, _) {
        return TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search tasks...',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _hasSearchText.value = false;
                      context.read<TasksProvider>().updateFilter(searchQuery: '');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            _hasSearchText.value = value.isNotEmpty;
            context.read<TasksProvider>().updateFilter(searchQuery: value);
          },
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return Selector<TasksProvider, ({List<dynamic> categories, String? selectedCategoryId})>(
      selector: (_, provider) => (
        categories: provider.state.categories,
        selectedCategoryId: provider.state.selectedCategoryId,
      ),
      builder: (context, data, _) {
        final provider = context.read<TasksProvider>();
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
                  monochrome: true,
                  onTap: () => provider.updateFilter(categoryId: null),
                ),
              ),
              ...data.categories.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CategoryChip(
                    label: entry.value.name,
                    colorIndex: entry.value.colorIndex,
                    isSelected: data.selectedCategoryId == entry.value.id,
                    monochrome: true,
                    onTap: () => provider.updateFilter(categoryId: entry.value.id),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _navigateToAddTask(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }
}
