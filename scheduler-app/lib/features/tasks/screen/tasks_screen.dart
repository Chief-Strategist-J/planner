import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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

class _TasksView extends StatefulWidget {
  final String projectId;
  final String projectName;

  const _TasksView({
    required this.projectId,
    required this.projectName,
  });

  @override
  State<_TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<_TasksView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textOnPrimary),
            ),
            Row(
              children: [
                const Icon(Icons.folder_outlined, size: 12, color: AppColors.border),
                const SizedBox(width: 4),
                Text(
                  'Project ID: ${widget.projectId}',
                  style: const TextStyle(fontSize: 11, color: AppColors.border, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Tasks',
            icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
            onPressed: () => context.read<TasksBloc>().add(FetchTasksEvent(projectId: widget.projectId)),
          ),
        ],
      ),
      body: BlocConsumer<TasksBloc, TasksState>(
        listener: (context, state) {
          if (state is TasksErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.textOnPrimary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage)),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TasksLoadingState) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Fetching tasks from Cloud Storage...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          if (state is TasksLoadedState) {
            final allTasks = state.tasks;
            final currentFilter = state.currentFilter;

            final filteredTasks = allTasks.where((t) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return t.title.toLowerCase().contains(q) ||
                  t.description.toLowerCase().contains(q) ||
                  t.taskId.toLowerCase().contains(q) ||
                  t.assignedToEmail.toLowerCase().contains(q);
            }).toList();

            return Column(
              children: [
                _buildSearchAndFilterHeader(context, allTasks, currentFilter),
                Expanded(
                  child: allTasks.isEmpty
                      ? _buildEmptyState(context)
                      : filteredTasks.isEmpty
                          ? _buildNoSearchResultsState()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () async {
                                context.read<TasksBloc>().add(FetchTasksEvent(
                                      projectId: widget.projectId,
                                      statusFilter: currentFilter,
                                    ));
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: filteredTasks.length,
                                itemBuilder: (context, index) {
                                  final task = filteredTasks[index];
                                  return _buildTaskCard(context, task);
                                },
                              ),
                            ),
                ),
              ],
            );
          }

          return Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Load Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => context.read<TasksBloc>().add(FetchTasksEvent(projectId: widget.projectId)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 3,
        icon: const Icon(Icons.add_task),
        label: const Text('New Task', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showTaskDialog(context),
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(
    BuildContext context,
    List<TaskModel> tasks,
    TaskStatusEnum? currentFilter,
  ) {
    final pendingCount = tasks.where((t) => t.status == TaskStatusEnum.pending).length;
    final inProgressCount = tasks.where((t) => t.status == TaskStatusEnum.inProgress).length;
    final completedCount = tasks.where((t) => t.status == TaskStatusEnum.completed).length;
    final cancelledCount = tasks.where((t) => t.status == TaskStatusEnum.cancelled).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search tasks by title, description, assignee...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  context,
                  label: 'All (${tasks.length})',
                  isSelected: currentFilter == null,
                  filter: null,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  context,
                  label: 'Pending ($pendingCount)',
                  isSelected: currentFilter == TaskStatusEnum.pending,
                  filter: TaskStatusEnum.pending,
                  dotColor: AppColors.statusPending,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  context,
                  label: 'In Progress ($inProgressCount)',
                  isSelected: currentFilter == TaskStatusEnum.inProgress,
                  filter: TaskStatusEnum.inProgress,
                  dotColor: AppColors.statusInProgress,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  context,
                  label: 'Completed ($completedCount)',
                  isSelected: currentFilter == TaskStatusEnum.completed,
                  filter: TaskStatusEnum.completed,
                  dotColor: AppColors.statusCompleted,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  context,
                  label: 'Cancelled ($cancelledCount)',
                  isSelected: currentFilter == TaskStatusEnum.cancelled,
                  filter: TaskStatusEnum.cancelled,
                  dotColor: AppColors.statusCancelled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required TaskStatusEnum? filter,
    Color? dotColor,
  }) {
    return FilterChip(
      avatar: dotColor != null
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            )
          : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        context.read<TasksBloc>().add(FetchTasksEvent(
              projectId: widget.projectId,
              statusFilter: filter,
            ));
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined, size: 54, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),
            Text(
              'No Tasks in ${widget.projectName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add tasks with due dates and assignees. The cloud scheduler will automatically monitor pending items and dispatch morning email reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_task),
              label: const Text('Add First Task', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showTaskDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No Matching Tasks',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try changing your search terms or status filter tab.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search Query'),
              onPressed: () => setState(() => _searchQuery = ''),
            ),
          ],
        ),
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

    final isCompleted = task.status == TaskStatusEnum.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick checkbox for completing task
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: isCompleted,
                    activeColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      final nextStatus = (val == true) ? TaskStatusEnum.completed : TaskStatusEnum.pending;
                      context.read<TasksBloc>().add(UpdateTaskStatusEvent(
                            projectId: widget.projectId,
                            taskId: task.taskId,
                            newStatus: nextStatus,
                          ));
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: priorityColor),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.priority.value,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: priorityColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              task.taskId,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<TaskStatusEnum>(
                  tooltip: 'Change Status',
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.status.value,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                  onSelected: (newStatus) {
                    context.read<TasksBloc>().add(UpdateTaskStatusEvent(
                          projectId: widget.projectId,
                          taskId: task.taskId,
                          newStatus: newStatus,
                        ));
                  },
                  itemBuilder: (_) => TaskStatusEnum.values.map((s) {
                    Color dotColor;
                    switch (s) {
                      case TaskStatusEnum.pending:
                        dotColor = AppColors.statusPending;
                        break;
                      case TaskStatusEnum.inProgress:
                        dotColor = AppColors.statusInProgress;
                        break;
                      case TaskStatusEnum.completed:
                        dotColor = AppColors.statusCompleted;
                        break;
                      case TaskStatusEnum.cancelled:
                        dotColor = AppColors.statusCancelled;
                        break;
                    }
                    final isCurrent = task.status == s;
                    return PopupMenuItem<TaskStatusEnum>(
                      value: s,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.value,
                              style: TextStyle(
                                color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isCurrent) const Icon(Icons.check, size: 16, color: AppColors.primary),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text(
                  task.description,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                ),
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
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      task.assignedToEmail.isNotEmpty ? task.assignedToEmail : 'Unassigned',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      task.dueDate.isNotEmpty ? task.dueDate : 'No due date',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Edit Task',
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryLight),
                      onPressed: () => _showTaskDialog(context, existing: task),
                    ),
                    IconButton(
                      tooltip: 'Delete Task',
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () => _confirmDeleteTask(context, task.taskId, task.title),
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
    final tasksBloc = context.read<TasksBloc>();
    final formKey = GlobalKey<FormState>();
    bool userCustomizedId = existing != null;

    final idController = TextEditingController(
      text: existing?.taskId ?? 'task-${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final emailController = TextEditingController(text: existing?.assignedToEmail ?? 'jaydeep.v@blute.co.in');

    final defaultDue = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7)));
    final dueDateController = TextEditingController(text: existing?.dueDate ?? defaultDue);

    TaskPriorityEnum selectedPriority = existing?.priority ?? TaskPriorityEnum.high;
    TaskStatusEnum selectedStatus = existing?.status ?? TaskStatusEnum.pending;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: tasksBloc,
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.90,
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                existing == null ? Icons.add_task_rounded : Icons.edit_note_rounded,
                                color: AppColors.primaryLight,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    existing == null ? 'Create New Task' : 'Edit Task Details',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    existing == null ? 'Task will be saved into cloud project' : 'Update task parameters',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textMuted),
                              onPressed: () => Navigator.pop(sheetCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // PRESELECTED TARGET PROJECT BANNER (Explicitly shows current project is selected by default!)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_rounded, size: 20, color: AppColors.primaryLight),
                              const SizedBox(width: 8),
                              const Text(
                                'Target Project:',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${widget.projectName} (${widget.projectId})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Selected by Default',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 16),

                        // Task Title
                        TextFormField(
                          controller: titleController,
                          autofocus: existing == null,
                          decoration: const InputDecoration(
                            labelText: 'Task Title *',
                            hintText: 'e.g. Deploy Cloud Run revision with SMTP',
                            helperText: 'Short, descriptive summary of the action item',
                            prefixIcon: Icon(Icons.title_rounded, color: AppColors.primaryLight),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Task title is required' : null,
                          onChanged: (val) {
                            if (existing == null && !userCustomizedId) {
                              final slug = val
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                                  .replaceAll(RegExp(r'^-+|-+$'), '');
                              setModalState(() {
                                idController.text = slug.isNotEmpty
                                    ? 'task-$slug'
                                    : 'task-${DateTime.now().millisecondsSinceEpoch % 100000}';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Task Description
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Task Description',
                            hintText: 'Provide detailed steps, acceptance criteria, or links...',
                            prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primaryLight),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Task ID & Assignee Email
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: idController,
                                readOnly: existing != null,
                                decoration: InputDecoration(
                                  labelText: 'Task ID *',
                                  hintText: 'task-01',
                                  prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primaryLight, size: 20),
                                  fillColor: existing != null ? AppColors.surfaceSubtle : AppColors.inputBackground,
                                ),
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Task ID required' : null,
                                onChanged: (val) {
                                  userCustomizedId = true;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Assignee Email *',
                                  hintText: 'assignee@company.com',
                                  prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.primaryLight, size: 20),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Assignee email required';
                                  if (!val.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Interactive Due Date with Calendar Picker
                        TextFormField(
                          controller: dueDateController,
                          readOnly: true,
                          onTap: () async {
                            DateTime initialDate = DateTime.tryParse(dueDateController.text) ?? DateTime.now();
                            final picked = await showDatePicker(
                              context: modalCtx,
                              initialDate: initialDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setModalState(() {
                                dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Due Date *',
                            hintText: 'YYYY-MM-DD',
                            helperText: 'Scheduler checks this date for daily morning alerts',
                            prefixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryLight),
                            suffixIcon: IconButton(
                              tooltip: 'Select date from calendar',
                              icon: const Icon(Icons.event_available, color: AppColors.primaryLight),
                              onPressed: () async {
                                DateTime initialDate = DateTime.tryParse(dueDateController.text) ?? DateTime.now();
                                final picked = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: initialDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Dropdown for Priority
                        DropdownButtonFormField<TaskPriorityEnum>(
                          initialValue: selectedPriority,
                          decoration: const InputDecoration(
                            labelText: 'Priority Level *',
                            helperText: 'Determines urgency in scheduler reports',
                            prefixIcon: Icon(Icons.flag_outlined, color: AppColors.primaryLight),
                          ),
                          dropdownColor: AppColors.surface,
                          items: TaskPriorityEnum.values.map((p) {
                            Color color;
                            switch (p) {
                              case TaskPriorityEnum.low:
                                color = AppColors.priorityLow;
                                break;
                              case TaskPriorityEnum.medium:
                                color = AppColors.priorityMedium;
                                break;
                              case TaskPriorityEnum.high:
                                color = AppColors.priorityHigh;
                                break;
                              case TaskPriorityEnum.critical:
                                color = AppColors.priorityCritical;
                                break;
                            }
                            return DropdownMenuItem(
                              value: p,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    p.value,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newPriority) {
                            if (newPriority != null) {
                              setModalState(() => selectedPriority = newPriority);
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Dropdown for Status
                        DropdownButtonFormField<TaskStatusEnum>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Initial Task Status *',
                            helperText: 'Current execution status of this task',
                            prefixIcon: Icon(Icons.timelapse_rounded, color: AppColors.primaryLight),
                          ),
                          dropdownColor: AppColors.surface,
                          items: TaskStatusEnum.values.map((s) {
                            Color color;
                            switch (s) {
                              case TaskStatusEnum.pending:
                                color = AppColors.statusPending;
                                break;
                              case TaskStatusEnum.inProgress:
                                color = AppColors.statusInProgress;
                                break;
                              case TaskStatusEnum.completed:
                                color = AppColors.statusCompleted;
                                break;
                              case TaskStatusEnum.cancelled:
                                color = AppColors.statusCancelled;
                                break;
                            }
                            return DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    s.value,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null) {
                              setModalState(() => selectedStatus = newStatus);
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // Modal Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.pop(sheetCtx),
                                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textOnPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: Text(
                                  existing == null ? 'Create Task' : 'Save Task',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;

                                  final task = TaskModel(
                                    taskId: idController.text.trim(),
                                    projectId: widget.projectId,
                                    title: titleController.text.trim(),
                                    description: descController.text.trim(),
                                    status: selectedStatus,
                                    priority: selectedPriority,
                                    assignedToEmail: emailController.text.trim(),
                                    dueDate: dueDateController.text.trim(),
                                  );

                                  tasksBloc.add(UpsertTaskEvent(task));
                                  Navigator.pop(sheetCtx);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline, color: AppColors.textOnPrimary),
                                          const SizedBox(width: 8),
                                          Text(existing == null ? 'Task created successfully' : 'Task updated successfully'),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDeleteTask(BuildContext context, String taskId, String taskTitle) {
    final tasksBloc = context.read<TasksBloc>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
            SizedBox(width: 8),
            Text('Delete Task?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete task "$taskTitle"?',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Task ID: $taskId\nProject: ${widget.projectId}',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              tasksBloc.add(DeleteTaskEvent(
                    projectId: widget.projectId,
                    taskId: taskId,
                  ));
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
                      SizedBox(width: 8),
                      Text('Task deleted successfully'),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Delete Task', style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
