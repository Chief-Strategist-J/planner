import 'package:equatable/equatable.dart';
import '../model/project_model.dart';

abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();

  @override
  List<Object?> get props => [];
}

class FetchProjectsEvent extends ProjectsEvent {
  const FetchProjectsEvent();
}

class UpsertProjectEvent extends ProjectsEvent {
  final ProjectModel project;

  const UpsertProjectEvent(this.project);

  @override
  List<Object?> get props => [project];
}

class DeleteProjectEvent extends ProjectsEvent {
  final String projectId;

  const DeleteProjectEvent(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

abstract class ProjectsState extends Equatable {
  const ProjectsState();

  @override
  List<Object?> get props => [];
}

class ProjectsInitialState extends ProjectsState {
  const ProjectsInitialState();
}

class ProjectsLoadingState extends ProjectsState {
  const ProjectsLoadingState();
}

class ProjectsLoadedState extends ProjectsState {
  final List<ProjectModel> projects;
  final String? message;

  const ProjectsLoadedState({
    required this.projects,
    this.message,
  });

  @override
  List<Object?> get props => [projects, message];
}

class ProjectsErrorState extends ProjectsState {
  final String errorMessage;

  const ProjectsErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
