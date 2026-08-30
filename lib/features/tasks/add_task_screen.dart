import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/task_model.dart';
import 'tasks_provider.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String? _categoryId;
  bool _isRecurring = false;
  String _recurrencePattern = 'daily';
  final List<SubTaskModel> _subtasks = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _dueTime = time);
  }

  void _addSubtask() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Subtask',
            style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Subtask title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _subtasks.add(SubTaskModel(
                    id: const Uuid().v4(),
                    title: controller.text.trim(),
                    createdAt: DateTime.now(),
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  static const List<(String, String)> _categoryLabels = [
    ('work', 'Work'),
    ('study', 'Study'),
    ('personal', 'Personal'),
    ('fitness', 'Fitness'),
  ];

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final task = TaskModel(
      id: const Uuid().v4(),
      title: InputValidators.clampLength(
        _titleController.text.trim(),
        InputValidators.maxTaskTitleLength,
      ),
      description: _descriptionController.text.trim().isNotEmpty
          ? InputValidators.clampLength(
              _descriptionController.text.trim(),
              InputValidators.maxTaskDescriptionLength,
            )
          : null,
      priority: _priority,
      dueDate: _dueDate,
      dueTime: _dueTime != null
          ? DateTime(
              _dueDate?.year ?? now.year,
              _dueDate?.month ?? now.month,
              _dueDate?.day ?? now.day,
              _dueTime!.hour,
              _dueTime!.minute,
            )
          : null,
      categoryId: _categoryId,
      categoryName: _categoryId == null
          ? null
          : _categoryLabels
              .firstWhere((c) => c.$1 == _categoryId,
                  orElse: () => ('', _categoryId!))
              .$2,
      isRecurring: _isRecurring,
      recurrencePattern: _isRecurring ? _recurrencePattern : null,
      subtasks: _subtasks,
      userId: '',
      createdAt: now,
      updatedAt: now,
    );

    context.read<TasksProvider>().addTask(task);
    Navigator.pop(context);
  }

  Color _getPriorityColor(String priority) {
    return Helpers.getPriorityColor(priority);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E2E) : theme.colorScheme.surface;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final hintColor = isDark ? Colors.white38 : theme.colorScheme.onSurface.withValues(alpha: 0.4);
    final labelColor = isDark ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final focusColor = ColorConstants.primary;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(
          'New Task',
          style: AppTextStyles.googleSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              _buildTitleField(textColor, hintColor, cardColor, borderColor, focusColor),
              const SizedBox(height: 16),
              _buildDescriptionField(textColor, hintColor, cardColor, borderColor, focusColor),
              const SizedBox(height: 20),
              _buildPrioritySection(isDark, textColor, labelColor, borderColor, cardColor),
              const SizedBox(height: 16),
              _buildDateRow(isDark, cardColor, borderColor, labelColor),
              const SizedBox(height: 12),
              _buildTimeRow(isDark, cardColor, borderColor, labelColor),
              const SizedBox(height: 12),
              _buildRecurrenceRow(isDark, cardColor, borderColor, labelColor),
              const SizedBox(height: 20),
              _buildCategorySection(isDark, textColor, labelColor, borderColor, cardColor),
              const SizedBox(height: 16),
              _buildSubtasksSection(isDark, labelColor, cardColor),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(
    Color textColor, Color hintColor, Color cardColor, Color borderColor, Color focusColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: AppTextStyles.googleSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          style: AppTextStyles.googleSans(color: textColor),
          decoration: InputDecoration(
            hintText: 'What needs doing?',
            hintStyle: AppTextStyles.googleSans(color: hintColor),
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusColor, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a title';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField(
    Color textColor, Color hintColor, Color cardColor, Color borderColor, Color focusColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (optional)',
          style: AppTextStyles.googleSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          style: AppTextStyles.googleSans(color: textColor),
          decoration: InputDecoration(
            hintText: 'Add details...',
            hintStyle: AppTextStyles.googleSans(color: hintColor),
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySection(
    bool isDark, Color textColor, Color labelColor, Color borderColor, Color cardColor,
  ) {
    final priorities = [
      ('low', 'Low', Icons.arrow_downward_rounded),
      ('medium', 'Medium', Icons.remove_rounded),
      ('high', 'High', Icons.arrow_upward_rounded),
      ('urgent', 'Urgent', Icons.priority_high_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: AppTextStyles.googleSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: priorities.map((p) {
            final isSelected = _priority == p.$1;
            final color = _getPriorityColor(p.$1);
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = p.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : cardColor,
                    border: Border.all(
                      color: isSelected ? color : borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(p.$3, color: color, size: 18),
                      const SizedBox(height: 4),
                      Text(
                        p.$2,
                        style: AppTextStyles.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? color : textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateRow(bool isDark, Color cardColor, Color borderColor, Color labelColor) {
    return _buildOptionRow(
      icon: Icons.calendar_today_rounded,
      label: _dueDate != null ? Helpers.formatDate(_dueDate!) : 'No due date',
      isSet: _dueDate != null,
      cardColor: cardColor,
      borderColor: borderColor,
      labelColor: labelColor,
      onTap: _selectDate,
    );
  }

  Widget _buildTimeRow(bool isDark, Color cardColor, Color borderColor, Color labelColor) {
    return _buildOptionRow(
      icon: Icons.access_time_rounded,
      label: _dueTime != null ? _dueTime!.format(context) : 'Add time of day',
      isSet: _dueTime != null,
      cardColor: cardColor,
      borderColor: borderColor,
      labelColor: labelColor,
      onTap: _selectTime,
    );
  }

  Widget _buildRecurrenceRow(bool isDark, Color cardColor, Color borderColor, Color labelColor) {
    return _buildOptionRow(
      icon: Icons.repeat_rounded,
      label: _isRecurring
          ? 'Every ${_recurrencePattern[0].toUpperCase()}${_recurrencePattern.substring(1)}'
          : 'No recurrence',
      isSet: _isRecurring,
      cardColor: cardColor,
      borderColor: borderColor,
      labelColor: labelColor,
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF2A2A3E) : Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Recurrence',
                    style: AppTextStyles.googleSans(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('None', style: AppTextStyles.googleSans()),
                  onTap: () {
                    setState(() => _isRecurring = false);
                    Navigator.pop(ctx);
                  },
                ),
                ...['daily', 'weekly', 'monthly'].map((pattern) => ListTile(
                      title: Text(pattern[0].toUpperCase() + pattern.substring(1),
                          style: AppTextStyles.googleSans()),
                      onTap: () {
                        setState(() {
                          _isRecurring = true;
                          _recurrencePattern = pattern;
                        });
                        Navigator.pop(ctx);
                      },
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required bool isSet,
    required Color cardColor,
    required Color borderColor,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSet ? ColorConstants.primary : labelColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.googleSans(
                  fontSize: 14,
                  color: isSet ? labelColor : labelColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: labelColor.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    bool isDark, Color textColor, Color labelColor, Color borderColor, Color cardColor,
  ) {
    final categories = [
      ('none', 'None', isDark ? Colors.white24 : Colors.grey),
      ('work', 'Work', ColorConstants.primary),
      ('study', 'Study', ColorConstants.secondary),
      ('personal', 'Personal', ColorConstants.warning),
      ('fitness', 'Fitness', ColorConstants.success),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTextStyles.googleSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _categoryId == cat.$1 || (_categoryId == null && cat.$1 == 'none');
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _categoryId = cat.$1 == 'none' ? null : cat.$1;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cat.$3.withValues(alpha: 0.2)
                        : cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? cat.$3 : borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: cat.$3, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.$2,
                        style: AppTextStyles.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? textColor : textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtasksSection(bool isDark, Color labelColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_subtasks.isNotEmpty) ...[
          ...List.generate(_subtasks.length, (index) {
            final subtask = _subtasks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle_outlined, size: 16, color: labelColor.withValues(alpha: 0.4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subtask.title,
                      style: AppTextStyles.googleSans(fontSize: 13, color: labelColor),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _subtasks.removeAt(index)),
                    child: Icon(Icons.close_rounded, size: 18, color: labelColor.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            );
          }),
        ],
        GestureDetector(
          onTap: _addSubtask,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 20, color: ColorConstants.primary),
                const SizedBox(width: 8),
                Text(
                  'Add subtask',
                  style: AppTextStyles.googleSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ColorConstants.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveTask,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          'Save task',
          style: AppTextStyles.googleSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
