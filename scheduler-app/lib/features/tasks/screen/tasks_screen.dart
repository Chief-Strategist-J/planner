import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/tasks_bloc.dart';
import '../model/task_model.dart';
import '../state/tasks_state.dart';

class TasksScreen extends StatelessWidget {
  final String projectId;
  final String projectName;

  const TasksScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TasksBloc()..add(FetchTasksEvent(projectId: projectId)),
      child: _TasksView(
        projectId: projectId,
        projectName: projectName,
      ),
    );
  }
}

class _TasksView extends StatelessWidget {
  final String projectId;
  final String projectName;

  const _TasksView({
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          projectName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
            onPressed: () => context.read<TasksBloc>().add(FetchTasksEvent(projectId: projectId)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(context),
          Expanded(
            child: BlocConsumer<TasksBloc, TasksState>(
              listener: (context, state) {
                if (state is TasksErrorState) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is TasksLoadingState) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (state is TasksLoadedState) {
                  if (state.tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.task_alt, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'No tasks found for this project',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Task'),
                            onPressed: () => _showTaskDialog(context),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.tasks.length,
                    itemBuilder: (context, index) {
                      final task = state.tasks[index];
                      return _buildTaskCard(context, task);
                    },
                  );
                }
                return Center(
                  child: ElevatedButton(
                    onPressed: () => context.read<TasksBloc>().add(FetchTasksEvent(projectId: projectId)),
                    child: const Text('Load Tasks'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add_task),
        label: const Text('New Task'),
        onPressed: () => _showTaskDialog(context),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, state) {
        final currentFilter = state is TasksLoadedState ? state.currentFilter : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(context, label: 'All', isSelected: currentFilter == null, filter: null),
                const SizedBox(width: 8),
                _filterChip(context, label: 'Pending', isSelected: currentFilter == TaskStatusEnum.pending, filter: TaskStatusEnum.pending),
                const SizedBox(width: 8),
                _filterChip(context, label: 'In Progress', isSelected: currentFilter == TaskStatusEnum.inProgress, filter: TaskStatusEnum.inProgress),
                const SizedBox(width: 8),
                _filterChip(context, label: 'Completed', isSelected: currentFilter == TaskStatusEnum.completed, filter: TaskStatusEnum.completed),
                const SizedBox(width: 8),
                _filterChip(context, label: 'Cancelled', isSelected: currentFilter == TaskStatusEnum.cancelled, filter: TaskStatusEnum.cancelled),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required TaskStatusEnum? filter,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        context.read<TasksBloc>().add(FetchTasksEvent(
          projectId: projectId,
          statusFilter: filter,
        ));
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task) {
    Color priorityColor;
    switch (task.priority) {
      case TaskPriorityEnum.low:
        priorityColor = AppColors.priorityLow;
        break;
      case TaskPriorityEnum.medium:
        priorityColor = AppColors.priorityMedium;
        break;
      case TaskPriorityEnum.high:
        priorityColor = AppColors.priorityHigh;
        break;
      case TaskPriorityEnum.critical:
        priorityColor = AppColors.priorityCritical;
        break;
    }

    Color statusColor;
    switch (task.status) {
      case TaskStatusEnum.pending:
        statusColor = AppColors.statusPending;
        break;
      case TaskStatusEnum.inProgress:
        statusColor = AppColors.statusInProgress;
        break;
      case TaskStatusEnum.completed:
        statusColor = AppColors.statusCompleted;
        break;
      case TaskStatusEnum.cancelled:
        statusColor = AppColors.statusCancelled;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: task.status == TaskStatusEnum.completed
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      decoration: task.status == TaskStatusEnum.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                PopupMenuButton<TaskStatusEnum>(
                  icon: Icon(Icons.more_vert, color: statusColor),
                  onSelected: (newStatus) {
                    context.read<TasksBloc>().add(UpdateTaskStatusEvent(
                      projectId: projectId,
                      taskId: task.taskId,
                      newStatus: newStatus,
                    ));
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: TaskStatusEnum.pending, child: Text('Mark as PENDING')),
                    const PopupMenuItem(value: TaskStatusEnum.inProgress, child: Text('Mark as IN_PROGRESS')),
                    const PopupMenuItem(value: TaskStatusEnum.completed, child: Text('Mark as COMPLETED')),
                    const PopupMenuItem(value: TaskStatusEnum.cancelled, child: Text('Mark as CANCELLED')),
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      task.assignedToEmail.isNotEmpty ? task.assignedToEmail : 'Unassigned',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      task.dueDate.isNotEmpty ? task.dueDate : 'No due date',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () => _confirmDeleteTask(context, task.taskId),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDialog(BuildContext context, {TaskModel? existing}) {
    final idController = TextEditingController(text: existing?.taskId ?? 'task-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final emailController = TextEditingController(text: existing?.assignedToEmail ?? 'jaydeep.v@blute.co.in');
    final dueDateController = TextEditingController(text: existing?.dueDate ?? '2026-10-01');
    TaskPriorityEnum selectedPriority = existing?.priority ?? TaskPriorityEnum.high;
    TaskStatusEnum selectedStatus = existing?.status ?? TaskStatusEnum.pending;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Add Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(labelText: 'Task ID'),
                  ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Assignee Email'),
                ),
                TextField(
                  controller: dueDateController,
                  decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final id = existing?.taskId ?? idController.text.trim();
                final title = titleController.text.trim();
                if (id.isEmpty || title.isEmpty) return;

                final task = TaskModel(
                  taskId: id,
                  projectId: projectId,
                  title: title,
                  description: descController.text.trim(),
                  status: selectedStatus,
                  priority: selectedPriority,
                  assignedToEmail: emailController.text.trim(),
                  dueDate: dueDateController.text.trim(),
                );

                context.read<TasksBloc>().add(UpsertTaskEvent(task));
                Navigator.pop(dialogCtx);
              },
              child: const Text('Save', style: TextStyle(color: AppColors.textOnPrimary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTask(BuildContext context, String taskId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete task "$taskId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<TasksBloc>().add(DeleteTaskEvent(
                projectId: projectId,
                taskId: taskId,
              ));
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.textOnPrimary)),
          ),
        ],
      ),
    );
  }
}
