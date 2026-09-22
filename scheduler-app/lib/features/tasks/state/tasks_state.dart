import 'package:equatable/equatable.dart';
import '../model/task_model.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class FetchTasksEvent extends TasksEvent {
  final String projectId;
  final TaskStatusEnum? statusFilter;

  const FetchTasksEvent({
    required this.projectId,
    this.statusFilter,
  });

  @override
  List<Object?> get props => [projectId, statusFilter];
}

class UpsertTaskEvent extends TasksEvent {
  final TaskModel task;

  const UpsertTaskEvent(this.task);

  @override
  List<Object?> get props => [task];
}

class UpdateTaskStatusEvent extends TasksEvent {
  final String projectId;
  final String taskId;
  final TaskStatusEnum newStatus;

  const UpdateTaskStatusEvent({
    required this.projectId,
    required this.taskId,
    required this.newStatus,
  });

  @override
  List<Object?> get props => [projectId, taskId, newStatus];
}

class DeleteTaskEvent extends TasksEvent {
  final String projectId;
  final String taskId;

  const DeleteTaskEvent({
    required this.projectId,
    required this.taskId,
  });

  @override
  List<Object?> get props => [projectId, taskId];
}

abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksInitialState extends TasksState {
  const TasksInitialState();
}

class TasksLoadingState extends TasksState {
  const TasksLoadingState();
}

class TasksLoadedState extends TasksState {
  final String projectId;
  final List<TaskModel> tasks;
  final TaskStatusEnum? currentFilter;
  final String? message;

  const TasksLoadedState({
    required this.projectId,
    required this.tasks,
    this.currentFilter,
    this.message,
  });

  @override
  List<Object?> get props => [projectId, tasks, currentFilter, message];
}

class TasksErrorState extends TasksState {
  final String errorMessage;

  const TasksErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
