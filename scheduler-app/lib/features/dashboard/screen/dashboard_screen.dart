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
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.textOnPrimary, size: 22),
            SizedBox(width: 8),
            Text(
              'Planner Cloud Hub',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textOnPrimary),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Dashboard',
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
          if (state is DashboardLoadingState) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Loading Cloud Infrastructure...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
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
                    const SizedBox(height: 16),
                    _buildTaskProgressCard(state.summary),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(state.summary),
                    const SizedBox(height: 16),
                    _buildQuickActions(context),
                    const SizedBox(height: 16),
                    _buildInfrastructureDetails(state.summary),
                  ],
                ),
              ),
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
              icon: const Icon(Icons.refresh),
              label: const Text('Load Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => context.read<DashboardBloc>().add(const FetchDashboardDataEvent()),
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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Google Cloud Run Service',
                    style: TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                    const Icon(Icons.circle, color: AppColors.textOnPrimary, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      summary.isHealthy ? 'HEALTHY & LIVE' : 'UNAVAILABLE',
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'https://planner-service-715525810343.asia-south1.run.app',
              style: TextStyle(color: AppColors.border, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.public_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Region: ${summary.region}',
                style: const TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.storage_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text(
                'gs://planner-app-66733-data',
                style: TextStyle(color: AppColors.textOnPrimary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskProgressCard(DashboardSummaryModel summary) {
    final total = summary.totalTasks;
    final completed = summary.completedTasks;
    final double completionRate = total > 0 ? (completed / total) : 0.0;
    final percentInt = (completionRate * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 18, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text(
                    'Overall Task Completion',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Text(
                '$percentInt% Completed',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completionRate,
              minHeight: 8,
              backgroundColor: AppColors.inputBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total tasks completed',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '${summary.pendingTasks} pending tasks remaining',
                style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
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
            _metricCard('Projects', '${summary.totalProjects}', Icons.folder_outlined, AppColors.info, 'Active buckets'),
            const SizedBox(width: 12),
            _metricCard('Total Tasks', '${summary.totalTasks}', Icons.task_outlined, AppColors.primaryLight, 'Across all projects'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricCard('Pending Tasks', '${summary.pendingTasks}', Icons.pending_actions_outlined, AppColors.warning, 'Requires action'),
            const SizedBox(width: 12),
            _metricCard('Completed', '${summary.completedTasks}', Icons.check_circle_outline, AppColors.success, 'Finished tasks'),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Navigation',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.folder_rounded, color: AppColors.primaryLight, size: 18),
                ),
                label: const Text('Manage Projects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.alarm_on_rounded, color: AppColors.accent, size: 18),
                ),
                label: const Text('Daily Scheduler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SchedulerScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfrastructureDetails(DashboardSummaryModel summary) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryLight),
                SizedBox(width: 8),
                Text(
                  'Cloud Architecture & Guardrails',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
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
              fontSize: 12,
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
