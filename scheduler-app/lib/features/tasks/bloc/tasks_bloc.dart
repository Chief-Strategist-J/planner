import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../model/task_model.dart';
import '../state/tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final ApiClient _apiClient = ApiClient();

  TasksBloc() : super(const TasksInitialState()) {
    on<FetchTasksEvent>(_onFetchTasks);
    on<UpsertTaskEvent>(_onUpsertTask);
    on<UpdateTaskStatusEvent>(_onUpdateTaskStatus);
    on<DeleteTaskEvent>(_onDeleteTask);
  }

  Future<void> _onFetchTasks(
    FetchTasksEvent event,
    Emitter<TasksState> emit,
  ) async {
    emit(const TasksLoadingState());
    try {
      final queryParams = <String, dynamic>{};
      if (event.statusFilter != null) {
        queryParams['status'] = event.statusFilter!.value;
      }

      final response = await _apiClient.dio.get(
        AppEndpoints.projectTasks(event.projectId),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data['data'] as List<dynamic>? ?? [];
        final tasks = data
            .map((item) => TaskModel.fromJson(item as Map<String, dynamic>))
            .toList();
        emit(TasksLoadedState(
          projectId: event.projectId,
          tasks: tasks,
          currentFilter: event.statusFilter,
        ));
      } else {
        emit(const TasksErrorState('Failed to fetch tasks'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Network error';
      emit(TasksErrorState(message.toString()));
    } catch (e) {
      emit(TasksErrorState(e.toString()));
    }
  }

  Future<void> _onUpsertTask(
    UpsertTaskEvent event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        AppEndpoints.projectTasks(event.task.projectId),
        data: event.task.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        add(FetchTasksEvent(projectId: event.task.projectId));
      } else {
        emit(const TasksErrorState('Failed to save task'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Save task error';
      emit(TasksErrorState(message.toString()));
    } catch (e) {
      emit(TasksErrorState(e.toString()));
    }
  }

  Future<void> _onUpdateTaskStatus(
    UpdateTaskStatusEvent event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final response = await _apiClient.dio.patch(
        AppEndpoints.taskStatus(event.projectId, event.taskId),
        data: {'status': event.newStatus.value},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        add(FetchTasksEvent(projectId: event.projectId));
      } else {
        emit(const TasksErrorState('Failed to update task status'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Status update error';
      emit(TasksErrorState(message.toString()));
    } catch (e) {
      emit(TasksErrorState(e.toString()));
    }
  }

  Future<void> _onDeleteTask(
    DeleteTaskEvent event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final response = await _apiClient.dio.delete(
        AppEndpoints.taskById(event.projectId, event.taskId),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        add(FetchTasksEvent(projectId: event.projectId));
      } else {
        emit(const TasksErrorState('Failed to delete task'));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['error']?['message'] ?? e.message ?? 'Delete task error';
      emit(TasksErrorState(message.toString()));
    } catch (e) {
      emit(TasksErrorState(e.toString()));
    }
  }
}
