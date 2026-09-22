import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/projects_bloc.dart';
import '../model/project_model.dart';
import '../state/projects_state.dart';
import '../../tasks/screen/tasks_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Projects',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
            onPressed: () => context.read<ProjectsBloc>().add(const FetchProjectsEvent()),
          ),
        ],
      ),
      body: BlocConsumer<ProjectsBloc, ProjectsState>(
        listener: (context, state) {
          if (state is ProjectsErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProjectsLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ProjectsLoadedState) {
            if (state.projects.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_open, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No projects found in Cloud Storage',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Project'),
                      onPressed: () => _showProjectDialog(context),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.projects.length,
              itemBuilder: (context, index) {
                final project = state.projects[index];
                return _buildProjectCard(context, project);
              },
            );
          }
          return Center(
            child: ElevatedButton(
              onPressed: () => context.read<ProjectsBloc>().add(const FetchProjectsEvent()),
              child: const Text('Load Projects'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        onPressed: () => _showProjectDialog(context),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    Color statusColor;
    switch (project.status) {
      case ProjectStatusEnum.active:
        statusColor = AppColors.success;
        break;
      case ProjectStatusEnum.onHold:
        statusColor = AppColors.warning;
        break;
      case ProjectStatusEnum.completed:
        statusColor = AppColors.info;
        break;
      case ProjectStatusEnum.archived:
        statusColor = AppColors.textMuted;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TasksScreen(
                projectId: project.projectId,
                projectName: project.name,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      project.status.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                project.description.isNotEmpty ? project.description : 'No description provided',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      project.ownerEmail.isNotEmpty ? project.ownerEmail : 'No owner email',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryLight),
                    onPressed: () => _showProjectDialog(context, existing: project),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    onPressed: () => _confirmDelete(context, project.projectId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectDialog(BuildContext context, {ProjectModel? existing}) {
    final idController = TextEditingController(text: existing?.projectId ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final emailController = TextEditingController(text: existing?.ownerEmail ?? 'jaydeep.v@blute.co.in');
    ProjectStatusEnum selectedStatus = existing?.status ?? ProjectStatusEnum.active;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'New Project' : 'Edit Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'Project ID',
                      hintText: 'e.g. cloud-service-01',
                    ),
                  ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g. Infrastructure Setup',
                  ),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Owner Email',
                  ),
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
                final id = existing?.projectId ?? idController.text.trim();
                final name = nameController.text.trim();
                if (id.isEmpty || name.isEmpty) return;

                final project = ProjectModel(
                  projectId: id,
                  name: name,
                  description: descController.text.trim(),
                  ownerEmail: emailController.text.trim(),
                  status: selectedStatus,
                );

                context.read<ProjectsBloc>().add(UpsertProjectEvent(project));
                Navigator.pop(dialogCtx);
              },
              child: const Text('Save', style: TextStyle(color: AppColors.textOnPrimary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String projectId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete project "$projectId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<ProjectsBloc>().add(DeleteProjectEvent(projectId));
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.textOnPrimary)),
          ),
        ],
      ),
    );
  }
}
