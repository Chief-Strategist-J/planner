import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../model/dashboard_model.dart';
import '../state/dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ApiClient _apiClient = ApiClient();

  DashboardBloc() : super(const DashboardInitialState()) {
    on<FetchDashboardDataEvent>(_onFetchDashboard);
  }

  Future<void> _onFetchDashboard(
    FetchDashboardDataEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoadingState());
    try {
      final healthRes = await _apiClient.dio.get(AppEndpoints.health);
      final isHealthy = healthRes.statusCode == 200;
      final serviceStatus = healthRes.data?['status'] as String? ?? 'offline';

      final projectsRes = await _apiClient.dio.get(AppEndpoints.projects);
      final List<dynamic> projects = projectsRes.data?['data'] as List<dynamic>? ?? [];

      int totalTasks = 0;
      int pendingTasks = 0;
      int completedTasks = 0;

      for (final p in projects) {
        final projectId = p['projectId'] as String? ?? '';
        if (projectId.isNotEmpty) {
          try {
            final tasksRes = await _apiClient.dio.get(AppEndpoints.projectTasks(projectId));
            final List<dynamic> tasks = tasksRes.data?['data'] as List<dynamic>? ?? [];
            totalTasks += tasks.length;
            for (final t in tasks) {
              final status = (t['status'] as String? ?? '').toUpperCase();
              if (status == 'PENDING') {
                pendingTasks++;
              } else if (status == 'COMPLETED') {
                completedTasks++;
              }
            }
          } catch (_) {}
        }
      }

      final summary = DashboardSummaryModel(
        isHealthy: isHealthy,
        serviceStatus: serviceStatus,
        totalProjects: projects.length,
        totalTasks: totalTasks,
        pendingTasks: pendingTasks,
        completedTasks: completedTasks,
        region: 'asia-south1 (Mumbai)',
        storageBucket: 'gs://planner-app-66733-data',
      );

      emit(DashboardLoadedState(summary));
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Dashboard network error';
      emit(DashboardErrorState(message.toString()));
    } catch (e) {
      emit(DashboardErrorState(e.toString()));
    }
  }
}
