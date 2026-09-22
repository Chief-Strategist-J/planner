import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../model/project_model.dart';
import '../state/projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  final ApiClient _apiClient = ApiClient();

  ProjectsBloc() : super(const ProjectsInitialState()) {
    on<FetchProjectsEvent>(_onFetchProjects);
    on<UpsertProjectEvent>(_onUpsertProject);
    on<DeleteProjectEvent>(_onDeleteProject);
  }

  Future<void> _onFetchProjects(
    FetchProjectsEvent event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(const ProjectsLoadingState());
    try {
      final response = await _apiClient.dio.get(AppEndpoints.projects);
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data['data'] as List<dynamic>? ?? [];
        final projects = data
            .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
            .toList();
        emit(ProjectsLoadedState(projects: projects));
      } else {
        emit(const ProjectsErrorState('Failed to fetch projects'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Network error';
      emit(ProjectsErrorState(message.toString()));
    } catch (e) {
      emit(ProjectsErrorState(e.toString()));
    }
  }

  Future<void> _onUpsertProject(
    UpsertProjectEvent event,
    Emitter<ProjectsState> emit,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        AppEndpoints.projects,
        data: event.project.toJson(),
      );
      if (response.statusCode == 200) {
        add(const FetchProjectsEvent());
      } else {
        emit(const ProjectsErrorState('Failed to save project'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Save error';
      emit(ProjectsErrorState(message.toString()));
    } catch (e) {
      emit(ProjectsErrorState(e.toString()));
    }
  }

  Future<void> _onDeleteProject(
    DeleteProjectEvent event,
    Emitter<ProjectsState> emit,
  ) async {
    try {
      final response = await _apiClient.dio.delete(
        AppEndpoints.projectById(event.projectId),
      );
      if (response.statusCode == 200) {
        add(const FetchProjectsEvent());
      } else {
        emit(const ProjectsErrorState('Failed to delete project'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Delete error';
      emit(ProjectsErrorState(message.toString()));
    } catch (e) {
      emit(ProjectsErrorState(e.toString()));
    }
  }
}
