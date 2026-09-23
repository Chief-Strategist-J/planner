import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/projects_bloc.dart';
import '../model/project_model.dart';
import '../state/projects_state.dart';
import '../../tasks/screen/tasks_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _searchQuery = '';
  ProjectStatusEnum? _selectedStatusFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Projects Directory',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Projects',
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
          if (state is ProjectsLoadingState) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Fetching projects from Cloud Storage...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          if (state is ProjectsLoadedState) {
            final allProjects = state.projects;

            final filteredProjects = allProjects.where((p) {
              final matchesQuery = _searchQuery.isEmpty ||
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  p.projectId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  p.description.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchesStatus = _selectedStatusFilter == null || p.status == _selectedStatusFilter;
              return matchesQuery && matchesStatus;
            }).toList();

            return Column(
              children: [
                _buildSearchAndFilterHeader(allProjects),
                Expanded(
                  child: allProjects.isEmpty
                      ? _buildEmptyState(context)
                      : filteredProjects.isEmpty
                          ? _buildNoSearchResultsState()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () async {
                                context.read<ProjectsBloc>().add(const FetchProjectsEvent());
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: filteredProjects.length,
                                itemBuilder: (context, index) {
                                  final project = filteredProjects[index];
                                  return _buildProjectCard(context, project);
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
              label: const Text('Load Projects', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => context.read<ProjectsBloc>().add(const FetchProjectsEvent()),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 3,
        icon: const Icon(Icons.add),
        label: const Text('New Project', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showProjectDialog(context),
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(List<ProjectModel> allProjects) {
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
              hintText: 'Search by project name, ID, or description...',
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
                _filterChip(label: 'All (${allProjects.length})', isSelected: _selectedStatusFilter == null, filter: null),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Active (${allProjects.where((p) => p.status == ProjectStatusEnum.active).length})',
                  isSelected: _selectedStatusFilter == ProjectStatusEnum.active,
                  filter: ProjectStatusEnum.active,
                  dotColor: AppColors.success,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'On Hold (${allProjects.where((p) => p.status == ProjectStatusEnum.onHold).length})',
                  isSelected: _selectedStatusFilter == ProjectStatusEnum.onHold,
                  filter: ProjectStatusEnum.onHold,
                  dotColor: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Completed (${allProjects.where((p) => p.status == ProjectStatusEnum.completed).length})',
                  isSelected: _selectedStatusFilter == ProjectStatusEnum.completed,
                  filter: ProjectStatusEnum.completed,
                  dotColor: AppColors.info,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Archived (${allProjects.where((p) => p.status == ProjectStatusEnum.archived).length})',
                  isSelected: _selectedStatusFilter == ProjectStatusEnum.archived,
                  filter: ProjectStatusEnum.archived,
                  dotColor: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required ProjectStatusEnum? filter,
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
      onSelected: (_) => setState(() => _selectedStatusFilter = filter),
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
              child: const Icon(Icons.folder_open_rounded, size: 54, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Projects Created Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first project to organize tasks, assign team members, and track automated daily schedules.',
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
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create First Project', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showProjectDialog(context),
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
              'No Matching Projects',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search query or status filter.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
              onPressed: () => setState(() {
                _searchQuery = '';
                _selectedStatusFilter = null;
              }),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_rounded, color: AppColors.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'ID: ${project.projectId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          project.status.value,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.description.isNotEmpty ? project.description : 'No description provided for this project.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.ownerEmail.isNotEmpty ? project.ownerEmail : 'No owner email',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit Project',
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryLight),
                    onPressed: () => _showProjectDialog(context, existing: project),
                  ),
                  IconButton(
                    tooltip: 'Delete Project',
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    onPressed: () => _confirmDelete(context, project.projectId, project.name),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Text('Tasks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primaryLight),
                        ],
                      ),
                    ),
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
    final projectsBloc = context.read<ProjectsBloc>();
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController(text: existing?.projectId ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final emailController = TextEditingController(text: existing?.ownerEmail ?? 'jaydeep.v@blute.co.in');
    ProjectStatusEnum selectedStatus = existing?.status ?? ProjectStatusEnum.active;
    bool userCustomizedId = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: projectsBloc,
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                existing == null ? Icons.create_new_folder_rounded : Icons.edit_note_rounded,
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
                                    existing == null ? 'Create New Project' : 'Edit Project Details',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    existing == null
                                        ? 'Add a new project to Google Cloud Storage'
                                        : 'Modify project configuration & metadata',
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
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nameController,
                          autofocus: existing == null,
                          decoration: const InputDecoration(
                            labelText: 'Project Name *',
                            hintText: 'e.g. Infrastructure Modernization',
                            helperText: 'Human-readable title displayed across dashboards',
                            prefixIcon: Icon(Icons.folder_outlined, color: AppColors.primaryLight),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Project Name is required' : null,
                          onChanged: (val) {
                            if (existing == null && !userCustomizedId) {
                              final slug = val
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                                  .replaceAll(RegExp(r'^-+|-+$'), '');
                              setModalState(() {
                                idController.text = slug;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: idController,
                          readOnly: existing != null,
                          decoration: InputDecoration(
                            labelText: existing == null ? 'Project ID *' : 'Project ID (Read-only)',
                            hintText: 'e.g. infra-modernization',
                            helperText: 'Unique ID key stored in gs://planner-app-66733-data',
                            prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primaryLight),
                            fillColor: existing != null ? AppColors.surfaceSubtle : AppColors.inputBackground,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Project ID is required' : null,
                          onChanged: (val) {
                            userCustomizedId = true;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe deliverables, scope, and objectives...',
                            prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primaryLight),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Owner Email *',
                            hintText: 'lead@company.com',
                            helperText: 'Receives daily morning task reminder digest',
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.primaryLight),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Owner email is required';
                            if (!val.contains('@')) return 'Enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Styled Dropdown for Project Status
                        DropdownButtonFormField<ProjectStatusEnum>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Project Status *',
                            helperText: 'Operational lifecycle stage of the project',
                            prefixIcon: Icon(Icons.info_outline_rounded, color: AppColors.primaryLight),
                          ),
                          dropdownColor: AppColors.surface,
                          items: ProjectStatusEnum.values.map((status) {
                            Color color;
                            switch (status) {
                              case ProjectStatusEnum.active:
                                color = AppColors.success;
                                break;
                              case ProjectStatusEnum.onHold:
                                color = AppColors.warning;
                                break;
                              case ProjectStatusEnum.completed:
                                color = AppColors.info;
                                break;
                              case ProjectStatusEnum.archived:
                                color = AppColors.textMuted;
                                break;
                            }
                            return DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status.value,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedStatus = val);
                            }
                          },
                        ),
                        const SizedBox(height: 24),
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
                                  existing == null ? 'Create Project' : 'Save Changes',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;

                                  final project = ProjectModel(
                                    projectId: idController.text.trim(),
                                    name: nameController.text.trim(),
                                    description: descController.text.trim(),
                                    ownerEmail: emailController.text.trim(),
                                    status: selectedStatus,
                                  );

                                  projectsBloc.add(UpsertProjectEvent(project));
                                  Navigator.pop(sheetCtx);
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

  void _confirmDelete(BuildContext context, String projectId, String projectName) {
    final projectsBloc = context.read<ProjectsBloc>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
            SizedBox(width: 8),
            Text('Delete Project?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "$projectName"?',
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
                'Project ID: $projectId\nThis will remove all associated tasks and schedules from Cloud Storage.',
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
              projectsBloc.add(DeleteProjectEvent(projectId));
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete Project', style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
