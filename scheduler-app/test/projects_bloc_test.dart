import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:scheduler_app/features/projects/bloc/projects_bloc.dart';
import 'package:scheduler_app/features/projects/model/project_model.dart';
import 'package:scheduler_app/features/projects/state/projects_state.dart';

void main() {
  group('ProjectsBloc Real Endpoint Tests', () {
    late ProjectsBloc projectsBloc;
    final testProjectId = 'test-proj-${DateTime.now().millisecondsSinceEpoch}';
    final testProject = ProjectModel(
      projectId: testProjectId,
      name: 'Automated Test Project',
      description: 'Created during live bloc integration test',
      ownerEmail: 'planner-qa@example.com',
      status: ProjectStatusEnum.active,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    setUp(() {
      projectsBloc = ProjectsBloc();
    });

    tearDown(() {
      projectsBloc.close();
    });

    test('initial state is ProjectsInitialState', () {
      expect(projectsBloc.state, equals(const ProjectsInitialState()));
    });

    blocTest<ProjectsBloc, ProjectsState>(
      'fetches projects list from live Cloud Run endpoint',
      build: () => ProjectsBloc(),
      act: (bloc) => bloc.add(const FetchProjectsEvent()),
      wait: const Duration(seconds: 4),
      expect: () => [
        const ProjectsLoadingState(),
        isA<ProjectsLoadedState>().having(
          (state) => state.projects,
          'projects',
          isNotNull,
        ),
      ],
    );

    blocTest<ProjectsBloc, ProjectsState>(
      'creates a new project on live Cloud Run backend and refreshes list',
      build: () => ProjectsBloc(),
      act: (bloc) => bloc.add(UpsertProjectEvent(testProject)),
      wait: const Duration(seconds: 5),
      expect: () => [
        const ProjectsLoadingState(),
        isA<ProjectsLoadedState>().having(
          (state) => state.projects.any((p) => p.projectId == testProjectId),
          'contains created project',
          isTrue,
        ),
      ],
    );

    blocTest<ProjectsBloc, ProjectsState>(
      'deletes the test project from live Cloud Run backend and refreshes list',
      build: () => ProjectsBloc(),
      act: (bloc) => bloc.add(DeleteProjectEvent(testProjectId)),
      wait: const Duration(seconds: 5),
      expect: () => [
        const ProjectsLoadingState(),
        isA<ProjectsLoadedState>().having(
          (state) => state.projects.any((p) => p.projectId == testProjectId),
          'does not contain deleted project',
          isFalse,
        ),
      ],
    );
  });
}
