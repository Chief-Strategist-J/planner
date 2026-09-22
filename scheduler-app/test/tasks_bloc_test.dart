import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:scheduler_app/features/projects/bloc/projects_bloc.dart';
import 'package:scheduler_app/features/projects/model/project_model.dart';
import 'package:scheduler_app/features/projects/state/projects_state.dart';
import 'package:scheduler_app/features/tasks/bloc/tasks_bloc.dart';
import 'package:scheduler_app/features/tasks/model/task_model.dart';
import 'package:scheduler_app/features/tasks/state/tasks_state.dart';

void main() {
  group('TasksBloc Real Endpoint Tests', () {
    late TasksBloc tasksBloc;
    final testProjectId = 'test-tasks-proj-${DateTime.now().millisecondsSinceEpoch}';
    final testTaskId = 'task-${DateTime.now().millisecondsSinceEpoch}';

    final testProject = ProjectModel(
      projectId: testProjectId,
      name: 'Task Integration Test Project',
      description: 'Host project for live task bloc testing',
      ownerEmail: 'tasks-qa@example.com',
      status: ProjectStatusEnum.active,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final testTask = TaskModel(
      taskId: testTaskId,
      projectId: testProjectId,
      title: 'Real Endpoint Automated Task',
      description: 'Testing task CRUD against live Cloud Run backend',
      assignedToEmail: 'developer@example.com',
      dueDate: DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String().substring(0, 10),
      priority: TaskPriorityEnum.high,
      status: TaskStatusEnum.pending,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    setUpAll(() async {
      final projectsBloc = ProjectsBloc();
      projectsBloc.add(UpsertProjectEvent(testProject));
      await Future.delayed(const Duration(seconds: 4));
      await projectsBloc.close();
    });

    tearDownAll(() async {
      final projectsBloc = ProjectsBloc();
      projectsBloc.add(DeleteProjectEvent(testProjectId));
      await Future.delayed(const Duration(seconds: 4));
      await projectsBloc.close();
    });

    setUp(() {
      tasksBloc = TasksBloc();
    });

    tearDown(() {
      tasksBloc.close();
    });

    test('initial state is TasksInitialState', () {
      expect(tasksBloc.state, equals(const TasksInitialState()));
    });

    blocTest<TasksBloc, TasksState>(
      'creates a new task on live Cloud Run backend and loads it',
      build: () => TasksBloc(),
      act: (bloc) => bloc.add(UpsertTaskEvent(testTask)),
      wait: const Duration(seconds: 5),
      expect: () => [
        const TasksLoadingState(),
        isA<TasksLoadedState>().having(
          (state) => state.tasks.any((t) => t.taskId == testTaskId),
          'contains created task',
          isTrue,
        ),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'fetches tasks for project from live Cloud Run endpoint',
      build: () => TasksBloc(),
      act: (bloc) => bloc.add(FetchTasksEvent(projectId: testProjectId)),
      wait: const Duration(seconds: 4),
      expect: () => [
        const TasksLoadingState(),
        isA<TasksLoadedState>().having(
          (state) => state.tasks.length,
          'task list length',
          greaterThanOrEqualTo(1),
        ),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'updates task status to COMPLETED on live backend',
      build: () => TasksBloc(),
      act: (bloc) => bloc.add(UpdateTaskStatusEvent(
        projectId: testProjectId,
        taskId: testTaskId,
        newStatus: TaskStatusEnum.completed,
      )),
      wait: const Duration(seconds: 5),
      expect: () => [
        const TasksLoadingState(),
        isA<TasksLoadedState>().having(
          (state) => state.tasks.firstWhere((t) => t.taskId == testTaskId).status,
          'updated status is completed',
          equals(TaskStatusEnum.completed),
        ),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'deletes task from live backend and refreshes list',
      build: () => TasksBloc(),
      act: (bloc) => bloc.add(DeleteTaskEvent(
        projectId: testProjectId,
        taskId: testTaskId,
      )),
      wait: const Duration(seconds: 5),
      expect: () => [
        const TasksLoadingState(),
        isA<TasksLoadedState>().having(
          (state) => state.tasks.any((t) => t.taskId == testTaskId),
          'does not contain deleted task',
          isFalse,
        ),
      ],
    );
  });
}
