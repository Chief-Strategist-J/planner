import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/dashboard_bloc.dart';
import '../model/dashboard_model.dart';
import '../state/dashboard_state.dart';
import '../../projects/screen/projects_screen.dart';
import '../../scheduler/screen/scheduler_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Planner Cloud Overview',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
            onPressed: () => context.read<DashboardBloc>().add(const FetchDashboardDataEvent()),
          ),
        ],
      ),
      body: BlocConsumer<DashboardBloc, DashboardState>(
        listener: (context, state) {
          if (state is DashboardErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is DashboardLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is DashboardLoadedState) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                context.read<DashboardBloc>().add(const FetchDashboardDataEvent());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCloudStatusHeader(state.summary),
                    const SizedBox(height: 20),
                    _buildMetricsGrid(state.summary),
                    const SizedBox(height: 20),
                    _buildQuickActions(context),
                    const SizedBox(height: 20),
                    _buildInfrastructureDetails(state.summary),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => context.read<DashboardBloc>().add(const FetchDashboardDataEvent()),
              child: const Text('Load Dashboard', style: TextStyle(color: AppColors.textOnPrimary)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCloudStatusHeader(DashboardSummaryModel summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Google Cloud Run Service',
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.isHealthy ? AppColors.success : AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: AppColors.textOnPrimary, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      summary.isHealthy ? 'LIVE' : 'OFFLINE',
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'https://planner-service-715525810343.asia-south1.run.app',
            style: TextStyle(color: AppColors.border, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                summary.region,
                style: const TextStyle(color: AppColors.textOnPrimary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(DashboardSummaryModel summary) {
    return Column(
      children: [
        Row(
          children: [
            _metricCard('Projects', '${summary.totalProjects}', Icons.folder_outlined, AppColors.info),
            const SizedBox(width: 12),
            _metricCard('Total Tasks', '${summary.totalTasks}', Icons.task_outlined, AppColors.primaryLight),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricCard('Pending', '${summary.pendingTasks}', Icons.pending_actions_outlined, AppColors.warning),
            const SizedBox(width: 12),
            _metricCard('Completed', '${summary.completedTasks}', Icons.check_circle_outline, AppColors.success),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            icon: const Icon(Icons.folder, color: AppColors.primary),
            label: const Text('Manage Projects', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectsScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            icon: const Icon(Icons.alarm_on, color: AppColors.accent),
            label: const Text('Daily Scheduler', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchedulerScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfrastructureDetails(DashboardSummaryModel summary) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Architecture & Cost Guardrails',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            _infoRow('Storage Backend:', summary.storageBucket),
            const SizedBox(height: 8),
            _infoRow('Autoscaling Policy:', 'Scale-to-Zero (min: 0, max: 1)'),
            const SizedBox(height: 8),
            _infoRow('Compute Allocation:', '1 vCPU | 512 MiB (CPU Throttled)'),
            const SizedBox(height: 8),
            _infoRow('Cost Tier:', 'Google Cloud 100% Free Tier (\$0.00/mo)'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
