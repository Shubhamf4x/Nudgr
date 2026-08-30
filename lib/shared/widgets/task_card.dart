import '../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '../../shared/models/task_model.dart';
import '../../core/utils/helpers.dart';
import '../../core/constants/color_constants.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedSubtasks = task.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = task.subtasks.length;

    return Dismissible(
      key: Key(task.id),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ColorConstants.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onDelete != null
            ? () => _showDeleteDialog(context, onDelete!)
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade100,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isCompleted
                          ? ColorConstants.success
                          : Helpers.getPriorityColor(task.priority),
                      width: 2,
                    ),
                    color: task.isCompleted
                        ? ColorConstants.success
                        : Colors.transparent,
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppTextStyles.googleSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: AppTextStyles.googleSans(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Helpers.getPriorityColor(task.priority).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.priority[0].toUpperCase() + task.priority.substring(1),
                            style: AppTextStyles.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Helpers.getPriorityColor(task.priority),
                            ),
                          ),
                        ),
                        if (task.categoryName != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ColorConstants.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.categoryName!,
                              style: AppTextStyles.googleSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ColorConstants.primary,
                              ),
                            ),
                          ),
                        ],
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            Helpers.formatDate(task.dueDate!),
                            style: AppTextStyles.googleSans(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    if (totalSubtasks > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '$completedSubtasks/$totalSubtasks subtasks',
                            style: AppTextStyles.googleSans(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: completedSubtasks / totalSubtasks,
                              backgroundColor: Colors.grey.shade200,
                              color: ColorConstants.success,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Task',
          style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${task.title}"?',
          style: AppTextStyles.googleSans(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.googleSans(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: Text(
              'Delete',
              style: AppTextStyles.googleSans(
                color: ColorConstants.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
